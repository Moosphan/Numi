import Foundation
import NumiCore

public enum CSVImportTargetLedger {
    public static func resolve(currentLedgerID: UUID?, from ledgers: [Ledger]) -> Ledger? {
        guard let currentLedgerID else { return ledgers.first }
        return ledgers.first(where: { $0.id == currentLedgerID }) ?? ledgers.first
    }
}
