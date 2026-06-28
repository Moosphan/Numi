import SwiftUI
import NumiCore

public struct NumiCurrencyOption: Identifiable, Equatable {
    public let code: String
    public let title: String
    public let symbol: String

    public var id: String { code }

    public init(code: String, title: String, symbol: String) {
        self.code = code.uppercased()
        self.title = title
        self.symbol = symbol
    }
}

public struct NumiCurrencyPickerRow: View {
    private let title: String?
    private let options: [NumiCurrencyOption]
    @Binding private var selectedCode: String
    private let accessibilityIdentifier: String

    public init(
        title: String? = nil,
        options: [NumiCurrencyOption],
        selectedCode: Binding<String>,
        accessibilityIdentifier: String
    ) {
        self.title = title
        self.options = options
        self._selectedCode = selectedCode
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selectedCode = option.code
                } label: {
                    Label("\(option.code) · \(option.title)", systemImage: selectedCode == option.code ? "checkmark.circle.fill" : "circle")
                }
                .accessibilityIdentifier("currency.\(option.code)")
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                    .frame(width: 24)
                Text(title ?? NumiLocalized.string("ledger.currency"))
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(selectedOption?.code ?? selectedCode)
                        .font(NumiFont.bodyStrong)
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(selectedOption?.title ?? selectedCode)
                        .font(NumiFont.caption)
                        .foregroundStyle(NumiColor.textTertiary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 52)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var selectedOption: NumiCurrencyOption? {
        options.first { $0.code == selectedCode.uppercased() }
    }
}
