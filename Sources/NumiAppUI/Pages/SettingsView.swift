import SwiftUI
import LocalAuthentication
import NumiCore

public struct SettingsView: View {
    enum AIKeyTestFailure: Equatable {
        case emptyKey
        case unknownProvider
        case invalidURL
        case unauthorized
        case httpStatus(Int)
        case transport(String)

        var displayMessage: String {
            switch self {
            case .emptyKey:
                return NumiLocalized.string("setting.ai.error.empty.key")
            case .unknownProvider:
                return NumiLocalized.string("setting.ai.error.unknown")
            case .invalidURL:
                return NumiLocalized.string("setting.ai.error.invalid.url")
            case .unauthorized:
                return NumiLocalized.string("setting.ai.error.unauthorized")
            case .httpStatus(let statusCode):
                return NumiLocalized.string("setting.ai.test.fail", statusCode)
            case .transport(let description):
                return NumiLocalized.string("setting.ai.test.fail", description)
            }
        }
    }

    private let categories: [NumiCore.Category]
    private let accounts: [Account]
    private let transactions: [NumiCore.Transaction]
    private let ledgers: [Ledger]
    private let currentLedgerID: UUID?
    private let ledgerTransactionCounts: [UUID: Int]
    private let exportSnapshot: (() -> BookkeepingSnapshot)?
    private let importSnapshot: ((BookkeepingSnapshot) throws -> Void)?
    private let onManageLedgers: () -> Void
    private let onCategoryVisibilityChange: (NumiCore.Category, Bool) -> Void
    private let onAccountVisibilityChange: (Account, Bool) -> Void
    private let onAccountCreate: (AccountDraft) -> Void
    private let onAccountUpdate: (Account, AccountDraft) -> Void
    private let onCategoryCreate: ((CategoryKind, String, String) -> Void)?
    private let onCategoryDelete: ((NumiCore.Category) -> Void)?
    private let onAccountDelete: ((Account) -> Void)?

    @AppStorage("app.privacy.lockEnabled") private var isLockEnabled = false
    @AppStorage("app.privacy.autoBlur") private var isAutoBlurEnabled = false
    @AppStorage("app.privacy.lockMethod") private var lockMethod: String = "biometric"
    @AppStorage("app.privacy.passcode") private var storedPasscode: String = ""
    @State private var showLockMethodSheet = false
    @State private var showPasscodeSetup = false
    @State private var passcodeMode: PasscodeMode = .setup
    @State private var showLanguageSheet = false
    @AppStorage("app.language") private var languageCode: String = "system"

    @AppStorage("app.ai.provider") private var aiProvider: String = "claude"
    @AppStorage("app.ai.claudeAPIKey") private var claudeAPIKey: String = ""
    @AppStorage("app.ai.qwenAPIKey") private var qwenAPIKey: String = ""
    @AppStorage("app.ai.deepseekAPIKey") private var deepseekAPIKey: String = ""
    @State private var showAIKeySheet = false
    @State private var editingProvider: String = "claude"
    @State private var editingClaudeKey: String = ""
    @State private var editingQwenKey: String = ""
    @State private var editingDeepseekKey: String = ""
    @State private var isTestingKey = false
    @State private var testResult: TestResult?

