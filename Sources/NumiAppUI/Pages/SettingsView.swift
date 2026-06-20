import SwiftUI
import LocalAuthentication
import NumiCore

public struct SettingsView: View {
    private let categories: [NumiCore.Category]
    private let accounts: [Account]
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
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            if case .failure(let msg) = self { return msg }
            return ""
        }
    }

    public init(
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
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
        self.onCategoryVisibilityChange = onCategoryVisibilityChange
        self.onAccountVisibilityChange = onAccountVisibilityChange
        self.onAccountCreate = onAccountCreate
        self.onAccountUpdate = onAccountUpdate
        self.onCategoryCreate = onCategoryCreate
        self.onCategoryDelete = onCategoryDelete
        self.onAccountDelete = onAccountDelete
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                settingsSection(
                    title: "数据",
                    accessibilityID: "settings.section.data",
                    cardAccessibilityID: "settings.card.data"
                ) {
                    NavigationLink {
                        CategoryManagementView(
                            categories: categories,
                            onVisibilityChange: onCategoryVisibilityChange,
                            onCategoryCreate: onCategoryCreate,
                            onCategoryDelete: onCategoryDelete
                        )
                    } label: {
                        settingsRow("分类管理", icon: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.categories")

                    NavigationLink {
                        AccountManagementView(
                            accounts: accounts,
                            onVisibilityChange: onAccountVisibilityChange,
                            onCreate: onAccountCreate,
                            onUpdate: onAccountUpdate,
                            onDelete: onAccountDelete
                        )
                    } label: {
                        settingsRow("账户管理", icon: "creditcard")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.accounts")

                    NavigationLink {
                        CurrencyManagementView()
                    } label: {
                        settingsRow("多货币管理", icon: "dollarsign.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.currency")

                    settingsRow("导入与导出", icon: "square.and.arrow.up")
                    settingsRow("本地备份", icon: "lock.doc")
                }

                settingsSection(
                    title: "安全",
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
                    title: "外观",
                    accessibilityID: "settings.section.appearance",
                    cardAccessibilityID: "settings.card.appearance"
                ) {
                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        settingsRow("主题", icon: "paintpalette")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.theme")
                }

                settingsSection(
                    title: "AI 服务",
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
                                .background(NumiColor.accentPrimary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .foregroundStyle(NumiColor.accentPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI 服务配置")
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
        .navigationTitle("我的")
        .modifier(LargeTitleNavigationChrome())
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        accessibilityID: String,
        cardAccessibilityID: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
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
            .accessibilityIdentifier(cardAccessibilityID)
        }
    }

    private var privacyLockRow: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: "faceid")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text("隐私锁")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            Toggle("", isOn: $isLockEnabled)
                .labelsHidden()
                .tint(NumiColor.accentDeep)
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
                    .background(NumiColor.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                Text("解锁方式")
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
    }

    private var lockMethodDisplayName: String {
        switch lockMethod {
        case "biometric":
            return "生物识别"
        case "passcode":
            return "数字密码"
        case "both":
            return "生物识别 + 密码"
        default:
            return "生物识别"
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
                    .background(NumiColor.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                    .foregroundStyle(NumiColor.accentPrimary)

                Text("修改密码")
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
                .background(NumiColor.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text("后台自动模糊")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

            Toggle("", isOn: $isAutoBlurEnabled)
                .labelsHidden()
                .tint(NumiColor.accentDeep)
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
            title: "解锁方式",
            options: [
                NumiOptionItem(
                    id: "biometric",
                    icon: "faceid",
                    title: "生物识别",
                    subtitle: isBiometricAvailable ? "使用 Face ID 或 Touch ID" : "设备不支持生物识别",
                    isDisabled: !isBiometricAvailable
                ),
                NumiOptionItem(
                    id: "passcode",
                    icon: "key.fill",
                    title: "数字密码",
                    subtitle: "使用6位数字密码解锁"
                ),
                NumiOptionItem(
                    id: "both",
                    icon: "lock.fill",
                    title: "生物识别 + 密码",
                    subtitle: isBiometricAvailable ? "两种方式都可使用" : "设备不支持生物识别",
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
            let reason = "验证身份以启用隐私锁"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "验证身份以启用隐私锁"
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

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(NumiColor.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                .foregroundStyle(NumiColor.accentPrimary)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)

            Spacer(minLength: NumiSpacing.s3)

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
        switch aiProvider {
        case "claude": return "Claude (Anthropic)"
        case "qwen": return "通义千问 (阿里)"
        case "deepseek": return "DeepSeek"
        default: return aiProvider
        }
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
                    Text("取消")
                        .font(NumiFont.body)
                        .foregroundStyle(NumiColor.toolbarIcon)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("AI 服务配置")
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
                    Text("保存")
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
                        Text("选择服务商")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)

                        Picker("服务商", selection: $editingProvider) {
                            Text("Claude").tag("claude")
                            Text("千问").tag("qwen")
                            Text("DeepSeek").tag("deepseek")
                        }
                        .pickerStyle(.segmented)
                    }

                    // API Key input
                    VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                        Text("API Key")
                            .font(NumiFont.bodySmall)
                            .foregroundStyle(NumiColor.textSecondary)

                        SecureField("输入 \(editingProviderDisplayName) API Key", text: editingAPIKeyBinding)
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
                            Text(isTestingKey ? "测试中..." : "测试连接")
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
                            Text(testResult.isSuccess ? "连接成功，API Key 有效" : "连接失败：\(testResult.message)")
                                .font(NumiFont.footnote)
                                .foregroundStyle(testResult.isSuccess ? NumiColor.positiveText : NumiColor.negativeText)
                        }
                        .transition(.opacity)
                    }

                    // Description
                    Text("API Key 用于 Siri 语音记账功能，调用 AI 解析账单文本。密钥存储在本地，不会上传到任何服务器。")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)

                    // Provider info
                    VStack(alignment: .leading, spacing: NumiSpacing.s1) {
                        Text("各服务商说明：")
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textSecondary)
                        Text("• Claude: api.anthropic.com，推荐 Haiku 模型\n• 千问: dashscope.aliyuncs.com，推荐 qwen-turbo\n• DeepSeek: api.deepseek.com，推荐 deepseek-chat")
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
        switch editingProvider {
        case "claude": return "Claude (Anthropic)"
        case "qwen": return "通义千问 (阿里)"
        case "deepseek": return "DeepSeek"
        default: return editingProvider
        }
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
        guard !key.isEmpty else { return .failure("请先输入 API Key") }

        switch editingProvider {
        case "claude":
            return await testClaude(key: key)
        case "qwen":
            return await testQwen(key: key)
        case "deepseek":
            return await testDeepSeek(key: key)
        default:
            return .failure("未知服务商")
        }
    }

    private func testClaude(key: String) async -> TestResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .failure("URL 无效")
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
            return .failure("URL 无效")
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
            return .failure("URL 无效")
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
                return .failure("响应无效")
            }
            if httpResponse.statusCode == 200 {
                return .success
            } else if httpResponse.statusCode == 401 {
                return .failure("API Key 无效 (401)")
            } else {
                return .failure("服务器错误 (\(httpResponse.statusCode))")
            }
        } catch {
            return .failure(error.localizedDescription)
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
