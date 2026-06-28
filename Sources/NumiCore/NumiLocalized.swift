import Foundation

/// 全局本地化辅助工具（NumiCore 版本）
/// 解决 `String(localized:)` 默认使用 `Bundle.main` 而不响应运行时语言切换的问题
public enum NumiLocalized {

    private static let bundle: Bundle = .module
    private static let lock = NSLock()
    private nonisolated(unsafe) static var registeredBundles: [Bundle] = []

    /// 根据用户存储的语言偏好返回正确的 Locale
    public static var currentLocale: Locale {
        let code = UserDefaults.standard.string(forKey: "app.language") ?? "system"
        if code == "system" {
            return .autoupdatingCurrent
        }
        return Locale(identifier: code)
    }

    /// 用正确的 locale 解析本地化字符串。
    public static func string(_ key: String) -> String {
        lookup(key, locale: currentLocale)
    }

    /// 用正确的 locale 解析并格式化带参数的本地化字符串。
    public static func string(_ key: String, _ arguments: Any...) -> String {
        format(key, arguments: arguments, locale: currentLocale)
    }

    public static func format(_ key: String, arguments: [Any], locale: Locale? = nil) -> String {
        let effectiveLocale = locale ?? currentLocale
        let template = lookup(key, locale: effectiveLocale)
        let normalizedTemplate = template
            .replacingOccurrences(of: "%lld", with: "%@")
            .replacingOccurrences(of: "%ld", with: "%@")
            .replacingOccurrences(of: "%d", with: "%@")
        let formattedArguments: [CVarArg] = arguments.map { String(describing: $0) }
        return String(format: normalizedTemplate, locale: effectiveLocale, arguments: formattedArguments)
    }

    public static func percent(_ value: Double, maximumFractionDigits: Int = 0, locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale ?? currentLocale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }

    /// 注册额外资源 bundle，让 AppUI、主 App 等模块也能复用同一套运行时语言 lookup。
    public static func register(bundle extraBundle: Bundle) {
        lock.lock()
        defer { lock.unlock() }

        guard !registeredBundles.contains(where: { $0.bundleURL == extraBundle.bundleURL }) else {
            return
        }

        registeredBundles.append(extraBundle)
    }

    /// 用正确的 locale 解析本地化字符串（支持普通 String key）
    public static func lookup(_ key: String, locale: Locale? = nil) -> String {
        let effectiveLocale = locale ?? currentLocale
        for searchBundle in searchBundles {
            if let localization = searchBundle.localizedString(forKey: key, locale: effectiveLocale) {
                return localization
            }
        }
        return key
    }

    private static var searchBundles: [Bundle] {
        lock.lock()
        defer { lock.unlock() }

        let bundles = registeredBundles + [.main, bundle]
        return bundles.reduce(into: []) { result, candidate in
            guard !result.contains(where: { $0.bundleURL == candidate.bundleURL }) else { return }
            result.append(candidate)
        }
    }
}

private extension Bundle {
    func localizedString(forKey key: String, locale: Locale) -> String? {
        for code in localizationCandidates(for: locale) {
            if let path = self.path(forResource: code, ofType: "lproj"),
               let localizedBundle = Bundle(path: path) {
                let value = localizedBundle.localizedString(forKey: key, value: nil, table: nil)
                if value != key {
                    return value
                }
            }
        }

        let fallback = self.localizedString(forKey: key, value: nil, table: nil)
        return fallback == key ? nil : fallback
    }

    private func localizationCandidates(for locale: Locale) -> [String] {
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let subtags = normalizedIdentifier.split(separator: "-").map(String.init)

        guard let rawLanguage = subtags.first, !rawLanguage.isEmpty else {
            return [normalizedIdentifier]
        }

        let language = rawLanguage.lowercased()
        var script: String?
        var region: String?

        for tag in subtags.dropFirst() {
            if script == nil, isScriptSubtag(tag) {
                script = tag.prefix(1).uppercased() + tag.dropFirst().lowercased()
                continue
            }

            if region == nil, isRegionSubtag(tag) {
                region = tag.uppercased()
            }
        }

        var candidates: [String] = []

        func append(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        append(normalizedIdentifier)

        if let script, let region {
            append([language, script, region].joined(separator: "-"))
        }
        if let script {
            append([language, script].joined(separator: "-"))
        }
        if let region {
            append([language, region].joined(separator: "-"))
        }
        if language == "zh" {
            for scriptFallback in inferredChineseScriptCandidates(region: region) {
                append(scriptFallback)
            }
        }
        append(language)

        return candidates
    }

    private func inferredChineseScriptCandidates(region: String?) -> [String] {
        switch region {
        case "CN", "SG":
            return ["zh-Hans"]
        case "TW", "HK", "MO":
            return ["zh-Hant"]
        default:
            return ["zh-Hans", "zh-Hant"]
        }
    }

    private func isScriptSubtag(_ tag: String) -> Bool {
        tag.count == 4 && tag.unicodeScalars.allSatisfy(CharacterSet.letters.contains)
    }

    private func isRegionSubtag(_ tag: String) -> Bool {
        (tag.count == 2 && tag.unicodeScalars.allSatisfy(CharacterSet.letters.contains))
            || (tag.count == 3 && tag.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains))
    }
}
