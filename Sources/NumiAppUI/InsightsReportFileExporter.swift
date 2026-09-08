import Foundation

public enum InsightsReportFileExporter {
    public static func write(
        csv: String,
        date: Date = Date(),
        directory: URL? = nil
    ) throws -> URL {
        let exportDirectory = directory ?? defaultExportDirectory()
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let url = exportDirectory.appendingPathComponent("Numi_Insights_\(fileNameTimestamp(date)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func defaultExportDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("NumiExports", isDirectory: true)
    }

    private static func fileNameTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}
