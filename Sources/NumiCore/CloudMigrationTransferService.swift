import Foundation

public enum CloudMigrationTransferError: Error, Equatable, Sendable {
    case stage
    case load
    case discard
    case complete
}

/// Holds a local source snapshot across the one-time transition to a
/// CloudKit-backed store. It is intentionally independent of the normal import
/// recovery point so a user can retain both recovery paths.
public final class CloudMigrationTransferService: Sendable {
    public static let shared = CloudMigrationTransferService(directory: defaultDirectory)

    private let fileURL: URL
    private let cloudRecoveryURL: URL
    private let completionURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("icloud-migration-source.json")
        cloudRecoveryURL = directory.appendingPathComponent("icloud-migration-cloud-recovery.json")
        completionURL = directory.appendingPathComponent("icloud-migration-completed")
    }

    public var hasStagedSnapshot: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// A completed migration keeps both JSON snapshots for recovery, but is no
    /// longer offered as an active migration on subsequent launches.
    public var isMigrationPending: Bool {
        hasStagedSnapshot && !FileManager.default.fileExists(atPath: completionURL.path)
    }

    public func stage(_ snapshot: BookkeepingSnapshot) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
            if FileManager.default.fileExists(atPath: completionURL.path) {
                try FileManager.default.removeItem(at: completionURL)
            }
        } catch {
            throw CloudMigrationTransferError.stage
        }
    }

    public func load() throws -> BookkeepingSnapshot {
        try loadSnapshot(at: fileURL)
    }

    public func stageCloudRecovery(_ snapshot: BookkeepingSnapshot) throws {
        do {
            try JSONEncoder().encode(snapshot).write(to: cloudRecoveryURL, options: .atomic)
        } catch {
            throw CloudMigrationTransferError.stage
        }
    }

    public func loadCloudRecovery() throws -> BookkeepingSnapshot {
        try loadSnapshot(at: cloudRecoveryURL)
    }

    public func discard() throws {
        guard hasStagedSnapshot else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw CloudMigrationTransferError.discard
        }
    }

    /// Marks a confirmed decision as complete without deleting either recovery
    /// copy. A future migration starts by staging a new source snapshot.
    public func markCompleted() throws {
        do {
            try FileManager.default.createDirectory(
                at: completionURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: completionURL, options: .atomic)
        } catch {
            throw CloudMigrationTransferError.complete
        }
    }

    private func loadSnapshot(at url: URL) throws -> BookkeepingSnapshot {
        do {
            return try JSONDecoder().decode(BookkeepingSnapshot.self, from: Data(contentsOf: url))
        } catch {
            throw CloudMigrationTransferError.load
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
