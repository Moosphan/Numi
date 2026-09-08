import SwiftUI
import Network
import Combine
import CloudKit
import CoreData
import NumiCore

// MARK: - Sync Status

public enum SyncStatus: Equatable {
    case idle
    case syncing
    /// CloudKit has accepted a sync request, but its import/export completion has
    /// not yet been observed. This must never be presented as a successful sync.
    case scheduled(Date)
    case success(Date)
    case failure(SyncFailureReason)

    var displayMessage: String {
        switch self {
        case .idle:
            return NumiLocalized.string("sync.status.waiting")
        case .syncing:
            return NumiLocalized.string("sync.status.syncing")
        case .scheduled:
            return NumiLocalized.string("sync.status.scheduled")
        case .success:
            return NumiLocalized.string("sync.status.success")
        case .failure(let reason):
            return reason.displayMessage
        }
    }
}

public enum SyncFailureReason: Equatable {
    case networkUnavailable
    case iCloudUnavailable
    case cellularDisabled
    case syncFailed

    var displayMessage: String {
        switch self {
        case .networkUnavailable:
            return NumiLocalized.string("sync.status.network.unavailable")
        case .iCloudUnavailable:
            return NumiLocalized.string("sync.status.icloud.unavailable")
        case .cellularDisabled:
            return NumiLocalized.string("sync.status.cellular.disabled")
        case .syncFailed:
            return NumiLocalized.string("sync.status.failed")
        }
    }
}

public enum SyncPreflight {
    public static func failure(
        isNetworkAvailable: Bool,
        isICloudAvailable: Bool,
        networkType: NetworkType,
        isCellularSyncEnabled: Bool
    ) -> SyncFailureReason? {
        guard isNetworkAvailable else { return .networkUnavailable }
        guard isICloudAvailable else { return .iCloudUnavailable }
        guard networkType != .cellular || isCellularSyncEnabled else { return .cellularDisabled }
        return nil
    }
}

public enum SyncExecutionPolicy {
    public static func canStart(status: SyncStatus) -> Bool {
        switch status {
        case .syncing, .scheduled:
            return false
        default:
            return true
        }
    }
}

public enum SyncRequestResult: Equatable, Sendable {
    case scheduled
    case failed
}

/// A normalized view of the lifecycle signals delivered by Core Data's
/// `NSPersistentCloudKitContainer` event stream.
public enum CloudSyncEventPhase: Equatable {
    case started
    case succeeded(Date)
    case failed
}

public enum CloudSyncEventStatusMapper {
    public static func status(for phase: CloudSyncEventPhase) -> SyncStatus {
        switch phase {
        case .started:
            .syncing
        case .succeeded(let completedAt):
            .success(completedAt)
        case .failed:
            .failure(.syncFailed)
        }
    }
}

public enum iCloudAccountStatusEvaluator {
    public static func isUsable(_ status: CKAccountStatus) -> Bool {
        status == .available
    }
}

public enum iCloudRuntimeAvailabilityPolicy {
    public static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    public static func shouldQueryCloudKit(isSimulator: Bool) -> Bool {
        !isSimulator
    }
}

// MARK: - Network Type

public enum NetworkType: String {
    case wifi
    case cellular
    case unavailable

    var displayName: String {
        switch self {
        case .wifi: return NumiLocalized.string( "sync.network.wifi")
        case .cellular: return NumiLocalized.string( "sync.network.cellular")
        case .unavailable: return NumiLocalized.string( "sync.network.none")
        }
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .unavailable: return "wifi.slash"
        }
    }
}

// MARK: - Sync Service

@MainActor
public class iCloudSyncService: ObservableObject {
    public static let shared = iCloudSyncService()

    @Published public private(set) var isSyncEnabled = false
    @Published public private(set) var isCellularSyncEnabled = false
    @Published public private(set) var networkType: NetworkType = .unavailable
    @Published public private(set) var isNetworkAvailable = false
    @Published public private(set) var isiCloudAvailable = false
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncProgress: Double = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.numi.network-monitor")
    private let defaults = UserDefaults.standard
    private var eventObservation: AnyCancellable?

    private init() {
        isSyncEnabled = defaults.bool(forKey: "app.sync.icloudEnabled")
        CloudSyncSharedPreference.setCloudSyncEnabled(isSyncEnabled)
        isCellularSyncEnabled = defaults.bool(forKey: "app.sync.cellularEnabled")
        lastSyncDate = defaults.object(forKey: "app.sync.lastSyncDate") as? Date
        startNetworkMonitor()
        checkiCloudAvailability()
        observeSyncEvents()
    }

