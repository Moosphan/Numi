# Runtime Localization Single Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure every visible localized key in AppUI and the app shell resolves through `NumiLocalized` after an in-app language change.

**Architecture:** Replace direct SwiftUI localized-key literals only when the literal is a dotted Numi localization key. Retain literal product names and diagnostic strings. A source-level unit test rejects direct dotted keys in visible SwiftUI API entry points, while runtime lookup tests verify the record-detail regression across all supported languages.

**Tech Stack:** Swift 5.10, SwiftUI, XCTest, NumiCore `NumiLocalized`, String Catalog localization.

## Global Constraints

- Work directly on `main`; do not create a worktree.
- Preserve all existing keys, translations, accessibility identifiers, layout, and user-facing behavior other than fixing runtime language resolution.
- All visible localized keys must resolve from `NumiLocalized`; do not add or alter translations.
- Scan `Sources/NumiAppUI` and `App/NumiApp`; ignore non-localization prose and product-name literals.
- Verify focused regression tests, full `swift test`, catalog validation, `git diff --check`, and a Debug simulator build before requesting commit confirmation.

---

### Task 1: Define the regression boundary

**Files:**
- Modify: `Tests/NumiAppUITests/AppUILocalizationBundleTests.swift`

**Interfaces:**
- Produces a source-lint test for direct dotted localization literals in SwiftUI entry points.
- Produces a four-language regression assertion for `record.detail`, `common.close`, and `common.edit`.

- [x] **Step 1: Write failing source-lint and record-detail tests**

```swift
XCTAssertEqual(NumiLocalized.lookup("record.detail", locale: locale), expected.title)
XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
```

The scanner rejects direct dotted literals in `Text`, `Button`, `Label`, `Toggle`, `Picker`, `Section`, `Menu`, `alert`, `confirmationDialog`, `navigationTitle`, `accessibilityLabel`, and `accessibilityHint`.

- [x] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter AppUILocalizationBundleTests/testRuntimeLocalizedSwiftUIKeysDoNotUseDirectLiterals`

Expected: failure listing `RecordDetailView.swift` and other source locations that render direct keys.

### Task 2: Migrate visible key literals to the runtime resolver

**Files:**
- Modify: affected `*.swift` files in `Sources/NumiAppUI/` and `App/NumiApp/`

**Interfaces:**
- Consumes `NumiLocalized.string(_:)`.
- Produces dynamically resolved `String` values for all visible SwiftUI titles and labels.

- [x] **Step 1: Replace direct localized-key literals mechanically and review exceptions**

Use `Text(NumiLocalized.string("key"))`, `Button(NumiLocalized.string("key"))`, `Label(NumiLocalized.string("key"), systemImage:)`, and matching dynamic titles for all flagged dotted keys. Keep strings without a dotted key unchanged.

- [x] **Step 2: Run focused source-lint and language tests and verify GREEN**

Run: `swift test --filter 'AppUILocalizationBundleTests/test(RuntimeLocalizedSwiftUIKeysDoNotUseDirectLiterals|RecordDetailRuntimeCopyCoversAllSupportedRuntimeLanguages)'`

Expected: no direct-key violations and all four language values resolve.

### Task 3: Verify and document the regression prevention

**Files:**
- Modify: `docs/backlog/current-priority-backlog.md`

- [x] **Step 1: Record the runtime-localization single-path guard**

Update P1-06 evidence to state that visible SwiftUI dotted keys are source-linted and record-detail runtime copy is covered across all four languages.

- [x] **Step 2: Run full verification**

Run: `ruby -rjson -e 'JSON.parse(File.read("Sources/NumiAppUI/Localizable.xcstrings")); puts "xcstrings JSON valid"'`, `swift test`, `xcodebuild -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataRuntimeLocalization CODE_SIGNING_ALLOWED=NO build`, and `git diff --check`.

- [ ] **Step 3: Request user confirmation before commit**

Report the fixed cause, the prevention check, verification evidence, and remaining external release checks. Do not commit or push until confirmation.
