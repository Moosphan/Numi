import Foundation
import CryptoKit

// MARK: - Backup Result

public enum BackupResult {
    case success(URL)
    case failure(BackupOperationFailure)
}

public enum RestoreResult {
    case success
    case failure(BackupOperationFailure)
}

public enum BackupOperationFailure: Equatable {
    case createBackup(String)
    case restoreBackup
    case export(String)

    public var displayMessage: String {
        switch self {
        case .createBackup(let description):
            return NumiLocalized.string("error.backup.fail", description)
        case .restoreBackup:
            return NumiLocalized.string("error.backup.restore.fail")
        case .export(let description):
            return NumiLocalized.string("error.export.fail", description)
        }
    }
}

// MARK: - Backup Service

public final class BackupService: Sendable {
    public static let shared = BackupService()

    private init() {}

    /// 创建加密备份文件
    public func createBackup(snapshot: BookkeepingSnapshot, password: String) -> BackupResult {
        do {
            let data = try JSONEncoder().encode(snapshot)
            let encrypted = try encrypt(data: data, password: password)

            let fileName = "Numi_Backup_\(Self.dateFormatter.string(from: Date())).numibackup"
            let url = Self.exportDirectory().appendingPathComponent(fileName)
            try encrypted.write(to: url, options: .atomic)

            return .success(url)
        } catch {
            return .failure(.createBackup(error.localizedDescription))
        }
    }

    /// 从加密备份恢复
    public func restoreBackup(from url: URL, password: String) -> RestoreResult {
        do {
            let encrypted = try Data(contentsOf: url)
            _ = try decrypt(data: encrypted, password: password)
            return .success
        } catch {
            return .failure(.restoreBackup)
        }
    }

    /// 导出 JSON 数据（未加密）
    public func exportJSON(snapshot: BookkeepingSnapshot) -> BackupResult {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)

            let fileName = "Numi_Export_\(Self.dateFormatter.string(from: Date())).json"
            let url = Self.exportDirectory().appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)

            return .success(url)
        } catch {
            return .failure(.export(error.localizedDescription))
        }
    }

    /// 导出 CSV
    public func exportCSV(snapshot: BookkeepingSnapshot) -> BackupResult {
        let header = "id,type,amount,currency,occurredAt,categoryID,accountID,note"
        let rows = snapshot.transactions.map { tx in
            [
                tx.id.uuidString,
                tx.type.rawValue,
                "\(tx.amount.minorUnits)",
                tx.amount.currencyCode,
                ISO8601DateFormatter().string(from: tx.occurredAt),
                tx.categoryID?.uuidString ?? "",
                tx.accountID?.uuidString ?? "",
                tx.note.replacingOccurrences(of: ",", with: "，")
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")

        do {
            let fileName = "Numi_Transactions_\(Self.dateFormatter.string(from: Date())).csv"
            let url = Self.exportDirectory().appendingPathComponent(fileName)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return .success(url)
        } catch {
            return .failure(.export(error.localizedDescription))
        }
    }

    /// 从 JSON 导入
    public func importJSON(from url: URL) throws -> BookkeepingSnapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BookkeepingSnapshot.self, from: data)
    }

    // MARK: - Encryption

    private func encrypt(data: Data, password: String) throws -> Data {
        let key = deriveKey(from: password)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw BackupError.encryptionFailed
        }
        return combined
    }

    private func decrypt(data: Data, password: String) throws -> Data {
        let key = deriveKey(from: password)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private func deriveKey(from password: String) -> SymmetricKey {
        let salt = "NumiBackupSalt_v1".data(using: .utf8)!
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: password.data(using: .utf8)!),
            salt: salt,
            info: "NumiBackup".data(using: .utf8)!,
            outputByteCount: 32
        )
        return derived
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static func exportDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exports = documents.appendingPathComponent("NumiExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        return exports
    }
}

// MARK: - Backup Error

public enum BackupError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed: return NumiLocalized.string( "error.encryption.fail")
        case .decryptionFailed: return NumiLocalized.string( "error.decryption.fail")
        }
    }
}
