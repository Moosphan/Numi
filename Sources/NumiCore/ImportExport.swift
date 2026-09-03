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

    public init(lineNumber: Int, message: String) {
        self.lineNumber = lineNumber
        self.message = message
    }
}

public struct CSVImportResult: Equatable, Sendable {
    public let transactions: [Transaction]
    public let errors: [CSVImportError]

    public init(transactions: [Transaction], errors: [CSVImportError]) {
        self.transactions = transactions
        self.errors = errors
    }
}

public enum CSVImportField: String, CaseIterable, Identifiable, Sendable {
    case ignored
    case type
    case amount
    case currency
    case date
    case category
    case account
    case note

    public var id: String { rawValue }
}

public struct CSVImportMapping: Equatable, Sendable {
    private var assignments: [String: CSVImportField]

    public init(headers: [String]) {
        assignments = Dictionary(uniqueKeysWithValues: headers.map { header in
            (header, Self.defaultField(for: header))
        })
    }

    public func field(for header: String) -> CSVImportField {
        assignments[header] ?? .ignored
    }

    public mutating func assign(_ field: CSVImportField, to header: String) {
        guard assignments[header] != nil else { return }
        if field != .ignored {
            for assignedHeader in assignments.keys where assignments[assignedHeader] == field {
                assignments[assignedHeader] = .ignored
            }
        }
        assignments[header] = field
    }

    private static func defaultField(for header: String) -> CSVImportField {
        switch header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "type", "kind", "类型": return .type
        case "amount", "total", "金额": return .amount
        case "currency", "币种": return .currency
        case "occurredat", "date", "day", "日期": return .date
        case "category", "category_name", "分类": return .category
        case "account", "wallet", "账户": return .account
        case "note", "memo", "备注": return .note
        default: return .ignored
        }
    }
}

public struct CSVImportRow: Equatable, Sendable {
    public let lineNumber: Int
    public let values: [String]

    public init(lineNumber: Int, values: [String]) {
        self.lineNumber = lineNumber
        self.values = values
    }
}

public enum CSVImportDocumentError: Error, Equatable {
    case missingHeader
    case duplicateHeader
    case unterminatedQuotedField
}

public struct CSVImportDocument: Equatable, Sendable {
    public let headers: [String]
    public let rows: [CSVImportRow]

    public init(csv: String) throws {
        let records = try Self.parseRecords(csv)
        guard let header = records.first?.values, !header.isEmpty else {
            throw CSVImportDocumentError.missingHeader
        }
        guard Set(header).count == header.count else {
            throw CSVImportDocumentError.duplicateHeader
        }
        headers = header
        rows = records.dropFirst().map { CSVImportRow(lineNumber: $0.lineNumber, values: $0.values) }
    }

    private static func parseRecords(_ csv: String) throws -> [(lineNumber: Int, values: [String])] {
        var records: [(lineNumber: Int, values: [String])] = []
        var fields: [String] = []
        var field = ""
        var recordLine = 1
        var currentLine = 1
        var isQuoted = false
        var hasRecordContent = false
        var index = csv.startIndex

        func appendRecord() {
            fields.append(field)
            if hasRecordContent || fields.contains(where: { !$0.isEmpty }) {
                records.append((recordLine, fields))
            }
            fields = []
            field = ""
            hasRecordContent = false
        }

        while index < csv.endIndex {
            let character = csv[index]
            if character == "\"" {
                let nextIndex = csv.index(after: index)
                if isQuoted, nextIndex < csv.endIndex, csv[nextIndex] == "\"" {
                    field.append("\"")
                    index = csv.index(after: nextIndex)
                    continue
                }
                if isQuoted || field.isEmpty {
                    isQuoted.toggle()
                } else {
                    field.append(character)
                }
                hasRecordContent = true
            } else if character == "," && !isQuoted {
                fields.append(field)
                field = ""
                hasRecordContent = true
            } else if character == "\n" && !isQuoted {
                appendRecord()
                currentLine += 1
                recordLine = currentLine
            } else if character != "\r" || isQuoted {
                field.append(character)
                hasRecordContent = true
                if character == "\n" {
                    currentLine += 1
                }
            }
            index = csv.index(after: index)
        }

        guard !isQuoted else { throw CSVImportDocumentError.unterminatedQuotedField }
        if hasRecordContent || !field.isEmpty || !fields.isEmpty {
            appendRecord()
        }
        return records
    }
}

