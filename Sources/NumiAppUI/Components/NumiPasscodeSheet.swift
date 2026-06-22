import SwiftUI
import LocalAuthentication
import NumiCore

public enum PasscodeMode {
    case setup
    case change
    case verify
}

public struct NumiPasscodeSheet: View {
    @Binding private var isPresented: Bool
    private let mode: PasscodeMode
    private let onVerified: () -> Void

    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var currentPasscode: String = ""
    @State private var step: PasscodeStep = .enter
    @State private var error: String?
    @State private var digits: [String] = Array(repeating: "", count: 6)

    @AppStorage("app.privacy.passcode") private var storedPasscode: String = ""

    private enum PasscodeStep {
        case enter
        case confirm
        case currentPasscode
    }

    public init(
        isPresented: Binding<Bool>,
        mode: PasscodeMode = .setup,
        onVerified: @escaping () -> Void = {}
    ) {
        self._isPresented = isPresented
        self.mode = mode
        self.onVerified = onVerified
    }

    public var body: some View {
        NumiBottomSheet(
            title: stepTitle,
            contentMode: .fit,
            grabberTopPadding: 5,
            grabberBottomPadding: 0,
            headerBottomPadding: 4,
            accessibilityPrefix: "sheet.passcode",
            dismissTitle: "取消",
            onDismiss: {
                isPresented = false
            }
        ) {
            VStack(spacing: NumiSpacing.s2) {
                // Header
                VStack(spacing: NumiSpacing.s2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(NumiColor.accentDeep)

                    Text(stepSubtitle)
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 0)

                // Passcode dots
                HStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(index < currentInput.count ? NumiColor.accentDeep : NumiColor.surfaceCardSubtle)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle()
                                    .strokeBorder(NumiColor.separator, lineWidth: 1)
                            }
                    }
                }
                .padding(.vertical, NumiSpacing.s2)

                // Error message
                if let error {
                    Text(error)
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.negativeText)
                        .transition(.opacity)
                }

                // Number pad
                VStack(spacing: 12) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 24) {
                            ForEach(1...3, id: \.self) { col in
                                let number = row * 3 + col
                                numberButton("\(number)")
                            }
                        }
                    }
                    HStack(spacing: 24) {
                        // Empty space
                        Color.clear
                            .frame(width: 72, height: 72)

                        numberButton("0")

                        // Delete button
                        Button {
                            deleteDigit()
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(NumiColor.textPrimary)
                                .frame(width: 72, height: 72)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentInput.isEmpty)
                        .accessibilityIdentifier("sheet.passcode.delete")
                    }
                }
                .padding(.bottom, NumiSpacing.s4)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.top, 0)
        }
        .onAppear {
            if mode == .verify {
                step = .enter
            } else if mode == .change {
                step = .currentPasscode
            }
        }
    }

    private var currentInput: String {
        switch step {
        case .enter:
            return passcode
        case .confirm:
            return confirmPasscode
        case .currentPasscode:
            return currentPasscode
        }
    }

    private var stepTitle: String {
        switch mode {
        case .setup:
            return step == .enter ? "设置密码" : "确认密码"
        case .change:
            if step == .currentPasscode {
                return "输入当前密码"
            }
            return step == .enter ? "设置新密码" : "确认新密码"
        case .verify:
            return "输入密码"
        }
    }

    private var stepSubtitle: String {
        switch mode {
        case .setup:
            return step == .enter ? "设置6位数字密码" : "再次输入密码确认"
        case .change:
            if step == .currentPasscode {
                return "验证当前密码"
            }
            return step == .enter ? "设置新的6位数字密码" : "再次输入新密码确认"
        case .verify:
            return "输入密码以解锁应用"
        }
    }

    private func numberButton(_ number: String) -> some View {
        Button {
            addDigit(number)
        } label: {
            Text(number)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)
                .frame(width: 64, height: 64)
                .background(NumiColor.surfaceCard)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isInputFull)
        .accessibilityIdentifier("sheet.passcode.key.\(number)")
    }

    private var isInputFull: Bool {
        currentInput.count >= 6
    }

    private func addDigit(_ digit: String) {
        error = nil

        switch step {
        case .enter:
            if passcode.count < 6 {
                passcode += digit
                if passcode.count == 6 {
                    handlePasscodeComplete()
                }
            }
        case .confirm:
            if confirmPasscode.count < 6 {
                confirmPasscode += digit
                if confirmPasscode.count == 6 {
                    handleConfirmComplete()
                }
            }
        case .currentPasscode:
            if currentPasscode.count < 6 {
                currentPasscode += digit
                if currentPasscode.count == 6 {
                    handleCurrentPasscodeComplete()
                }
            }
        }
    }

    private func deleteDigit() {
        error = nil

        switch step {
        case .enter:
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        case .confirm:
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            }
        case .currentPasscode:
            if !currentPasscode.isEmpty {
                currentPasscode.removeLast()
            }
        }
    }

    private func handlePasscodeComplete() {
        switch mode {
        case .setup:
            step = .confirm
        case .change:
            step = .confirm
        case .verify:
            if passcode == storedPasscode {
                onVerified()
                isPresented = false
            } else {
                error = "密码错误"
                passcode = ""
            }
        }
    }

    private func handleConfirmComplete() {
        if passcode == confirmPasscode {
            storedPasscode = passcode
            onVerified()
            isPresented = false
        } else {
            error = "两次密码不一致"
            passcode = ""
            confirmPasscode = ""
            step = .enter
        }
    }

    private func handleCurrentPasscodeComplete() {
        if currentPasscode == storedPasscode {
            passcode = ""
            step = .enter
        } else {
            error = "当前密码错误"
            currentPasscode = ""
        }
    }
}