    // MARK: - Public API

    public func toggleSync() {
        isSyncEnabled.toggle()
        defaults.set(isSyncEnabled, forKey: "app.sync.icloudEnabled")
        if isSyncEnabled {
            Task { await performSync() }
        }
    }

    public func toggleCellularSync() {
        isCellularSyncEnabled.toggle()
        defaults.set(isCellularSyncEnabled, forKey: "app.sync.cellularEnabled")
    }

    /// 外部注入的同步闭包，由 RootShellView 提供
    public var onPerformSync: (() async -> SyncRequestResult)?

    public func performSync() async {
        guard isSyncEnabled else { return }
        guard SyncExecutionPolicy.canStart(status: syncStatus) else { return }
        if let failure = SyncPreflight.failure(
            isNetworkAvailable: isNetworkAvailable,
            isICloudAvailable: isiCloudAvailable,
            networkType: networkType,
            isCellularSyncEnabled: isCellularSyncEnabled
        ) {
            syncProgress = 0
            syncStatus = .failure(failure)
            return
        }

        syncStatus = .syncing
        syncProgress = 0

        if let onPerformSync {
            switch await onPerformSync() {
            case .scheduled:
                let now = Date()
                syncStatus = .scheduled(now)
                syncProgress = 0
            case .failed:
                syncProgress = 0
                syncStatus = .failure(.syncFailed)
            }
        } else {
            syncProgress = 0
            syncStatus = .failure(.syncFailed)
        }
    }

    // MARK: - Private

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.networkType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.networkType = .cellular
                } else if path.status == .satisfied {
                    self?.networkType = .wifi
                } else {
                    self?.networkType = .unavailable
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func checkiCloudAvailability() {
        guard iCloudRuntimeAvailabilityPolicy.shouldQueryCloudKit(
            isSimulator: iCloudRuntimeAvailabilityPolicy.isRunningInSimulator
        ) else {
            isiCloudAvailable = false
            return
        }

        CKContainer(identifier: "iCloud.com.local.Numi").accountStatus { [weak self] status, _ in
            let available = iCloudAccountStatusEvaluator.isUsable(status)
            DispatchQueue.main.async {
                self?.isiCloudAvailable = available
            }
        }
    }

    /// 监听 CloudKit 同步事件
    private func observeSyncEvents() {
        // Core Data emits lifecycle events for real CloudKit work. A manual
        // request stays distinct from the global activity stream, which cannot
        // serve as a receipt for one particular request.
        eventObservation = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
                else { return }

                let phase: CloudSyncEventPhase
                if let completedAt = event.endDate {
                    phase = event.succeeded ? .succeeded(completedAt) : .failed
                } else {
                    phase = .started
                }
                self.applyObservedCloudSyncEvent(phase)
            }
    }

    private func applyObservedCloudSyncEvent(_ phase: CloudSyncEventPhase) {
        let status = CloudSyncEventStatusMapper.status(for: phase)
        syncStatus = status

        switch status {
        case .success(let completedAt):
            lastSyncDate = completedAt
            defaults.set(completedAt, forKey: "app.sync.lastSyncDate")
            syncProgress = 1
        case .idle, .syncing, .scheduled, .failure:
            syncProgress = 0
        }
    }

    deinit {
        monitor.cancel()
        eventObservation?.cancel()
    }
}

// MARK: - Sync Settings View

public struct SyncSettingsView: View {
    @StateObject private var syncService = iCloudSyncService.shared
    @ObservedObject private var membership = MembershipController.shared
    @State private var membershipPaywallContext: MembershipPaywallContext?
    @State private var showMigrationPreparationError = false
    @State private var showMigrationResolutionError = false
    @State private var migrationAssessment: CloudMigrationAssessment?
    @State private var isMigrationConflictPresented = false
    @AppStorage("app.sync.icloudMigrationNeedsRelaunch") private var migrationNeedsRelaunch = false
    private let onPrepareMigration: (() throws -> Void)?
    private let hasPendingMigration: (() -> Bool)?
    private let onMigrationAssessment: (() throws -> CloudMigrationAssessment?)?
    private let onResolveMigration: ((CloudMigrationConflictStrategy) throws -> Void)?

