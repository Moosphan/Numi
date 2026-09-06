import Foundation
import NumiCore

public struct CSVImportMappingTemplate: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let mapping: CSVImportMapping

    public init(id: UUID = UUID(), name: String, mapping: CSVImportMapping) {
        self.id = id
        self.name = name
        self.mapping = mapping
    }
}

public final class CSVImportMappingTemplateStore {
    public static let shared = CSVImportMappingTemplateStore()

    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "csv.import.mapping.templates"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public var templates: [CSVImportMappingTemplate] {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([CSVImportMappingTemplate].self, from: data) else {
            return []
        }
        return saved
    }

    public func save(_ template: CSVImportMappingTemplate) {
        var saved = templates.filter { $0.id != template.id }
        saved.append(template)
        persist(saved)
    }

    public func delete(id: UUID) {
        persist(templates.filter { $0.id != id })
    }

    private func persist(_ templates: [CSVImportMappingTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
