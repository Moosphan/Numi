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

    @AppStorage("app.privacy.lockEnabled") private var isLockEnabled = false
    @AppStorage("app.privacy.autoBlur") private var isAutoBlurEnabled = false
    @AppStorage("app.privacy.lockMethod") private var lockMethod: String = "biometric"
    @AppStorage("app.privacy.passcode") private var storedPasscode: String = ""
    @State private var showLockMethodSheet = false
    @State private var showPasscodeSetup = false
    @State private var passcodeMode: PasscodeMode = .setup

    public init(
        categories: [NumiCore.Category] = [],
        accounts: [Account] = [],
        onCategoryVisibilityChange: @escaping (NumiCore.Category, Bool) -> Void = { _, _ in },
        onAccountVisibilityChange: @escaping (Account, Bool) -> Void = { _, _ in },
        onAccountCreate: @escaping (AccountDraft) -> Void = { _ in },
        onAccountUpdate: @escaping (Account, AccountDraft) -> Void = { _, _ in }
    ) {
        self.categories = categories
        self.accounts = accounts
        self.onCategoryVisibilityChange = onCategoryVisibilityChange
        self.onAccountVisibilityChange = onAccountVisibilityChange
        self.onAccountCreate = onAccountCreate
        self.onAccountUpdate = onAccountUpdate
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
                            onVisibilityChange: onCategoryVisibilityChange
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
                            onUpdate: onAccountUpdate
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
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NumiColor.separator, lineWidth: 1)
            }
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
