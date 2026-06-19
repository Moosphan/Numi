import Foundation

public enum NumiJSONExporter {
    public static func exportSnapshot(from snapshot: BookkeepingSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    public static func importSnapshot(from data: Data) throws -> BookkeepingSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BookkeepingSnapshot.self, from: data)
    }
}

public enum NumiCSVExporter {
    public static func exportTransactions(_ transactions: [Transaction]) -> String {
        let header = "id,type,amount,currency,occurredAt,categoryID,accountID,targetAccountID,note"
        let rows = transactions.map { transaction in
            [
                transaction.id.uuidString,
                transaction.type.rawValue,
                decimalString(for: transaction.amount),
                transaction.amount.currencyCode,
                ISO8601DateFormatter().string(from: transaction.occurredAt),
                transaction.categoryID?.uuidString ?? "",
                transaction.accountID?.uuidString ?? "",
                transaction.targetAccountID?.uuidString ?? "",
                escape(transaction.note)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func decimalString(for money: Money) -> String {
        let scale = Decimal(Money.scale(for: money.currencyCode))
        let decimal = Decimal(money.minorUnits) / scale
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}

public struct CSVImportError: Equatable, Sendable {
    public let lineNumber: Int
    public let message: String
}

public struct CSVImportResult: Equatable, Sendable {
    public let transactions: [Transaction]
    public let errors: [CSVImportError]
}

public enum NumiCSVImporter {
    public static func importTransactions(csv: String) -> CSVImportResult {
        let lines = csv
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard let header = lines.first else {
            return CSVImportResult(transactions: [], errors: [CSVImportError(lineNumber: 1, message: "Missing header")])
        }

        let columns = header.split(separator: ",").map(String.init)
        var transactions: [Transaction] = []
        var errors: [CSVImportError] = []

        for (offset, line) in lines.dropFirst().enumerated() {
            let lineNumber = offset + 2
            let values = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let row = Dictionary(uniqueKeysWithValues: zip(columns, values))
            do {
                guard let typeRaw = row["type"], let type = TransactionType(rawValue: typeRaw) else {
                    throw ImportFailure("Invalid type")
                }
                guard let amountRaw = row["amount"], let currency = row["currency"] else {
                    throw ImportFailure("Missing amount or currency")
                }
                let money = try Money(decimalString: amountRaw, currencyCode: currency)
                transactions.append(Transaction(
                    type: type,
                    amount: money,
                    categoryID: nil,
                    accountID: nil,
                    note: row["note"] ?? ""
                ))
            } catch {
                errors.append(CSVImportError(lineNumber: lineNumber, message: "\(error)"))
            }
        }

        return CSVImportResult(transactions: transactions, errors: errors)
    }

    private struct ImportFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }
}
