import SwiftUI
import NumiCore

public struct NumiAmountKeypad: View {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("keypad.\(accessibilityKeyName(key))")
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
            HStack(spacing: 4) {
                Text(key)
                    .font(NumiFont.bodyStrong)
                Image(systemName: dateAccessorySystemImage)
                    .font(.system(size: 13, weight: .semibold))
            }
        } else {
            Text(key)
                .font(NumiFont.bodyStrong)
        }
    }

    private func keyBackground(_ key: String) -> Color {
        if key == dateShortcutTitle {
            return NumiColor.controlFill
        }
        if ["+", "-", "="].contains(key) {
            return NumiColor.controlFillStrong.opacity(0.72)
        }
        if key == "delete.left" {
            return NumiColor.controlFill
        }
        return NumiColor.controlFill
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
