import SwiftUI
import UniformTypeIdentifiers
import NumiCore

// MARK: - Share URL Wrapper

private struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
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
            .navigationTitle("io.title")
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
        .alert("io.import.restore.confirm.title", isPresented: $showRestoreRecoveryConfirmation) {
            Button("io.import.restore.confirm.action", role: .destructive) {
                restoreRecoveryPoint()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("io.import.restore.confirm.message")
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
            Text("io.export")
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
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("io.import")
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

            Text("io.import.warning")
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
                showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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
                showToastMessage(NumiLocalized.string("io.import.rollback.success", importError.localizedDescription))
            } catch {
                showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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
            showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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
            showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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
                showToastMessage(NumiLocalized.string("io.import.rollback.success", importError.localizedDescription))
            } catch {
                showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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

    @State private var backupPassword = ""
    @State private var restorePassword = ""
    @State private var showBackupFile = false
    @State private var showRestoreFile = false
    @State private var shareURL: ShareableURL?
    @State private var toastMessage: String?
    @State private var showToast = false

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
                    restoreBackupSection
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("scroll.backupManagement")
            .background(NumiColor.surfacePage)
            .navigationTitle("backup.title")
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
    }

    // MARK: - Create Backup

    private var createBackupSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("backup.create")
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
                    Text("backup.encrypted")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text("backup.encrypted.desc")
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
                Text("backup.password")
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
                createBackup()
            } label: {
                let isEnabled = !backupPassword.isEmpty
                HStack {
                    Spacer()
                    Text("backup.create")
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

    // MARK: - Restore Backup

    private var restoreBackupSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("backup.restore")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            HStack(spacing: NumiSpacing.s3) {
                Text("backup.password")
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
                        Text("backup.restore.from")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("backup.restore.file.hint")
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

            Text("backup.restore.warning")
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.negativeText)
        }
    }

    // MARK: - Actions

    private func createBackup() {
        let snapshot = exportSnapshot()
        let result = BackupService.shared.createBackup(snapshot: snapshot, password: backupPassword)
        switch result {
        case .success(let url):
            shareURL = ShareableURL(url: url)
            // 延迟显示 toast，避免与分享面板冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showToastMessage(NumiLocalized.string( "backup.success"))
            }
        case .failure(let error):
            showToastMessage(error.displayMessage)
        }
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
                    showToastMessage(NumiLocalized.string("io.import.fail", error.localizedDescription))
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
