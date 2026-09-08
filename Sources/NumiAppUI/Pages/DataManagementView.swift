import SwiftUI
import UniformTypeIdentifiers
import NumiCore

// MARK: - Share URL Wrapper

private struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private func localizedImportErrorDetail(_ error: Error) -> String {
    guard let validationError = error as? SnapshotImportValidationError else {
        return error.localizedDescription
    }

    switch validationError {
    case .convertedAmountCurrencyMismatch:
        return NumiLocalized.string("io.import.error.converted.amount.currency.mismatch")
    }
}

// MARK: - Data Management View

public struct DataManagementView: View {
    private let exportSnapshot: () -> BookkeepingSnapshot
    private let importSnapshot: (BookkeepingSnapshot) throws -> Void
    private let appendTransactions: ([NumiCore.Transaction]) throws -> Void
    private let recoveryPointService: ImportRecoveryPointService

    @State private var showImportJSON = false
    @State private var showImportCSV = false
    @State private var showCSVImportReview = false
    @State private var csvImportDocument: CSVImportDocument?
    @State private var csvImportSnapshot: BookkeepingSnapshot?
    @State private var hasImportRecoveryPoint: Bool
    @State private var showRestoreRecoveryConfirmation = false
    @State private var shareURL: ShareableURL?
    @State private var toastMessage: String?
    @State private var showToast = false