// MARK: - Lock Screen View

public struct NumiLockScreen: View {
    @Binding private var isLocked: Bool
    @AppStorage("app.privacy.passcode") private var storedPasscode: String = ""
    @AppStorage("app.privacy.lockMethod") private var lockMethod: String = "biometric"

    @State private var showPasscodeEntry = false
    @State private var passcode: String = ""
    @State private var error: String?

    public init(isLocked: Binding<Bool>) {
        self._isLocked = isLocked
    }

    public var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: NumiSpacing.s4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(NumiColor.textSecondary)

                Text("应用已锁定")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)

                if showPasscodeEntry {
                    // Passcode entry
                    VStack(spacing: NumiSpacing.s3) {
                        // Passcode dots
                        HStack(spacing: 16) {
                            ForEach(0..<6, id: \.self) { index in
                                Circle()
                                    .fill(index < passcode.count ? NumiColor.accentDeep : NumiColor.surfaceCardSubtle)
                                    .frame(width: 16, height: 16)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(NumiColor.separator, lineWidth: 1)
                                    }
                            }
                        }

                        if let error {
                            Text(error)
                                .font(NumiFont.footnote)
                                .foregroundStyle(NumiColor.negativeText)
                        }

                        // Number pad
                        VStack(spacing: 12) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 24) {
                                    ForEach(1...3, id: \.self) { col in
                                        let number = row * 3 + col
                                        numberButton("\(number)")
                                    }
                                }
                            }
                            HStack(spacing: 24) {
                                Color.clear
                                    .frame(width: 72, height: 72)

                                numberButton("0")

                                Button {
                                    if !passcode.isEmpty {
                                        passcode.removeLast()
                                        error = nil
                                    }
                                } label: {
                                    Image(systemName: "delete.left")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(NumiColor.textPrimary)
                                        .frame(width: 72, height: 72)
                                }
                                .buttonStyle(.plain)
                                .disabled(passcode.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal, NumiSpacing.s5)
                } else {
                    // Unlock buttons
                    VStack(spacing: NumiSpacing.s3) {
                        if lockMethod == "biometric" || lockMethod == "both" {
                            Button {
                                authenticateWithBiometric()
                            } label: {
                                HStack {
                                    Image(systemName: biometricIcon)
                                        .font(.system(size: 20, weight: .medium))
                                    Text(biometricTitle)
                                        .font(NumiFont.bodyStrong)
                                }
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 48)
                                .background(NumiColor.accentDeep)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if lockMethod == "passcode" || lockMethod == "both" {
                            Button {
                                withAnimation {
                                    showPasscodeEntry = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 20, weight: .medium))
                                    Text("密码解锁")
                                        .font(NumiFont.bodyStrong)
                                }
                                .foregroundStyle(NumiColor.textPrimary)
                                .frame(width: 200, height: 48)
                                .background(NumiColor.surfaceCard)
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if lockMethod == "biometric" {
                            Button {
                                withAnimation {
                                    showPasscodeEntry = true
                                }
                            } label: {
                                Text("使用密码")
                                    .font(NumiFont.bodySmall)
                                    .foregroundStyle(NumiColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType == .faceID ? "faceid" : "touchid"
        }
        return "faceid"
    }

    private var biometricTitle: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType == .faceID ? "Face ID 解锁" : "Touch ID 解锁"
        }
        return "生物识别解锁"
    }

    private func numberButton(_ number: String) -> some View {
        Button {
            addDigit(number)
        } label: {
            Text(number)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(NumiColor.textPrimary)
                .frame(width: 72, height: 72)
                .background(NumiColor.surfaceCard)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(passcode.count >= 6)
    }

    private func addDigit(_ digit: String) {
        error = nil
        if passcode.count < 6 {
            passcode += digit
            if passcode.count == 6 {
                verifyPasscode()
            }
        }
    }

    private func verifyPasscode() {
        if passcode == storedPasscode {
            withAnimation(.easeOut(duration: 0.4)) {
                isLocked = false
            }
        } else {
            error = "密码错误"
            passcode = ""
        }
    }

    private func authenticateWithBiometric() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "验证身份以解锁应用"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.easeOut(duration: 0.4)) {
                            isLocked = false
                        }
                    }
                }
            }
        }
    }
}
