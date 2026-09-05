# P1-04 iCloud 可用性实施计划

**Goal:** Use CloudKit account status as the source of truth before presenting iCloud sync as available.

**Architecture:** Keep the existing sync UI and SwiftData CloudKit container, but replace the ubiquity-file heuristic with a testable account-status evaluator. Unavailable, restricted, and no-account states continue through the existing localized failure path.

**Constraints:** Work in the current checkout, avoid unrelated refactors, preserve four-language copy, and do not commit before user confirmation.

### Task 1: CloudKit account status check

- [ ] Add failing evaluator tests for available and unavailable statuses.
- [ ] Implement the evaluator and CloudKit account-status lookup.
- [x] Run focused tests, full SwiftPM tests, simulator build, and `git diff --check`.
- [ ] Ask for confirmation before committing or pushing.
