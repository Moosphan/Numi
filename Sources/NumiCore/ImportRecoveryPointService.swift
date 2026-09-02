import Foundation

public enum ImportRecoveryPointError: Error, Equatable {
    case save
    case load
    case discard

    public var displayMessage: String {
        switch self {
        case .save:
            return NumiLocalized.string("error.import.recovery.save")
        case .load:
            return NumiLocalized.string("error.import.recovery.load")
        case .discard:
            return NumiLocalized.string("error.import.recovery.discard")
        }
    }
}

public final class ImportRecoveryPointService: Sendable {
    public static let shared = ImportRecoveryPointService(directory: defaultDirectory)

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("import-recovery-point.json")
    }

    public var hasRecoveryPoint: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func save(_ snapshot: BookkeepingSnapshot) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            throw ImportRecoveryPointError.save
        }
    }

    public func load() throws -> BookkeepingSnapshot {
        do {
            return try JSONDecoder().decode(BookkeepingSnapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            throw ImportRecoveryPointError.load
        }
    }

    public func discard() throws {
        guard hasRecoveryPoint else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw ImportRecoveryPointError.discard
        }
    }

    private static let defaultDirectory: URL = {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return applicationSupport.appendingPathComponent("Numi", isDirectory: true)
    }()
}
