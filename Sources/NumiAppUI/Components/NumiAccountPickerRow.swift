import SwiftUI
import NumiCore

public struct NumiAccountPickerRow: View {
    private let title: String?
    private let accounts: [Account]
    @Binding private var selectedAccountID: UUID?
    private let excludedAccountID: UUID?
    private let accessibilityIdentifier: String

    public init(
        title: String? = nil,
        accounts: [Account],
        selectedAccountID: Binding<UUID?>,
        excludedAccountID: UUID? = nil,
        accessibilityIdentifier: String
    ) {
        self.title = title
        self.accounts = accounts
        self._selectedAccountID = selectedAccountID
        self.excludedAccountID = excludedAccountID
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Menu {
            ForEach(visibleAccounts) { account in
                Button {
                    selectedAccountID = account.id
                } label: {
                    Label(account.localizedDisplayName, systemImage: iconName(for: account.type))
                }
                .accessibilityIdentifier("account.\(account.id.uuidString)")
            }
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: iconName(for: selectedAccount?.type ?? .other))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                    .frame(width: 24)
                Text(title ?? NumiLocalized.string("record.account"))
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                Text(selectedAccount?.localizedDisplayName ?? NumiLocalized.string( "empty.no.selection"))
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 44)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .onAppear(perform: ensureSelectedAccount)
        .onChange(of: accounts.map(\.id)) {
            ensureSelectedAccount()
        }
        .onChange(of: excludedAccountID) {
            ensureSelectedAccount()
        }
    }

    private var visibleAccounts: [Account] {
        accounts.filter { !$0.isHidden && $0.id != excludedAccountID }
    }

    private var selectedAccount: Account? {
        visibleAccounts.first { $0.id == selectedAccountID } ?? visibleAccounts.first
    }

    private func ensureSelectedAccount() {
        if selectedAccount == nil {
            selectedAccountID = visibleAccounts.first?.id
        }
    }

    private func iconName(for type: AccountType) -> String {
        switch type {
        case .cash: "banknote"
        case .debitCard: "creditcard"
        case .creditCard: "creditcard.trianglebadge.exclamationmark"
        case .wechat: "message"
        case .alipay: "qrcode"
        case .virtual: "wallet.pass"
        case .liability: "minus.circle"
        case .other: "ellipsis.circle"
        }
    }
}