    private enum TestResult: Equatable {
        case success
        case failure(AIKeyTestFailure)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            if case .failure(let failure) = self { return failure.displayMessage }
            return ""
        }
    }

    public init(
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        transactions: [NumiCore.Transaction] = [],
        ledgers: [Ledger] = [],
        currentLedgerID: UUID? = nil,
        ledgerTransactionCounts: [UUID: Int] = [:],
        exportSnapshot: (() -> BookkeepingSnapshot)? = nil,
        importSnapshot: ((BookkeepingSnapshot) throws -> Void)? = nil,
        onManageLedgers: @escaping () -> Void = {},
        onCategoryVisibilityChange: @escaping (NumiCore.Category, Bool) -> Void = { _, _ in },
        onAccountVisibilityChange: @escaping (Account, Bool) -> Void = { _, _ in },
        onAccountCreate: @escaping (AccountDraft) -> Void = { _ in },
        onAccountUpdate: @escaping (Account, AccountDraft) -> Void = { _, _ in },
        onCategoryCreate: ((CategoryKind, String, String) -> Void)? = nil,
        onCategoryDelete: ((NumiCore.Category) -> Void)? = nil,
        onAccountDelete: ((Account) -> Void)? = nil
    ) {
        self.categories = categories
        self.accounts = accounts
        self.transactions = transactions
        self.ledgers = ledgers
        self.currentLedgerID = currentLedgerID
        self.ledgerTransactionCounts = ledgerTransactionCounts
        self.exportSnapshot = exportSnapshot
        self.importSnapshot = importSnapshot
        self.onManageLedgers = onManageLedgers
        self.onCategoryVisibilityChange = onCategoryVisibilityChange
        self.onAccountVisibilityChange = onAccountVisibilityChange
        self.onAccountCreate = onAccountCreate
        self.onAccountUpdate = onAccountUpdate
        self.onCategoryCreate = onCategoryCreate
        self.onCategoryDelete = onCategoryDelete
        self.onAccountDelete = onAccountDelete
    }

    public var body: some View {
        NumiBottomAccessoryTrackingScrollView(accessibilityIdentifier: "scroll.settingsHome") {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 统计小卡片
                statsRow

                settingsSection(
                    title: NumiLocalized.string( "setting.data"),
                    accessibilityID: "settings.section.data",
                    cardAccessibilityID: "settings.card.data"
                ) {
                    Button {
                        onManageLedgers()
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.ledger"), icon: "book")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.ledgers")

                    NavigationLink {
                        CategoryManagementView(
                            categories: categories,
                            onVisibilityChange: onCategoryVisibilityChange,
                            onCategoryCreate: onCategoryCreate,
                            onCategoryDelete: onCategoryDelete
                        )
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.category"), icon: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.categories")

                    NavigationLink {
                        AccountManagementView(
                            accounts: accounts,
                            transactions: transactions,
                            categories: categories,
                            onVisibilityChange: onAccountVisibilityChange,
                            onCreate: onAccountCreate,
                            onUpdate: onAccountUpdate,
                            onDelete: onAccountDelete
                        )
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.account"), icon: "creditcard")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.accounts")

                    NavigationLink {
                        CurrencyManagementView()
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.multi.currency"), icon: "dollarsign.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.currency")

                    NavigationLink {
                        SyncSettingsView()
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.icloud.sync"), icon: "icloud")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.sync")

                    if let export = exportSnapshot, let importFn = importSnapshot {
                        NavigationLink {
                            DataManagementView(exportSnapshot: export, importSnapshot: importFn)
                        } label: {
                            settingsRow(NumiLocalized.string( "setting.import.export"), icon: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.importExport")

                        NavigationLink {
                            BackupView(exportSnapshot: export, importSnapshot: importFn)
                        } label: {
                            settingsRow(NumiLocalized.string( "setting.local.backup"), icon: "lock.doc")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.backup")
                    }
                }

                settingsSection(
                    title: NumiLocalized.string( "setting.security"),
                    accessibilityID: "settings.section.security",
                    cardAccessibilityID: "settings.card.security"
                ) {
                    privacyLockRow
                    if isLockEnabled {
                        lockMethodRow
                        if lockMethod == "passcode" || lockMethod == "both" {
                            changePasscodeRow
                        }
                    }
                    autoBlurRow
                }

                settingsSection(
                    title: NumiLocalized.string( "setting.appearance"),
                    accessibilityID: "settings.section.appearance",
                    cardAccessibilityID: "settings.card.appearance"
                ) {
                    Button {
                        showLanguageSheet = true
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.language"), icon: "globe", trailingText: currentLanguageName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.language")

                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        settingsRow(NumiLocalized.string( "setting.theme"), icon: "paintpalette")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.theme")
                }

                settingsSection(
                    title: NumiLocalized.string( "setting.ai.service"),
                    accessibilityID: "settings.section.ai",
                    cardAccessibilityID: "settings.card.ai"
                ) {
                    Button {
                        showAIKeySheet = true
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            Image(systemName: "brain")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(NumiColor.iconBackground)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .foregroundStyle(NumiColor.accentPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("setting.ai.config")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(NumiColor.textPrimary)
                                Text(currentProviderDisplayName)
                                    .font(NumiFont.footnote)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }

                            Spacer(minLength: NumiSpacing.s3)

                            if hasAPIKey {
                                Circle()
                                    .fill(NumiColor.positiveText)
                                    .frame(width: 8, height: 8)
                            } else {
                                Circle()
                                    .fill(NumiColor.textTertiary)
                                    .frame(width: 8, height: 8)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NumiColor.surfaceCard)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.ai")
                    .sheet(isPresented: $showAIKeySheet) {
                        aiConfigSheet
                            .presentationDetents([.height(420)])
                            .presentationCornerRadius(28)
                            .onAppear {
                                editingProvider = aiProvider
                                editingClaudeKey = claudeAPIKey
                                editingQwenKey = qwenAPIKey
                                editingDeepseekKey = deepseekAPIKey
                            }
                    }
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("setting.title")
        .modifier(LargeTitleNavigationChrome())
        .sheet(isPresented: $showLanguageSheet) {
            languageSheet
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
    }

    static func providerDisplayName(for providerID: String) -> String {
        switch providerID {
        case "claude":
            return NumiLocalized.string("setting.ai.provider.claude")
        case "qwen":
            return NumiLocalized.string("setting.ai.provider.qwen")
        case "deepseek":
            return NumiLocalized.string("setting.ai.provider.deepseek")
        default:
            return providerID
        }
    }

    // MARK: - Language

    private var currentLanguageName: String {
        NumiAppLanguage.displayName(for: languageCode)
    }

    private struct LangOption: Identifiable {
        let id: String
        let title: String
    }

    private var languageOptions: [LangOption] {
        NumiAppLanguage.allCases.map { .init(id: $0.rawValue, title: $0.displayName) }
    }

    private var languageSheet: some View {
        NumiBottomSheet(
            title: NumiLocalized.string( "setting.language"),
            contentMode: .scroll,
            accessibilityPrefix: "sheet.language",
            dismissTitle: NumiLocalized.string( "common.close"),
            onDismiss: { showLanguageSheet = false }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(languageOptions.enumerated()), id: \.element.id) { index, option in
                    let isSelected = languageCode == option.id
                    Button {
                        guard !isSelected else { return }
                        UserDefaults.standard.set(option.id, forKey: NumiAppLanguage.pendingToastDefaultsKey)
                        languageCode = option.id
                        showLanguageSheet = false
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            Text(option.title)
                                .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(NumiColor.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("language.\(option.id)")

                    if index < languageOptions.count - 1 {
                        Divider().padding(.leading, NumiSpacing.s4)
                    }
                }
            }
            .padding(.bottom, NumiSpacing.s4)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: NumiSpacing.s2) {
            statCard(title: NumiLocalized.string( "setting.stat.days"), value: "\(recordDays)")
            statCard(title: NumiLocalized.string( "setting.stat.avg.expense"), value: avgDailyExpense)
            statCard(title: NumiLocalized.string( "setting.stat.max.expense"), value: topExpenseCategory)
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: NumiSpacing.s2) {
            Text(value)
                .font(NumiFont.title)
                .foregroundStyle(NumiColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var recordDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(transactions.map { calendar.startOfDay(for: $0.occurredAt) })
        return uniqueDays.count
    }

    private var avgDailyExpense: String {
        let expenses = transactions.filter { $0.type == .expense }
        guard !expenses.isEmpty else { return "¥0" }
        let total = expenses.reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        let days = max(recordDays, 1)
        let avg = total / Int64(days)
        return Money(minorUnits: avg, currencyCode: "CNY").formatted()
    }

    private var topExpenseCategory: String {
        let expenses = transactions.filter { $0.type == .expense }
        guard !expenses.isEmpty else { return "-" }
        var categoryTotals: [UUID: Int64] = [:]
        for tx in expenses {
            guard let catID = tx.categoryID else { continue }
            categoryTotals[catID, default: 0] += tx.amount.minorUnits
        }
        guard let topID = categoryTotals.max(by: { $0.value < $1.value })?.key else { return "-" }
        return categories.first { $0.id == topID }?.localizedDisplayName ?? "-"
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        accessibilityID: String,
        cardAccessibilityID: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // cardAccessibilityID reserved for future stable selectors
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .accessibilityIdentifier(accessibilityID)

            VStack(spacing: 0) {
                content()
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private var privacyLockRow: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: "faceid")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text("setting.privacy.lock")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            Toggle("", isOn: $isLockEnabled)
                .labelsHidden()
                .tint(NumiColor.accentDeep)
                .accessibilityIdentifier("toggle.privacyLock")
                .onChange(of: isLockEnabled) { _, newValue in
                    if newValue {
                        showLockMethodSheet = true
                    }
                }
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .sheet(isPresented: $showLockMethodSheet) {
            lockMethodSheet
                .presentationDetents([.height(280)])
                .presentationCornerRadius(28)
        }
    }

    private var lockMethodRow: some View {
        Button {
            showLockMethodSheet = true
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                Text("setting.unlock.method")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer(minLength: NumiSpacing.s3)

                Text(lockMethodDisplayName)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.lockMethod")
    }

    private var lockMethodDisplayName: String {
        switch lockMethod {
        case "biometric":
            return NumiLocalized.string( "setting.lock.biometric")
        case "passcode":
            return NumiLocalized.string( "setting.lock.passcode")
        case "both":
            return NumiLocalized.string( "setting.lock.both")
        default:
            return NumiLocalized.string( "setting.lock.biometric")
        }
    }

    private var changePasscodeRow: some View {
        Button {
            passcodeMode = .change
            showPasscodeSetup = true
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "key")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(NumiColor.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                Text("setting.change.password")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer(minLength: NumiSpacing.s3)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPasscodeSetup) {
            NumiPasscodeSheet(
                isPresented: $showPasscodeSetup,
                mode: passcodeMode
            )
            .presentationDetents([.height(480)])
            .presentationCornerRadius(28)
        }
    }

    private var autoBlurRow: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: "eye.slash")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text("setting.auto.blur")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            Toggle("", isOn: $isAutoBlurEnabled)
                .labelsHidden()
                .tint(NumiColor.accentDeep)
                .accessibilityIdentifier("toggle.autoBlur")
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
    }

    private var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private var lockMethodSheet: some View {
        NumiOptionSheet(
            title: NumiLocalized.string( "setting.unlock.method"),
            options: [
                NumiOptionItem(
                    id: "biometric",
                    icon: "faceid",
                    title: NumiLocalized.string( "setting.lock.biometric"),
                    subtitle: isBiometricAvailable ? NumiLocalized.string( "setting.lock.biometric.desc") : NumiLocalized.string( "setting.lock.biometric.unavailable"),
                    isDisabled: !isBiometricAvailable
                ),
                NumiOptionItem(
                    id: "passcode",
                    icon: "key.fill",
                    title: NumiLocalized.string( "setting.lock.passcode"),
                    subtitle: NumiLocalized.string( "setting.lock.passcode.desc")
                ),
                NumiOptionItem(
                    id: "both",
                    icon: "lock.fill",
                    title: NumiLocalized.string( "setting.lock.both"),
                    subtitle: isBiometricAvailable ? NumiLocalized.string( "setting.lock.both.desc") : NumiLocalized.string( "setting.lock.biometric.unavailable"),
                    isDisabled: !isBiometricAvailable
                )
            ],
            selectedID: lockMethod,
            onSelect: { option in
                lockMethod = option.id
                if option.id == "passcode" || option.id == "both" {
                    if storedPasscode.isEmpty {
                        passcodeMode = .setup
                        showPasscodeSetup = true
                    }
                }
                showLockMethodSheet = false
            },
            onDismiss: {
                showLockMethodSheet = false
            }
        )
    }

    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = NumiLocalized.string( "security.verify.to.enable")
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = NumiLocalized.string( "security.verify.to.enable")
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    private func settingsRow(_ title: String, icon: String, trailingText: String? = nil) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            if let trailingText {
                Text(trailingText)
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NumiColor.textTertiary)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
    }

    // MARK: - AI Config Helpers

    private var currentProviderDisplayName: String {
        Self.providerDisplayName(for: aiProvider)
    }

    private var hasAPIKey: Bool {
        switch aiProvider {
        case "claude": return !claudeAPIKey.isEmpty
        case "qwen": return !qwenAPIKey.isEmpty
        case "deepseek": return !deepseekAPIKey.isEmpty
        default: return false
        }
    }

    // MARK: - AI Config Sheet

    private var aiConfigSheet: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    showAIKeySheet = false
                } label: {
                    Text("common.cancel")
                        .font(NumiFont.body)
                        .foregroundStyle(NumiColor.toolbarIcon)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("setting.ai.config")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)

                Spacer()

                Button {
                    // 保存到持久化
                    aiProvider = editingProvider
                    claudeAPIKey = editingClaudeKey
                    qwenAPIKey = editingQwenKey
                    deepseekAPIKey = editingDeepseekKey
                    // 同步到 App Group UserDefaults（供 Intents 扩展读取）
                    if let defaults = UserDefaults(suiteName: "group.com.numi.shared") {
                        defaults.set(editingProvider, forKey: "app.ai.provider")
                        defaults.set(editingClaudeKey, forKey: "app.ai.claudeAPIKey")
                        defaults.set(editingQwenKey, forKey: "app.ai.qwenAPIKey")
                        defaults.set(editingDeepseekKey, forKey: "app.ai.deepseekAPIKey")
                    }
                    showAIKeySheet = false
                } label: {
                    Text("common.save")
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.accentDeep)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: NumiSpacing.s4) {
                    // Provider picker - TabView
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        Text("setting.ai.select.provider")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)

                        Picker("setting.ai.provider", selection: $editingProvider) {
                            Text("setting.ai.provider.claude").tag("claude")
                            Text("setting.ai.provider.qwen").tag("qwen")
                            Text("setting.ai.provider.deepseek").tag("deepseek")
                        }
                        .pickerStyle(.segmented)
                    }

                    // API Key input
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        Text("setting.ai.api.key")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)

                        SecureField(NumiLocalized.string("setting.ai.enter.key", editingProviderDisplayName), text: editingAPIKeyBinding)
                            .font(NumiFont.body)
                            .padding(.horizontal, NumiSpacing.s3)
                            .padding(.vertical, 12)
                            .background(NumiColor.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                    }

                    // Test button
                    Button {
                        isTestingKey = true
                        testResult = nil
                        Task {
                            let result = await testCurrentAPIKey()
                            isTestingKey = false
                            testResult = result
                        }
                    } label: {
                        HStack(spacing: NumiSpacing.s2) {
                            if isTestingKey {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(isTestingKey ? NumiLocalized.string( "testing") : NumiLocalized.string( "setting.ai.test.connection"))
                                .font(NumiFont.bodySmall)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(currentEditingKey.isEmpty ? NumiColor.textTertiary : NumiColor.accentDeep)
                        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTestingKey || currentEditingKey.isEmpty)

                    // Test result
                    if let testResult {
                        HStack(spacing: NumiSpacing.s2) {
                            Image(systemName: testResult.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(testResult.isSuccess ? NumiColor.positiveText : NumiColor.negativeText)
                            Text(testResult.isSuccess ? NumiLocalized.string("setting.ai.test.success") : testResult.message)
                                .font(NumiFont.footnote)
                                .foregroundStyle(testResult.isSuccess ? NumiColor.positiveText : NumiColor.negativeText)
                        }
                        .transition(.opacity)
                    }

                    // Description
                    Text("setting.ai.api.key.desc")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)

                    // Provider info
                    VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                        Text("setting.ai.providers.title")
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textSecondary)
                        Text("setting.ai.providers.detail")
                            .font(NumiFont.caption)
                            .foregroundStyle(NumiColor.textTertiary)
                    }
                }
                .padding(.horizontal, NumiSpacing.s4)
                .padding(.bottom, NumiSpacing.s6)
            }
        }
        .background(NumiColor.surfacePage)
    }

    private var editingProviderDisplayName: String {
        Self.providerDisplayName(for: editingProvider)
    }

    private var editingAPIKeyBinding: Binding<String> {
        switch editingProvider {
        case "claude": return $editingClaudeKey
        case "qwen": return $editingQwenKey
        case "deepseek": return $editingDeepseekKey
        default: return $editingClaudeKey
        }
    }

    private var currentEditingKey: String {
        switch editingProvider {
        case "claude": return editingClaudeKey
        case "qwen": return editingQwenKey
        case "deepseek": return editingDeepseekKey
        default: return ""
        }
    }

    private func testCurrentAPIKey() async -> TestResult {
        let key = currentEditingKey
        guard !key.isEmpty else { return .failure(.emptyKey) }

        switch editingProvider {
        case "claude":
            return await testClaude(key: key)
        case "qwen":
            return await testQwen(key: key)
        case "deepseek":
            return await testDeepSeek(key: key)
        default:
            return .failure(.unknownProvider)
        }
    }

    private func testClaude(key: String) async -> TestResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .failure(.invalidURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 16,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await executeTest(request: request)
    }

    private func testQwen(key: String) async -> TestResult {
        guard let url = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions") else {
            return .failure(.invalidURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "model": "qwen-turbo",
            "max_tokens": 16,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await executeTest(request: request)
    }

    private func testDeepSeek(key: String) async -> TestResult {
        guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
            return .failure(.invalidURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "max_tokens": 16,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await executeTest(request: request)
    }

    private func executeTest(request: URLRequest) async -> TestResult {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidURL)
            }
            if httpResponse.statusCode == 200 {
                return .success
            } else if httpResponse.statusCode == 401 {
                return .failure(.unauthorized)
            } else {
                return .failure(.httpStatus(httpResponse.statusCode))
            }
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }
}

struct LargeTitleNavigationChrome: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.large)
        #else
        content
        #endif
    }
}
