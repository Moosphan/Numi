# P1-06 运行时本地化测试实施计划

**Goal:** Keep runtime localization regressions visible across all four supported languages.

**Architecture:** Extend the existing Core and AppUI localization test suites with deterministic locale matrices. Tests use the runtime lookup API and resource bundles directly, so they remain independent of simulator UI timing.

**Constraints:** Work in the current checkout, avoid unrelated refactors, keep `zh-Hans`, `zh-Hant`, `en`, and `ja` covered, and do not commit before user confirmation.

### Task 1: Four-language regression matrix

- [x] Add Core and AppUI assertions for all supported runtime languages.
- [x] Run focused localization tests and verify all pass.
- [x] Update backlog evidence and verify whitespace/build health.
- [ ] Ask for confirmation before committing or pushing.
