# Pro CSV Mapping Templates Implementation Plan

**Goal:** Let Pro members save a CSV column mapping by name and reuse it in later imports, while preserving all users' ability to load or delete templates already stored on their device.

**Architecture:** Make `CSVImportMapping` codable and able to apply only matching header assignments to a new CSV document. Persist small named templates with a focused `UserDefaults` store in App UI. The CSV review sheet owns template selection/save/delete UI and gates only template creation through `.openAdvancedImportExport`.

**Constraints:**

- Basic CSV import, mapping, preview, errors, recovery point, export, and import remain free.
- Existing templates must never be made unreadable or undeletable after a downgrade.
- A template must only override headers present in the current file; unmatched old headers are ignored.
- Add new text for `zh-Hans`, `zh-Hant`, `en`, and `ja`.
- Do not add this workflow to the V1 commercial benefits catalogue until the advanced import/export release criteria are met.

## Tasks

1. Add failing core tests for serializing/reapplying matching mappings without changing unmatched new headers.
2. Add `CSVImportMappingTemplate` and `CSVImportMappingTemplateStore`, with a deterministic injected `UserDefaults` test.
3. Add a compact template menu to `CSVImportReviewSheet`: load, save (Pro-gated), and delete.
4. Add four-language labels and update feature-gate/product/backlog evidence without changing V1 sales claims.
5. Run focused tests, `swift test`, String Catalog JSON, `git diff --check`, and an iOS Simulator Debug build; request confirmation before commit.
