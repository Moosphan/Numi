import XCTest
@testable import NumiAppUI
import NumiCore

final class CSVImportMappingTemplateStoreTests: XCTestCase {
    func testPersistsAndDeletesNamedTemplates() {
        let suiteName = "CSVImportMappingTemplateStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CSVImportMappingTemplateStore(defaults: defaults)
        let template = CSVImportMappingTemplate(
            name: "My Bank",
            mapping: CSVImportMapping(headers: ["transaction_total"])
        )

        store.save(template)

        XCTAssertEqual(store.templates, [template])
        store.delete(id: template.id)
        XCTAssertTrue(store.templates.isEmpty)
    }
}