public struct CSVImportContext: Sendable {
    public let ledger: Ledger
    public let categories: [Category]
    public let accounts: [Account]

    public init(ledger: Ledger, categories: [Category], accounts: [Account]) {
        self.ledger = ledger
        self.categories = categories
        self.accounts = accounts
    }
}

public enum NumiCSVImporter {
    public static func importTransactions(csv: String) -> CSVImportResult {
        do {
            let document = try CSVImportDocument(csv: csv)
            return preview(
                document: document,
                mapping: CSVImportMapping(headers: document.headers),
                context: CSVImportContext(ledger: Ledger(name: "CSV Import", currencyCode: "CNY"), categories: [], accounts: [])
            )
        } catch {
            return CSVImportResult(
                transactions: [],
                errors: [CSVImportError(lineNumber: 1, message: "\(error)")]
            )
        }
    }

    public static func preview(
        document: CSVImportDocument,
        mapping: CSVImportMapping,
        context: CSVImportContext
    ) -> CSVImportResult {
        var transactions: [Transaction] = []
        var errors: [CSVImportError] = []

        for row in document.rows {
            do {
                guard row.values.count == document.headers.count else {
                    throw ImportFailure("Column count does not match header")
                }
                let values = Dictionary(uniqueKeysWithValues: zip(document.headers, row.values))
                let type = try transactionType(from: value(for: .type, in: values, mapping: mapping))
                let amount = try requiredValue(for: .amount, in: values, mapping: mapping)
                let currency = value(for: .currency, in: values, mapping: mapping) ?? context.ledger.currencyCode
                let money = try Money(decimalString: amount, currencyCode: currency)
                let categoryID = try resolvedCategoryID(
                    from: value(for: .category, in: values, mapping: mapping),
                    type: type,
                    categories: context.categories
                )
                let accountID = try resolvedAccountID(
                    from: value(for: .account, in: values, mapping: mapping),
                    accounts: context.accounts
                )
                transactions.append(Transaction(
                    type: type,
                    amount: money,
                    occurredAt: try date(from: value(for: .date, in: values, mapping: mapping)),
                    categoryID: categoryID,
                    accountID: accountID,
                    ledgerID: context.ledger.id,
                    note: value(for: .note, in: values, mapping: mapping) ?? ""
                ))
            } catch {
                errors.append(CSVImportError(lineNumber: row.lineNumber, message: "\(error)"))
            }
        }

        return CSVImportResult(transactions: transactions, errors: errors)
    }

    private static func value(
        for field: CSVImportField,
        in values: [String: String],
        mapping: CSVImportMapping
    ) -> String? {
        guard let header = values.keys.first(where: { mapping.field(for: $0) == field }) else { return nil }
        let value = values[header]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func requiredValue(
        for field: CSVImportField,
        in values: [String: String],
        mapping: CSVImportMapping
    ) throws -> String {
        guard let value = value(for: field, in: values, mapping: mapping) else {
            throw ImportFailure("Missing \(field.rawValue)")
        }
        return value
    }

    private static func transactionType(from value: String?) throws -> TransactionType {
        switch value?.lowercased() {
        case "expense", "支出": return .expense
        case "income", "收入": return .income
        case "transfer", "转账": throw ImportFailure("Transfers are not supported")
        default: throw ImportFailure("Invalid type")
        }
    }

    private static func date(from value: String?) throws -> Date {
        guard let value else { return Date() }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { throw ImportFailure("Invalid date") }
        return date
    }

    private static func resolvedCategoryID(
        from value: String?,
        type: TransactionType,
        categories: [Category]
    ) throws -> UUID? {
        guard let value else { return nil }
        let category = categories.first { $0.id.uuidString.caseInsensitiveCompare(value) == .orderedSame }
            ?? categories.first { $0.name.caseInsensitiveCompare(value) == .orderedSame && (($0.kind == .expense) == (type == .expense)) }
        guard let category else { throw ImportFailure("Unknown category \(value)") }
        return category.id
    }

    private static func resolvedAccountID(from value: String?, accounts: [Account]) throws -> UUID? {
        guard let value else { return nil }
        let account = accounts.first { $0.id.uuidString.caseInsensitiveCompare(value) == .orderedSame }
            ?? accounts.first { $0.name.caseInsensitiveCompare(value) == .orderedSame }
        guard let account else { throw ImportFailure("Unknown account \(value)") }
        return account.id
    }

    private struct ImportFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }
}
