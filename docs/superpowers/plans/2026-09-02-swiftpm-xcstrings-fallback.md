# SwiftPM XCStrings Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make runtime localization resolve Core and AppUI string-catalog values in SwiftPM tests without changing the iOS app's compiled `.strings` behavior.

**Architecture:** `NumiLocalized.lookup` continues to search localized `.lproj` bundles first. Only when a bundle has no compiled localization value does it read that bundle's raw `Localizable.xcstrings` catalog, cache the decoded catalog by bundle URL, and select a value using the existing locale-candidate ordering. Xcode-built iOS bundles do not carry the raw catalog, so their current path remains unchanged.

**Tech Stack:** Swift 5.10, Foundation `Bundle`, `JSONDecoder`, XCTest, Swift Package Manager, Xcode string catalogs.

## Global Constraints

- iOS deployment target remains 17.0; Domain code must not depend on SwiftData.
- User-visible strings remain in target-specific `Localizable.xcstrings` files; do not duplicate `.strings` files.
- Do not change the `NumiLocalized.register(bundle:)` public interface or the registered-bundle precedence.
- Preserve existing locale fallback order and custom-name behavior.
- Do not commit until the user has reviewed the verified change.

## Implementation adjustments discovered during verification

- Move Core-owned export and exchange-rate error keys into the Core catalog, then remove the obsolete App-target copy.
- Keep package tests within the Core/AppUI catalogs they actually load; use unique temporary test keys so static bundle registration cannot make tests order-dependent.
- Resolve language display names in the current UI language, and localize `TransactionServiceError` through its existing Core keys.
- Accept date-only (`yyyy-MM-dd`) values from LLM responses in addition to full ISO 8601 timestamps.

---

### Task 1: Reproduce SwiftPM raw-catalog fallback behavior

**Files:**
- Modify: `Tests/NumiCoreTests/RuntimeLocalizationTests.swift`

**Interfaces:**
- Consumes: `NumiLocalized.lookup(_:locale:)`.
- Produces: a regression test that requires `Bundle.module`'s raw `Localizable.xcstrings` to resolve `currency.name.USD` when SwiftPM does not generate `.lproj` resources.

- [x] **Step 1: Write the failing test**

```swift
func testLookupReadsCoreStringCatalogFromSwiftPMResourceBundle() {
    XCTAssertEqual(
        NumiLocalized.lookup("currency.name.USD", locale: Locale(identifier: "en")),
        "US Dollar"
    )
}
```

- [x] **Step 2: Run the focused test and verify it fails because the current lookup returns the key**

Run: `swift test --filter RuntimeLocalizationTests.testLookupReadsCoreStringCatalogFromSwiftPMResourceBundle`

Expected: `XCTAssertEqual failed: ("currency.name.USD") is not equal to ("US Dollar")`.

### Task 2: Add a cached raw-XCStrings fallback after compiled-resource lookup

**Files:**
- Modify: `Sources/NumiCore/NumiLocalized.swift:5-99`
- Test: `Tests/NumiCoreTests/RuntimeLocalizationTests.swift`

**Interfaces:**
- Consumes: `Bundle.url(forResource:withExtension:)`, `JSONDecoder`, existing `Bundle.localizationCandidates(for:)`.
- Produces: `NumiLocalized.lookup(_:locale:)` that resolves the following sources in order: compiled `.lproj` value, raw `Localizable.xcstrings` value, next registered bundle, raw key.

- [x] **Step 1: Define private catalog decoding types in `NumiLocalized.swift`**

```swift
private struct XCStringsCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: XCStringsEntry]
}

private struct XCStringsEntry: Decodable {
    let localizations: [String: XCStringsLocalization]
}

private struct XCStringsLocalization: Decodable {
    let stringUnit: XCStringsUnit?
}

private struct XCStringsUnit: Decodable {
    let value: String?
}
```

- [x] **Step 2: Add lock-protected caches to `NumiLocalized`**

```swift
private nonisolated(unsafe) static var decodedCatalogs: [URL: XCStringsCatalog] = [:]
private nonisolated(unsafe) static var bundlesWithoutCatalog: Set<URL> = []
```

- [x] **Step 3: Add a private helper that loads and caches `Localizable.xcstrings` from a bundle**