    public init(
        exportSnapshot: @escaping () -> BookkeepingSnapshot,
        importSnapshot: @escaping (BookkeepingSnapshot) throws -> Void,
        appendTransactions: @escaping ([NumiCore.Transaction]) throws -> Void,
        recoveryPointService: ImportRecoveryPointService = .shared
    ) {
        self.exportSnapshot = exportSnapshot
        self.importSnapshot = importSnapshot
        self.appendTransactions = appendTransactions
        self.recoveryPointService = recoveryPointService
        _hasImportRecoveryPoint = State(initialValue: recoveryPointService.hasRecoveryPoint)
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                    exportSection
                    importSection
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("scroll.dataManagement")
            .background(NumiColor.surfacePage)
            .navigationTitle(NumiLocalized.string("io.title"))
            .modifier(LargeTitleNavigationChrome())

            // Toast
            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    NumiToastView(message: msg)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showToast)
            }
        }
        .sheet(item: $shareURL) { item in
#if canImport(UIKit)
            NumiShareSheet(items: [item.url]) {
                showToastMessage(NumiLocalized.string( "io.saved"))
            }
#endif
        }
        .alert(NumiLocalized.string("io.import.restore.confirm.title"), isPresented: $showRestoreRecoveryConfirmation) {
            Button(NumiLocalized.string("io.import.restore.confirm.action"), role: .destructive) {
                restoreRecoveryPoint()
            }
            Button(NumiLocalized.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(NumiLocalized.string("io.import.restore.confirm.message"))
        }
        .sheet(isPresented: $showCSVImportReview) {
            if let csvImportDocument, let csvImportSnapshot {
                CSVImportReviewSheet(
                    document: csvImportDocument,
                    snapshot: csvImportSnapshot,
                    onImport: importCSVTransactions
                )
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("io.export"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                // Export JSON
                Button {
                    exportJSON()
                } label: {
                    exportRow(
                        icon: "doc.text",
                        title: NumiLocalized.string( "io.export.json"),
                        subtitle: NumiLocalized.string( "io.export.json.desc")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("io.export.json")

                Divider().padding(.leading, 48)

                // Export CSV
                Button {
                    exportCSV()
                } label: {
                    exportRow(
                        icon: "tablecells",
                        title: NumiLocalized.string( "io.export.csv"),
                        subtitle: NumiLocalized.string( "io.export.csv.desc")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("io.export.csv")
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("io.import"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                // Import JSON
                Button {
                    showImportJSON = true
                } label: {
                    exportRow(
                        icon: "square.and.arrow.down",
                        title: NumiLocalized.string( "io.import.json"),
                        subtitle: NumiLocalized.string( "io.import.json.desc")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("io.import.json")
                .fileImporter(
                    isPresented: $showImportJSON,
                    allowedContentTypes: [.json]
                ) { result in
                    handleImport(result)
                }

                Divider().padding(.leading, 48)

                Button {
                    showImportCSV = true
                } label: {
                    exportRow(
                        icon: "tablecells.badge.ellipsis",
                        title: NumiLocalized.string("io.import.csv"),
                        subtitle: NumiLocalized.string("io.import.csv.desc")
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("io.import.csv")
                .fileImporter(
                    isPresented: $showImportCSV,
                    allowedContentTypes: [.commaSeparatedText]
                ) { result in
                    handleCSVImport(result)
                }

                Divider().padding(.leading, 48)

                Button {
                    showRestoreRecoveryConfirmation = true
                } label: {
                    exportRow(
                        icon: "arrow.uturn.backward.circle",
                        title: NumiLocalized.string("io.import.restore.previous"),
                        subtitle: NumiLocalized.string("io.import.restore.previous.desc")
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasImportRecoveryPoint)
                .accessibilityIdentifier("io.import.restorePrevious")
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)

            Text(NumiLocalized.string("io.import.warning"))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
        }
    }

    // MARK: - Helpers

    private func exportRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(subtitle)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 14)
    }

    private func exportJSON() {
        let snapshot = exportSnapshot()
        let result = BackupService.shared.exportJSON(snapshot: snapshot)
        switch result {
        case .success(let url):
            shareURL = ShareableURL(url: url)
        case .failure(let error):
            showToastMessage(error.displayMessage)
        }
    }

    private func exportCSV() {
        let snapshot = exportSnapshot()
        let result = BackupService.shared.exportCSV(snapshot: snapshot)
        switch result {
        case .success(let url):
            shareURL = ShareableURL(url: url)
        case .failure(let error):
            showToastMessage(error.displayMessage)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                // 确保能访问安全范围资源
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                try importDecodedSnapshot(BackupService.shared.importJSON(from: url))
            } catch let error as ImportRecoveryPointError {
                showToastMessage(error.displayMessage)
            } catch {
                showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
            }
        case .failure(let error):
            showToastMessage(NumiLocalized.string("io.import.file.fail", error.localizedDescription))
        }
    }

    private func importDecodedSnapshot(_ snapshot: BookkeepingSnapshot) throws {
        let currentSnapshot = exportSnapshot()
        try recoveryPointService.save(currentSnapshot)
        hasImportRecoveryPoint = true

        do {
            try importSnapshot(snapshot)
            showToastMessage(NumiLocalized.string("io.import.success.withRecovery", snapshot.transactions.count))
        } catch {
            let importError = error
            do {
                try importSnapshot(currentSnapshot)
                try recoveryPointService.discard()
                hasImportRecoveryPoint = false
                showToastMessage(NumiLocalized.string("io.import.rollback.success", localizedImportErrorDetail(importError)))
            } catch {
                showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
            }
        }
    }

    private func restoreRecoveryPoint() {
        do {
            try importSnapshot(recoveryPointService.load())
            try recoveryPointService.discard()
            hasImportRecoveryPoint = false
            showToastMessage(NumiLocalized.string("io.import.restore.success"))
        } catch let error as ImportRecoveryPointError {
            showToastMessage(error.displayMessage)
        } catch {
            showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
        }
    }

    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard let csv = String(data: data, encoding: .utf8) else {
                    throw CSVImportDocumentError.missingHeader
                }
                let snapshot = exportSnapshot()
                guard !snapshot.ledgers.isEmpty else {
                    showToastMessage(NumiLocalized.string("io.import.csv.no.ledger"))
                    return
                }
                csvImportDocument = try CSVImportDocument(csv: csv)
                csvImportSnapshot = snapshot
                showCSVImportReview = true
            } catch {
                showToastMessage(NumiLocalized.string("io.import.csv.file.fail", error.localizedDescription))
            }
        case .failure(let error):
            showToastMessage(NumiLocalized.string("io.import.csv.file.fail", error.localizedDescription))
        }
    }

    private func importCSVTransactions(_ transactions: [NumiCore.Transaction]) {
        let currentSnapshot = exportSnapshot()
        do {
            try recoveryPointService.save(currentSnapshot)
        } catch let error as ImportRecoveryPointError {
            showToastMessage(error.displayMessage)
            return
        } catch {
            showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
            return
        }

        do {
            try appendTransactions(transactions)
            hasImportRecoveryPoint = true
            showToastMessage(NumiLocalized.string("io.import.csv.success", transactions.count))
        } catch {
            let importError = error
            do {
                try importSnapshot(currentSnapshot)
                try recoveryPointService.discard()
                hasImportRecoveryPoint = false
                showToastMessage(NumiLocalized.string("io.import.rollback.success", localizedImportErrorDetail(importError)))
            } catch {
                showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
            }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
        }
    }
}

// MARK: - Backup View

public struct BackupView: View {
    private let exportSnapshot: () -> BookkeepingSnapshot
    private let importSnapshot: (BookkeepingSnapshot) throws -> Void

    @ObservedObject private var membership = MembershipController.shared
    @State private var backupPassword = ""
    @State private var restorePassword = ""
    @State private var showBackupFile = false
    @State private var showRestoreFile = false
    @State private var shareURL: ShareableURL?
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var membershipPaywallContext: MembershipPaywallContext?
    @AppStorage("app.backup.reminder.enabled") private var isBackupReminderEnabled = false
    @AppStorage("app.backup.reminder.intervalDays") private var backupReminderIntervalDays = 14
    @AppStorage("app.backup.reminder.lastBackupAt") private var lastBackupTimestamp = 0.0

    public init(
        exportSnapshot: @escaping () -> BookkeepingSnapshot,
        importSnapshot: @escaping (BookkeepingSnapshot) throws -> Void
    ) {
        self.exportSnapshot = exportSnapshot
        self.importSnapshot = importSnapshot
    }

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                    createBackupSection
                    backupReminderSection
                    restoreBackupSection
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("scroll.backupManagement")
            .background(NumiColor.surfacePage)
            .navigationTitle(NumiLocalized.string("backup.title"))
            .modifier(LargeTitleNavigationChrome())

            // Toast
            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    NumiToastView(message: msg)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: showToast)
            }
        }
        .sheet(item: $shareURL) { item in
#if canImport(UIKit)
            NumiShareSheet(items: [item.url])
#endif
        }
        .task { await membership.start() }
        .onChange(of: backupReminderIntervalDays) { _, _ in
            guard isBackupReminderEnabled else { return }
            Task {
                let schedulingSucceeded = await scheduleBackupReminder()
                isBackupReminderEnabled = BackupReminderPreferencePolicy.enabledValue(
                    requestedEnabled: true,
                    schedulingSucceeded: schedulingSucceeded
                )
            }
        }
        .membershipPaywall(context: $membershipPaywallContext)
    }

    // MARK: - Create Backup

    private var createBackupSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("backup.create"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            // Info row
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "lock.doc")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NumiLocalized.string("backup.encrypted"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(NumiLocalized.string("backup.encrypted.desc"))
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)

            // Password input card
            HStack(spacing: NumiSpacing.s3) {
                Text(NumiLocalized.string("backup.password"))
                    .font(NumiFont.body)
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer()

                SecureField("backup.set.password", text: $backupPassword)
                    .font(NumiFont.body)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)

            // Create button
            Button {
                startCreatingBackup()
            } label: {
                let isEnabled = !backupPassword.isEmpty
                HStack {
                    Spacer()
                    Text(NumiLocalized.string("backup.create"))
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(isEnabled ? .white : NumiColor.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                        .fill(isEnabled ? NumiColor.accentDeep : {
                            #if canImport(UIKit)
                            Color(uiColor: .systemGray5)
                            #else
                            Color.gray.opacity(0.16)
                            #endif
                        }())
                )
                .animation(.easeInOut(duration: 0.2), value: isEnabled)
            }
            .buttonStyle(.plain)
            .disabled(backupPassword.isEmpty)
        }
    }

    private var backupReminderSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("backup.reminder.title"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.iconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NumiLocalized.string("backup.reminder.enable"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("backup.reminder.desc"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isBackupReminderEnabled },
                        set: { configureBackupReminder($0) }
                    ))
                    .labelsHidden()
                    .tint(NumiColor.accentDeep)
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)

                if isBackupReminderEnabled {
                    Divider().padding(.leading, 48)
                    Picker(NumiLocalized.string("backup.reminder.interval"), selection: $backupReminderIntervalDays) {
                        Text(NumiLocalized.string("backup.reminder.interval.7")).tag(7)
                        Text(NumiLocalized.string("backup.reminder.interval.14")).tag(14)
                        Text(NumiLocalized.string("backup.reminder.interval.30")).tag(30)
                    }
                    .font(NumiFont.body)
                    .padding(.horizontal, NumiSpacing.s4)
                    .padding(.vertical, 8)
                }
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .accessibilityIdentifier("backup.reminder")
    }

    // MARK: - Restore Backup

    private var restoreBackupSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("backup.restore"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            HStack(spacing: NumiSpacing.s3) {
                Text(NumiLocalized.string("backup.password"))
                    .font(NumiFont.body)
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer()

                SecureField("backup.password", text: $restorePassword)
                    .font(NumiFont.body)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("backup.restore.password")
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)

            Button {
                showRestoreFile = true
            } label: {
                HStack(spacing: NumiSpacing.s3) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(NumiColor.iconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                        .foregroundStyle(NumiColor.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NumiLocalized.string("backup.restore.from"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("backup.restore.file.hint"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.vertical, 14)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(restorePassword.isEmpty)
            .accessibilityIdentifier("backup.restore.selectFile")
            .fileImporter(
                isPresented: $showRestoreFile,
                allowedContentTypes: [.data]
            ) { result in
                handleRestore(result)
            }

            Text(NumiLocalized.string("backup.restore.warning"))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.negativeText)
        }
    }

    // MARK: - Actions

    private func startCreatingBackup() {
        switch membership.decision(for: .openEncryptedBackup) {
        case .granted:
            createBackup()
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func createBackup() {
        let snapshot = exportSnapshot()
        let result = BackupService.shared.createBackup(snapshot: snapshot, password: backupPassword)
        switch result {
        case .success(let url):
            lastBackupTimestamp = Date().timeIntervalSince1970
            if isBackupReminderEnabled {
                Task {
                    let schedulingSucceeded = await scheduleBackupReminder()
                    isBackupReminderEnabled = BackupReminderPreferencePolicy.enabledValue(
                        requestedEnabled: true,
                        schedulingSucceeded: schedulingSucceeded
                    )
                }
            }
            shareURL = ShareableURL(url: url)
            // 延迟显示 toast，避免与分享面板冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showToastMessage(NumiLocalized.string( "backup.success"))
            }
        case .failure(let error):
            showToastMessage(error.displayMessage)
        }
    }

    private func configureBackupReminder(_ isEnabled: Bool) {
        guard isEnabled else {
            isBackupReminderEnabled = false
            BackupReminderScheduler.cancel()
            return
        }
        switch membership.decision(for: .openEncryptedBackup) {
        case .granted:
            Task {
                guard await BackupReminderScheduler.requestAuthorization() else {
                    showToastMessage(NumiLocalized.string("backup.reminder.authorization.failed"))
                    return
                }
                let schedulingSucceeded = await scheduleBackupReminder()
                isBackupReminderEnabled = BackupReminderPreferencePolicy.enabledValue(
                    requestedEnabled: true,
                    schedulingSucceeded: schedulingSucceeded
                )
            }
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func scheduleBackupReminder() async -> Bool {
        let lastBackupAt = lastBackupTimestamp > 0 ? Date(timeIntervalSince1970: lastBackupTimestamp) : nil
        let schedulingSucceeded = await BackupReminderScheduler.schedule(
            lastBackupAt: lastBackupAt,
            intervalDays: backupReminderIntervalDays
        )
        guard schedulingSucceeded else {
            showToastMessage(NumiLocalized.string("backup.reminder.schedule.failed"))
            return false
        }
        return true
    }

    private func handleRestore(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            switch BackupService.shared.restoreBackup(from: url, password: restorePassword) {
            case .success(let snapshot):
                do {
                    try importSnapshot(snapshot)
                    showToastMessage(NumiLocalized.string("backup.restore.success", snapshot.transactions.count))
                } catch {
                    showToastMessage(NumiLocalized.string("io.import.fail", localizedImportErrorDetail(error)))
                }
            case .failure(let error):
                showToastMessage(error.displayMessage)
            }
        case .failure(let error):
            showToastMessage(NumiLocalized.string("io.import.file.fail", error.localizedDescription))
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
        }
    }
}
