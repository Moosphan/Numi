import Foundation

enum Config {
    /// Claude API Key，从 App Group UserDefaults 读取
    static var llmAPIKey: String {
        let defaults = UserDefaults(suiteName: "group.com.numi.shared")
        return defaults?.string(forKey: "app.ai.claudeAPIKey") ?? ""
    }

    static func setAPIKey(_ key: String) {
        let defaults = UserDefaults(suiteName: "group.com.numi.shared")
        defaults?.set(key, forKey: "app.ai.claudeAPIKey")
    }
}