```swift
private static func catalogValue(forKey key: String, locale: Locale, bundle: Bundle) -> String? {
    let bundleURL = bundle.bundleURL
    lock.lock()
    if let catalog = decodedCatalogs[bundleURL] {
        lock.unlock()
        return catalogValue(forKey: key, locale: locale, bundle: bundle, catalog: catalog)
    }
    if bundlesWithoutCatalog.contains(bundleURL) {
        lock.unlock()
        return nil
    }
    lock.unlock()

    guard let catalogURL = bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
          let data = try? Data(contentsOf: catalogURL),
          let catalog = try? JSONDecoder().decode(XCStringsCatalog.self, from: data)
    else {
        lock.lock()
        bundlesWithoutCatalog.insert(bundleURL)
        lock.unlock()
        return nil
    }

    lock.lock()
    decodedCatalogs[bundleURL] = catalog
    lock.unlock()
    return catalogValue(forKey: key, locale: locale, bundle: bundle, catalog: catalog)
}
```

- [x] **Step 4: Select a catalog translation using existing locale candidates and catalog source language**

```swift
private static func catalogValue(forKey key: String, locale: Locale, bundle: Bundle, catalog: XCStringsCatalog) -> String? {
    guard let entry = catalog.strings[key] else { return nil }
    for code in bundle.localizationCandidates(for: locale) + [catalog.sourceLanguage] {
        if let value = entry.localizations[code]?.stringUnit?.value, !value.isEmpty {
            return value
        }
    }
    return nil
}
```

- [x] **Step 5: Use the raw-catalog helper only after each bundle's compiled-resource lookup fails**

```swift
for searchBundle in searchBundles {
    if let localization = searchBundle.localizedString(forKey: key, locale: effectiveLocale) {
        return localization
    }
    if let localization = catalogValue(forKey: key, locale: effectiveLocale, bundle: searchBundle) {
        return localization
    }
}
```

- [x] **Step 6: Run the focused regression test and verify it passes**

Run: `swift test --filter RuntimeLocalizationTests.testLookupReadsCoreStringCatalogFromSwiftPMResourceBundle`

Expected: `Executed 1 test, with 0 failures`.

### Task 3: Verify regression coverage and iOS resource compatibility

**Files:**
- Modify: `Tests/NumiCoreTests/RuntimeLocalizationTests.swift`
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift` only if an existing test exposes a missing raw-catalog case.

**Interfaces:**
- Consumes: registered AppUI bundle via `NumiAppUILocalization.registerBundle()`.
- Produces: passing Core, Persistence, and AppUI package tests while retaining Xcode-generated `.lproj/Localizable.strings` resources.

- [x] **Step 1: Run the localization-focused suites**

Run: `swift test --filter RuntimeLocalizationTests && swift test --filter AppUILocalizationBundleTests && swift test --filter SwiftDataBookkeepingStoreTests && swift test --filter TransactionServiceTests`

Expected: each command exits `0`; no raw localization keys, missing default-data IDs, or balance-linkage failures remain.

- [x] **Step 2: Run the package test suite**

Run: `swift test`

Expected: exit `0`; only integration tests without configured API keys may be skipped.

- [x] **Step 3: Verify the iOS build keeps compiled resource bundles**

Run: `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath build/localization-verification build && find build/localization-verification/Build/Products -path '*/*.lproj/Localizable.strings' -print`

Expected: Xcode build exits `0` and outputs `Localizable.strings` inside both `Numi_NumiCore.bundle` and `Numi_NumiAppUI.bundle` localization directories.

- [x] **Step 4: Report verified diff and wait for the user's approval to commit**

Run: `git diff --check && git diff -- Sources/NumiCore/NumiLocalized.swift Tests/NumiCoreTests/RuntimeLocalizationTests.swift`

Expected: no whitespace errors; diff contains only the raw catalog fallback and its regression test.

- [ ] **Step 5: Commit only after user approval**

```bash
git add Sources/NumiCore/NumiLocalized.swift Tests/NumiCoreTests/RuntimeLocalizationTests.swift docs/superpowers/plans/2026-09-02-swiftpm-xcstrings-fallback.md
git commit -m "fix: load string catalogs in SwiftPM tests"
```

## Self-Review

- Coverage: the plan addresses the demonstrated SwiftPM resource-format mismatch, verifies Core/AppUI lookups and the dependent persistence suites, then confirms Xcode still emits compiled `.strings` resources.
- Scope: no default-data, balance, or product behavior changes are included; language names and Core error messages now use the correct owner catalog and active locale.
- Type consistency: all helper and model types are private to `NumiLocalized`; no public API changes are required.
- Placeholder scan: no `TBD`, deferred implementation, or unspecified test behavior remains.