    public init(
        onPrepareMigration: (() throws -> Void)? = nil,
        hasPendingMigration: (() -> Bool)? = nil,
        onMigrationAssessment: (() throws -> CloudMigrationAssessment?)? = nil,
        onResolveMigration: ((CloudMigrationConflictStrategy) throws -> Void)? = nil
    ) {
        self.onPrepareMigration = onPrepareMigration
        self.hasPendingMigration = hasPendingMigration
        self.onMigrationAssessment = onMigrationAssessment
        self.onResolveMigration = onResolveMigration
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // iCloud Sync Toggle
                syncToggleCard

                // Network Status
                networkStatusCard

                // iCloud Status
                icloudStatusCard

                // Sync Status
                syncStatusCard

                if syncService.isSyncEnabled, migrationNeedsRelaunch, hasPendingMigration?() == true {
                    migrationRelaunchCard
                } else if migrationNeedsRelaunch {
                    storageRestartCard
                } else if syncService.isSyncEnabled, hasPendingMigration?() == true, onMigrationAssessment != nil {
                    migrationReviewCard
                }

                // Manual Sync Button
                if syncService.isSyncEnabled {
                    manualSyncButton
                }

                // Info
                syncInfoCard
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.syncSettings")
        .background(NumiColor.surfacePage)
        .navigationTitle(Text(NumiLocalized.string("sync.title")))
        .modifier(LargeTitleNavigationChrome())
        .task { await membership.start() }
        .membershipPaywall(context: $membershipPaywallContext)
        .alert(NumiLocalized.string("sync.migration.prepare.failure.title"), isPresented: $showMigrationPreparationError) {
            Button(NumiLocalized.string("common.ok"), role: .cancel) {}
        } message: {
            Text(NumiLocalized.string("sync.migration.prepare.failure.message"))
        }
        .alert(NumiLocalized.string("sync.migration.resolve.failure.title"), isPresented: $showMigrationResolutionError) {
            Button(NumiLocalized.string("common.ok"), role: .cancel) {}
        } message: {
            Text(NumiLocalized.string("sync.migration.resolve.failure.message"))
        }
        .sheet(isPresented: $isMigrationConflictPresented) {
            if let migrationAssessment {
                CloudMigrationConflictSheet(assessment: migrationAssessment) { strategy in
                    resolveMigration(strategy)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Sync Toggle Card

    private var syncToggleCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "icloud")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NumiLocalized.string("sync.enable"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(NumiLocalized.string("sync.enable.desc"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { syncService.isSyncEnabled },
                    set: { setSyncEnabled($0) }
                ))
                .labelsHidden()
                .tint(NumiColor.accentDeep)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 14)

            if syncService.isSyncEnabled {
                Divider()
                    .padding(.leading, 36 + NumiSpacing.s3)

                // Cellular sync toggle
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.iconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NumiLocalized.string("sync.cellular"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("sync.cellular.desc"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { syncService.isCellularSyncEnabled },
                        set: { _ in syncService.toggleCellularSync() }
                    ))
                    .labelsHidden()
                    .tint(NumiColor.accentDeep)
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)
            }
        }
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Network Status Card

    private func setSyncEnabled(_ isEnabled: Bool) {
        guard isEnabled != syncService.isSyncEnabled else { return }
        guard isEnabled else {
            syncService.toggleSync()
            migrationNeedsRelaunch = true
            return
        }
        switch membership.decision(for: .openICloudSync) {
        case .granted:
            do {
                try onPrepareMigration?()
            } catch {
                showMigrationPreparationError = true
                return
            }
            syncService.toggleSync()
            migrationNeedsRelaunch = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private var migrationRelaunchCard: some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            Image(systemName: "arrow.clockwise.icloud")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(NumiLocalized.string("sync.migration.restart.title"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(NumiLocalized.string("sync.migration.restart.message"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var storageRestartCard: some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(NumiLocalized.string("sync.storage.restart.title"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(NumiLocalized.string("sync.storage.restart.message"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var migrationReviewCard: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NumiLocalized.string("sync.migration.review"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(NumiLocalized.string("sync.migration.pending"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(NumiLocalized.string("sync.migration.review")) {
                prepareMigrationReview()
            }
            .buttonStyle(.borderedProminent)
            .tint(NumiColor.accentPrimary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .disabled(!hasObservedInitialCloudSync)
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var hasObservedInitialCloudSync: Bool {
        if case .success = syncService.syncStatus { return true }
        return false
    }

    private func prepareMigrationReview() {
        do {
            guard let assessment = try onMigrationAssessment?() else { return }
            migrationAssessment = assessment
            isMigrationConflictPresented = true
        } catch {
            showMigrationResolutionError = true
        }
    }

    private func resolveMigration(_ strategy: CloudMigrationConflictStrategy) {
        do {
            try onResolveMigration?(strategy)
            isMigrationConflictPresented = false
            migrationAssessment = nil
        } catch {
            showMigrationResolutionError = true
        }
    }

    private var networkStatusCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: syncService.networkType.icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(NumiLocalized.string("sync.network.status"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(syncService.isNetworkAvailable ? syncService.networkType.displayName : NumiLocalized.string( "sync.network.not.connected"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            Circle()
                .fill(syncService.isNetworkAvailable ? NumiColor.positiveText : NumiColor.negativeText)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 14)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - iCloud Status Card

    private var icloudStatusCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: syncService.isiCloudAvailable ? "checkmark.icloud" : "icloud.slash")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(NumiLocalized.string("sync.icloud.connection"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(syncService.isiCloudAvailable ? NumiLocalized.string( "sync.icloud.connected") : NumiLocalized.string( "sync.icloud.unavailable"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            Circle()
                .fill(syncService.isiCloudAvailable ? NumiColor.positiveText : NumiColor.negativeText)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 14)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: statusIcon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(NumiLocalized.string("sync.status"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(statusText)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)

                if case .scheduled(let requestedAt) = syncService.syncStatus {
                    Text(NumiLocalized.string(
                        "sync.requested.at",
                        requestedAt.numiFormatted(.dateTime.month().day().hour().minute())
                    ))
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
                } else if let lastDate = syncService.lastSyncDate {
                    Text(NumiLocalized.string(
                        "sync.last.completed",
                        lastDate.numiFormatted(.dateTime.month().day().hour().minute())
                    ))
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 14)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NumiLocalized.string("sync.status"))
        .accessibilityValue(statusAccessibilityValue)
    }

    // MARK: - Manual Sync Button

    private var manualSyncButton: some View {
        Button {
            Task {
                await syncService.performSync()
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous)
                        .fill(NumiColor.iconBackground)
                        .frame(width: 36, height: 36)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NumiColor.accentPrimary)
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NumiLocalized.string("sync.manual"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    if case .scheduled(let requestedAt) = syncService.syncStatus {
                        Text(NumiLocalized.string(
                            "sync.requested.at",
                            requestedAt.numiFormatted(.dateTime.month().day().hour().minute())
                        ))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                    } else if let lastDate = syncService.lastSyncDate {
                        Text(NumiLocalized.string("sync.last.completed", lastDate.numiFormatted(.dateTime.month().day().hour().minute())))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isSyncRequestScheduled {
                    Label(NumiLocalized.string("sync.requested"), systemImage: "clock")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)
                } else {
                    Text(NumiLocalized.string("sync.button"))
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.accentDeep)
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 14)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isSyncRequestInFlight)
    }

    private var isSyncing: Bool {
        if case .syncing = syncService.syncStatus { return true }
        return false
    }

    private var isSyncRequestInFlight: Bool {
        switch syncService.syncStatus {
        case .syncing, .scheduled:
            true
        default:
            false
        }
    }

    private var isSyncRequestScheduled: Bool {
        if case .scheduled = syncService.syncStatus { return true }
        return false
    }

    // MARK: - Info Card

    private var syncInfoCard: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string("sync.notes"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
            Text(NumiLocalized.string("sync.notes.detail"))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(NumiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Status Helpers

    private var statusIcon: String {
        switch syncService.syncStatus {
        case .idle: return "arrow.clockwise.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .scheduled: return "clock.arrow.circlepath"
        case .success: return "checkmark.circle"
        case .failure: return "exclamationmark.circle"
        }
    }

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .success:
            NumiColor.positiveText
        case .failure:
            NumiColor.negativeText
        case .scheduled:
            NumiColor.textSecondary
        case .idle, .syncing:
            NumiColor.accentPrimary
        }
    }

    private var statusText: String {
        syncService.syncStatus.displayMessage
    }

    private var statusAccessibilityValue: String {
        switch syncService.syncStatus {
        case .scheduled(let requestedAt):
            let requestTime = NumiLocalized.string(
                "sync.requested.at",
                requestedAt.numiFormatted(.dateTime.month().day().hour().minute())
            )
            return "\(statusText). \(requestTime)"
        case .idle, .syncing, .failure:
            return statusText
        case .success(let completedAt):
            let completionTime = NumiLocalized.string(
                "sync.last.completed",
                completedAt.numiFormatted(.dateTime.month().day().hour().minute())
            )
            return "\(statusText). \(completionTime)"
        }
    }
}
