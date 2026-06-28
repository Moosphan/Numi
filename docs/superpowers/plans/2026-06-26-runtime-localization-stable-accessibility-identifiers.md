# Runtime Localization Stable Accessibility Identifiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace production accessibility identifiers that interpolate localized strings with stable identifiers so runtime language switching does not alter UI automation locators.

**Architecture:** Keep visible labels localized, but derive accessibility identifiers from stable values only: `UUID` for categories/accounts/transactions, fixed enum keys for sections, and explicit fallback identifiers for reusable components. Add a static localization guard so risky interpolation patterns fail in CI before they reach the app.

**Tech Stack:** SwiftUI, XCTest UI tests, Python 3, pytest

## Global Constraints

- Keep edits scoped to runtime localization and UI automation stability.
- Do not change user-visible copy as part of this slice.
- Preserve existing UI test helpers that fall back to label-based queries.
- Add a failing automated test before expanding the localization guard.
- Validation in this environment is limited to repo scripts and pytest; Simulator execution remains blocked by sandbox.

---

### Task 1: Add Static Guard Coverage For Localized Accessibility Identifiers

**Files:**
- Modify: `scripts/tests/test_check_localization.py`
- Modify: `scripts/check_localization.py`

**Interfaces:**
- Consumes: `find_runtime_localization_risks(source_roots: list[Path]) -> list[str]`
- Produces: runtime-risk scan errors for localized accessibility identifier interpolation

- [ ] **Step 1: Write the failing test**

```python
def test_runtime_risk_scan_flags_localized_accessibility_identifier_interpolation(tmp_path: Path):
    module = load_check_localization_module()

    source = tmp_path / "Sources" / "NumiAppUI" / "Pages" / "AddRecordView.swift"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(
        "import SwiftUI\n"
        'Text(category.localizedDisplayName).accessibilityIdentifier("category.\\(category.localizedDisplayName)")\n'
        'Text(row.categoryName).accessibilityIdentifier("record.\\(row.categoryName)")\n'
    )

    risks = module.find_runtime_localization_risks([tmp_path / "Sources"])

    assert risks == [
        "Sources/NumiAppUI/Pages/AddRecordView.swift: localized accessibility identifier interpolation uses 'category.localizedDisplayName'",
        "Sources/NumiAppUI/Pages/AddRecordView.swift: localized accessibility identifier interpolation uses 'row.categoryName'",
    ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest scripts/tests/test_check_localization.py -q`
Expected: FAIL because `find_runtime_localization_risks(...)` does not yet report these patterns.

- [ ] **Step 3: Write minimal implementation**

```python
LOCALIZED_ACCESSIBILITY_IDENTIFIER_PATTERN = re.compile(
    r'accessibilityIdentifier\\(\\s*"[^"]*\\\\\\(([^)]+)\\)[^"]*"\\s*\\)'
)

LOCALIZED_IDENTIFIER_FRAGMENTS = (
    "localizedDisplayName",
    "categoryName",
    ".name",
    "title",
)
```

Extend `find_runtime_localization_risks(...)` so it inspects interpolated `accessibilityIdentifier(...)` string literals and emits a risk when the captured expression contains any fragment above.

- [ ] **Step 4: Run test to verify it passes**

Run: `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest scripts/tests/test_check_localization.py -q`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/check_localization.py scripts/tests/test_check_localization.py
git commit -m "test: guard localized accessibility identifiers"
```

### Task 2: Replace Localized Accessibility Identifiers In Production SwiftUI Code

**Files:**
- Modify: `Sources/NumiAppUI/Pages/AddRecordView.swift`
- Modify: `Sources/NumiAppUI/Pages/AddRecordFlowView.swift`
- Modify: `Sources/NumiAppUI/Pages/EditRecordView.swift`
- Modify: `Sources/NumiAppUI/Pages/AccountManagementView.swift`
- Modify: `Sources/NumiAppUI/Pages/CategoryManagementView.swift`
- Modify: `Sources/NumiAppUI/Pages/TransactionSearchView.swift`
- Modify: `Sources/NumiAppUI/Pages/InsightsView.swift`
- Modify: `Sources/NumiAppUI/Components/NumiRecordRow.swift`
- Modify: `Sources/NumiAppUI/Components/NumiAccountPickerRow.swift`
- Modify: `App/NumiUITests/NumiUITests.swift`

**Interfaces:**
- Consumes: category/account/transaction `UUID`, section `type` strings, existing UI test helper fallbacks
- Produces: stable identifiers such as `category.<uuid>`, `account.<uuid>`, `record.<uuid>`, `search.record.<uuid>`, `insights.category.<uuid>`

- [ ] **Step 1: Write the failing repo-level guard run**

Run: `python3 scripts/check_localization.py`
Expected: PASS before guard expansion, but repository still contains localized accessibility identifier patterns that the new test is about to make detectable.

- [ ] **Step 2: Implement stable identifiers**

```swift
.accessibilityIdentifier("category.\(category.id.uuidString)")
.accessibilityIdentifier("account.\(account.id.uuidString)")
.accessibilityIdentifier("record.\(transaction.id.uuidString)")
.accessibilityIdentifier("record.amount.\(transaction.id.uuidString)")
.accessibilityIdentifier("search.record.\(row.transaction.id.uuidString)")
.accessibilityIdentifier("toggle.category.\(category.id.uuidString)")
.accessibilityIdentifier("account.includedStatus.\(account.id.uuidString)")
.accessibilityIdentifier("insights.category.\(item.categoryID.uuidString)")
.accessibilityIdentifier("insights.categoryIcon.\(item.categoryID.uuidString)")
.accessibilityIdentifier("insights.distribution.\(type)")
```

Where reusable views need a stable identifier but do not currently accept one, add an optional identifier parameter and thread the stable value through the call sites.

- [ ] **Step 3: Update UI test helpers minimally**

```swift
private func categoryButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
}
```

Keep helper fallbacks label-based so existing Chinese tests remain runnable without knowing model UUIDs ahead of time.

- [ ] **Step 4: Run focused verification**

Run:

```bash
python3 scripts/check_localization.py
scripts/check_hardcoded_chinese.py
git diff --check
```

Expected: all pass, and no new runtime localization risks are reported.

- [ ] **Step 5: Commit**

```bash
git add Sources/NumiAppUI App/NumiUITests
git commit -m "fix: stabilize localization-sensitive accessibility ids"
```

### Task 3: Update Runtime Localization Docs And Backlog

**Files:**
- Modify: `docs/tech/runtime-localization-switching-solution.md`
- Modify: `docs/backlog/runtime-localization-switching-backlog.md`

**Interfaces:**
- Consumes: completed accessibility-id stabilization work and available validation evidence
- Produces: updated implementation status and remaining runtime verification gaps

- [ ] **Step 1: Write the documentation update**

Add a short subsection recording that production accessibility identifiers no longer derive from localized names and that the localization script now guards against this regression class.

- [ ] **Step 2: Run a quick self-check**

Run: `rg -n "accessibility" docs/tech/runtime-localization-switching-solution.md docs/backlog/runtime-localization-switching-backlog.md`
Expected: updated notes appear in both files.

- [ ] **Step 3: Commit**

```bash
git add docs/tech/runtime-localization-switching-solution.md docs/backlog/runtime-localization-switching-backlog.md
git commit -m "docs: record stable localization accessibility ids"
```
