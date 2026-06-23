import SwiftUI
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

    @State private var showImportJSON = false
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
                    exportSection
                    importSection
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("scroll.dataManagement")
            .background(NumiColor.surfacePage)
            .navigationTitle("导入与导出")
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
            NumiShareSheet(items: [item.url]) {
                showToastMessage("已保存")
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("导出数据")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                // Export JSON
                Button {
                    exportJSON()
                } label: {
                    exportRow(
                        icon: "doc.text",
                        title: "导出完整数据 (JSON)",
                        subtitle: "包含账户、分类、交易、预算、订阅等所有数据"
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
                        title: "导出交易记录 (CSV)",
                        subtitle: "仅导出交易记录，可用 Excel 打开"
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
            Text("导入数据")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                // Import JSON
                Button {
                    showImportJSON = true
                } label: {
                    exportRow(
                        icon: "square.and.arrow.down",
                        title: "从 JSON 导入",
                        subtitle: "导入之前导出的完整数据备份"
                    )
                }
                .buttonStyle(.plain)
                .fileImporter(
                    isPresented: $showImportJSON,
                    allowedContentTypes: [.json]
                ) { result in
                    handleImport(result)
                }
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)

            Text("导入会覆盖当前数据，建议先导出备份。")
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
        case .failure(let msg):
            showToastMessage(msg)
        }
    }

    private func exportCSV() {
        let snapshot = exportSnapshot()
        let result = BackupService.shared.exportCSV(snapshot: snapshot)
        switch result {
        case .success(let url):
            shareURL = ShareableURL(url: url)
        case .failure(let msg):
            showToastMessage(msg)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                // 确保能访问安全范围资源
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let snapshot = try BackupService.shared.importJSON(from: url)
                try importSnapshot(snapshot)
                showToastMessage("导入成功，共 \(snapshot.transactions.count) 笔交易")
            } catch {
                showToastMessage("导入失败：\(error.localizedDescription)")
            }
        case .failure(let error):
            showToastMessage("选择文件失败：\(error.localizedDescription)")
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
            .navigationTitle("本地备份")
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
            NumiShareSheet(items: [item.url])
        }
    }

    // MARK: - Create Backup

    private var createBackupSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text("创建备份")
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
                    Text("加密备份")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text("使用 AES-GCM 加密，保护数据隐私")
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
                Text("备份密码")
                    .font(NumiFont.body)
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer()

                SecureField("设置密码", text: $backupPassword)
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
                    Text("创建备份")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(isEnabled ? .white : NumiColor.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous)
                        .fill(isEnabled ? NumiColor.accentDeep : Color(.systemGray5))
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
            Text("恢复备份")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

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
                        Text("从备份恢复")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(NumiColor.textPrimary)
                        Text("选择 .numibackup 文件并输入密码")
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
            .fileImporter(
                isPresented: $showRestoreFile,
                allowedContentTypes: [.data]
            ) { result in
                handleRestore(result)
            }

            Text("恢复会覆盖当前所有数据，请确保已备份当前数据。")
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
                showToastMessage("备份创建成功")
            }
        case .failure(let msg):
            showToastMessage(msg)
        }
    }

    private func handleRestore(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showToastMessage("请选择备份文件并输入密码")
        case .failure(let error):
            showToastMessage("选择文件失败：\(error.localizedDescription)")
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
