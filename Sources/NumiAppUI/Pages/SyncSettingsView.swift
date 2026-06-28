import SwiftUI
import Network
import Combine
import NumiCore

// MARK: - Sync Status

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case failure(SyncFailureReason)

    var displayMessage: String {
        switch self {
        case .idle:
            return NumiLocalized.string("sync.status.waiting")
        case .syncing:
            return NumiLocalized.string("sync.status.syncing")
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
    public var onPerformSync: (() async -> Bool)?

    public func performSync() async {
        guard isSyncEnabled else { return }
        guard isNetworkAvailable else {
            syncStatus = .failure(.networkUnavailable)
            return
        }
        guard isiCloudAvailable else {
            syncStatus = .failure(.iCloudUnavailable)
            return
        }

        if networkType == .cellular && !isCellularSyncEnabled {
            syncStatus = .failure(.cellularDisabled)
            return
        }

        syncStatus = .syncing
        syncProgress = 0

        if let onPerformSync {
            let success = await onPerformSync()
            if success {
                let now = Date()
                lastSyncDate = now
                defaults.set(now, forKey: "app.sync.lastSyncDate")
                syncStatus = .success(now)
                syncProgress = 1.0
            } else {
                syncStatus = .failure(.syncFailed)
            }
        } else {
            // 模拟同步
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let now = Date()
            lastSyncDate = now
            defaults.set(now, forKey: "app.sync.lastSyncDate")
            syncStatus = .success(now)
            syncProgress = 1.0
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
        DispatchQueue.global(qos: .background).async { [weak self] in
            let available = FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
            DispatchQueue.main.async {
                self?.isiCloudAvailable = available
            }
        }
    }

    /// 监听 CloudKit 同步事件
    private func observeSyncEvents() {
        // NSPersistentCloudKitContainer 发送同步事件通知
        eventObservation = NotificationCenter.default
            .publisher(for: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                // 从通知中提取同步进度
                if let event = notification.userInfo?["event"] as? NSObject {
                    let typeName = String(describing: type(of: event))
                    if typeName.contains("Setup") {
                        self.syncProgress = 0.1
                    } else if typeName.contains("Import") {
                        self.syncProgress = 0.5
                    } else if typeName.contains("Export") {
                        self.syncProgress = 0.8
                    }
                }
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

    public init() {}

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
        .navigationTitle(Text("sync.title"))
        .modifier(LargeTitleNavigationChrome())
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
                    Text("sync.enable")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text("sync.enable.desc")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { syncService.isSyncEnabled },
                    set: { _ in syncService.toggleSync() }
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
                        Text("sync.cellular")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("sync.cellular.desc")
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

    private var networkStatusCard: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: syncService.networkType.icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("sync.network.status")
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
                Text("sync.icloud.connection")
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
                .foregroundStyle(NumiColor.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("sync.status")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(statusText)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            if let lastDate = syncService.lastSyncDate {
                Text(lastDate.numiFormatted(.dateTime.month().day().hour().minute()))
                    .font(NumiFont.caption)
                    .foregroundStyle(NumiColor.textTertiary)
            }
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 14)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
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
                    Text("sync.manual")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    if let lastDate = syncService.lastSyncDate {
                        Text(NumiLocalized.string("sync.last.time", lastDate.numiFormatted(.dateTime.month().day().hour().minute())))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("sync.button")
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
        .disabled(isSyncing)
    }

    private var isSyncing: Bool {
        if case .syncing = syncService.syncStatus { return true }
        return false
    }

    // MARK: - Info Card

    private var syncInfoCard: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text("sync.notes")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
            Text("sync.notes.detail")
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
        case .success: return "checkmark.circle"
        case .failure: return "exclamationmark.circle"
        }
    }

    private var statusText: String {
        syncService.syncStatus.displayMessage
    }
}
