import Foundation

public struct LocalizedTransferAccountResolution {
    public let source: Account
    public let target: Account

    public init(source: Account, target: Account) {
        self.source = source
        self.target = target
    }
}

public extension Category {
    var runtimeSearchNames: [String] {
        var seen = Set<String>()
        var names: [String] = []

        func append(_ value: String) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return }
            names.append(normalized)
        }

        append(name)
        append(localizedDisplayName)

        if let builtInKey {
            for code in NumiBuiltInCatalog.supportedLanguageCodes {
                append(NumiLocalized.lookup(builtInKey, locale: Locale(identifier: code)))
            }
        }

        return names
    }
}

public extension Collection where Element == Category {
    func localizedCategoryNames(includeHidden: Bool = false) -> [String] {
        var seen = Set<String>()

        return self
            .filter { includeHidden || !$0.isHidden }
            .compactMap { category in
                let name = category.localizedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return name
            }
    }

    func resolveLocalizedCategory(named candidateName: String, includeHidden: Bool = false) -> Category? {
        let normalizedCandidate = candidateName.normalizedCategoryMatchText
        guard !normalizedCandidate.isEmpty else { return nil }

        let categories = self.filter { includeHidden || !$0.isHidden }

        if let exact = categories.first(where: { category in
            category.runtimeSearchNames.contains { $0.normalizedCategoryMatchText == normalizedCandidate }
        }) {
            return exact
        }

        return categories.first(where: { category in
            category.runtimeSearchNames.contains { searchName in
                let normalizedSearchName = searchName.normalizedCategoryMatchText
                return normalizedSearchName.contains(normalizedCandidate)
                    || normalizedCandidate.contains(normalizedSearchName)
            }
        })
    }
}

public extension Account {
    var runtimeSearchNames: [String] {
        var seen = Set<String>()
        var names: [String] = []

        func append(_ value: String) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return }
            names.append(normalized)
        }

        append(name)
        append(localizedDisplayName)

        if let builtInKey {
            for code in NumiBuiltInCatalog.supportedLanguageCodes {
                append(NumiLocalized.lookup(builtInKey, locale: Locale(identifier: code)))
            }
        }

        return names
    }
}

public extension Collection where Element == Account {
    func localizedAccountNames(includeHidden: Bool = false) -> [String] {
        var seen = Set<String>()

        return self
            .filter { includeHidden || !$0.isHidden }
            .compactMap { account in
                let name = account.localizedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, seen.insert(name).inserted else { return nil }
                return name
            }
    }

    func resolveLocalizedAccount(named candidateName: String?, includeHidden: Bool = false) -> Account? {
        let normalizedCandidate = candidateName?.normalizedCategoryMatchText ?? ""
        guard !normalizedCandidate.isEmpty else { return nil }

        let accounts = self.filter { includeHidden || !$0.isHidden }

        if let exact = accounts.first(where: { account in
            account.runtimeSearchNames.contains { $0.normalizedCategoryMatchText == normalizedCandidate }
        }) {
            return exact
        }

        return accounts.first(where: { account in
            account.runtimeSearchNames.contains { searchName in
                let normalizedSearchName = searchName.normalizedCategoryMatchText
                return normalizedSearchName.contains(normalizedCandidate)
                    || normalizedCandidate.contains(normalizedSearchName)
            }
        })
    }

    func resolveLocalizedTransferAccounts(
        parsedAccountName: String?,
        parsedTargetAccountName: String?,
        includeHidden: Bool = false
    ) -> LocalizedTransferAccountResolution? {
        let accounts = self.filter { includeHidden || !$0.isHidden }
        let parsedAccount = accounts.resolveLocalizedAccount(named: parsedAccountName, includeHidden: true)
        let parsedTargetAccount = accounts.resolveLocalizedAccount(named: parsedTargetAccountName, includeHidden: true)
        let targetAccount = parsedTargetAccount ?? parsedAccount

        guard let targetAccount else { return nil }

        let sourceAccount: Account?
        if parsedTargetAccount != nil,
           let parsedAccount,
           parsedAccount.id != targetAccount.id {
            sourceAccount = parsedAccount
        } else {
            sourceAccount = accounts.first { $0.id != targetAccount.id }
        }

        guard let sourceAccount else { return nil }
        return LocalizedTransferAccountResolution(source: sourceAccount, target: targetAccount)
    }
}

private extension String {
    var normalizedCategoryMatchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
