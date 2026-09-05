# P1-05 App Intents 本地化实施计划

**Goal:** Make Siri/App Intents metadata and dialogs follow the app's four supported languages.

**Architecture:** Keep the existing intent and persistence flow unchanged. Replace hard-coded metadata/dialog text with `NumiIntents/Localizable.xcstrings` keys and use the existing localized format strings for dynamic results.

**Constraints:** Work in the current checkout, avoid unrelated refactors, preserve existing behavior, and do not commit before user confirmation.

### Task 1: Localize intent metadata and dialogs

- [x] Replace hard-coded title, description, parameter title, and dialogs with localized resources.
- [x] Verify the App Intents target through an iOS simulator build.
- [x] Check `git diff --check` and update backlog evidence.
- [ ] Ask for confirmation before committing or pushing.
