import NumiCore

public enum BatchTransactionSelectionPolicy {
    public static func canAdd(_ candidate: Transaction, to selection: [Transaction]) -> Bool {
        guard candidate.type != .transfer else { return false }
        return selection.isEmpty || selection.allSatisfy { $0.type == candidate.type }
    }
}
