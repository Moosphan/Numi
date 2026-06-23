import SwiftUI
import NumiCore
#if canImport(UIKit)
import UIKit
#endif

public struct NumiAmountKeypad: View {
    enum KeyStyle: String {
        case neutral
        case accent
        case dateAccent
    }

    @Binding private var state: MoneyInputState
    private let dateShortcutTitle: String
    private let dateAccessorySystemImage: String
    private let onDateShortcut: () -> Void

    public init(
        state: Binding<MoneyInputState>,
        dateShortcutTitle: String = "今天",
        dateAccessorySystemImage: String = "calendar",
        onDateShortcut: @escaping () -> Void = {}
    ) {
        self._state = state
        self.dateShortcutTitle = dateShortcutTitle
        self.dateAccessorySystemImage = dateAccessorySystemImage
        self.onDateShortcut = onDateShortcut
    }

    public var body: some View {
        keypadGrid
    }

    private var keypadGrid: some View {
        let keys = [
            ["7", "8", "9", dateShortcutTitle],
            ["4", "5", "6", "-"],
            ["1", "2", "3", "+"],
            [".", "0", "delete.left", "="]
        ]

        return VStack(spacing: NumiSpacing.s2) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: NumiSpacing.s2) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handle(key)
                        } label: {
                            keyLabel(key)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(keyBackground(key))
                                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                .shadow(
                                    color: keyShadowColor(key),
                                    radius: keyShadowRadius(key),
                                    x: 0,
                                    y: keyShadowYOffset(key)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("keypad.\(accessibilityKeyName(key))")
                        .accessibilityValue("style.\(keyStyle(for: key).rawValue)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyLabel(_ key: String) -> some View {
        if key == "delete.left" {
            Image(systemName: key)
                .font(.system(size: 20, weight: .semibold))
        } else if key == dateShortcutTitle {
            HStack(spacing: 3) {
                Text(key)
                    .font(dateLabelFont(for: key))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                if showsDateAccessoryIcon(for: key) {
                    Image(systemName: dateAccessorySystemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Text(key)
                .font(NumiFont.bodyStrong)
        }
    }

    private func keyBackground(_ key: String) -> Color {
        switch keyStyle(for: key) {
        case .neutral:
            return neutralKeyBackground
        case .accent:
            return NumiColor.controlFillStrong.opacity(0.72)
        case .dateAccent:
            return NumiColor.controlFill
        }
    }

    private func keyShadowColor(_ key: String) -> Color {
        switch keyStyle(for: key) {
        case .neutral:
            return .black.opacity(0.035)
        case .accent, .dateAccent:
            return .clear
        }
    }

    private func keyShadowRadius(_ key: String) -> CGFloat {
        keyStyle(for: key) == .neutral ? 6 : 0
    }

    private func keyShadowYOffset(_ key: String) -> CGFloat {
        keyStyle(for: key) == .neutral ? 2 : 0
    }

    func keyStyle(for key: String) -> KeyStyle {
        if key == dateShortcutTitle {
            return .dateAccent
        }
        if ["+", "-", "="].contains(key) {
            return .neutral
        }
        return .neutral
    }

    private var neutralKeyBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemGray6)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    private func showsDateAccessoryIcon(for key: String) -> Bool {
        ["今天", "昨天", "前天"].contains(key)
    }

    private func dateLabelFont(for key: String) -> Font {
        if showsDateAccessoryIcon(for: key) {
            return NumiFont.bodyStrong
        }
        return .system(size: 15, weight: .semibold)
    }

    private func handle(_ key: String) {
        switch key {
        case "delete.left":
            state.apply(.delete)
        case dateShortcutTitle:
            onDateShortcut()
        default:
            state.apply(.token(key))
        }
    }

    private func accessibilityKeyName(_ key: String) -> String {
        if key == dateShortcutTitle {
            return "openDatePicker"
        }
        switch key {
        case "delete.left":
            return "delete"
        case ".":
            return "decimal"
        case "+":
            return "plus"
        case "-":
            return "minus"
        case "=":
            return "equals"
        default:
            return key
        }
    }
}
