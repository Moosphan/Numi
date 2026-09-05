# TestFlight Release Checklist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the repository ready for a traceable TestFlight submission by adding the required-reason privacy manifest and a release checklist that separates verified repository facts from App Store Connect actions.

**Architecture:** Add `PrivacyInfo.xcprivacy` to the main app target's resources, declaring only the required-reason API proven by code review: `UserDefaults` with Apple reason `CA92.1`. Add a Markdown checklist with release metadata, archive checks, TestFlight setup, privacy-label ownership, and known product risks. It will intentionally not declare external AI or CloudKit collection behavior in the manifest because that requires current provider and App Store Connect disclosure review.

**Tech Stack:** Xcode project configuration, Apple privacy manifest plist, Markdown.

## Global Constraints

- Keep the change limited to release configuration and documentation; do not change runtime behavior or localized UI copy.
- Add only privacy API reasons supported by source inspection and Apple documentation.
- Keep App Store Connect privacy labels as a manual release gate; do not claim the repository alone completes them.
- Verify the manifest is valid, included in the built app bundle, run `swift test`, `git diff --check`, and an iOS Simulator Debug build before requesting commit approval.

---

### Task 1: Add a required-reason privacy manifest

**Files:**
- Create: `App/NumiApp/PrivacyInfo.xcprivacy`
- Modify: `Numi.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `UserDefaults` use in the main app and App Intents code.
- Produces: `PrivacyInfo.xcprivacy` at the root of the built `Numi.app` bundle.

- [x] **Step 1: Run the failing manifest-presence check**

Run:

```bash
test -f App/NumiApp/PrivacyInfo.xcprivacy
```

Expected: FAIL because the privacy manifest has not been created.

- [x] **Step 2: Add the minimal valid manifest**

Create a plist containing exactly this accessed-API declaration:

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
<key>NSPrivacyTracking</key>
<false/>
```

Do not add `NSPrivacyCollectedDataTypes` until the release owner reviews the final CloudKit and AI-provider retention practices for the App Store Connect privacy label. Add the manifest file reference and resource build-file entry to the `Numi` target only.

- [x] **Step 3: Verify the manifest source and built placement**

Run:

```bash
plutil -lint App/NumiApp/PrivacyInfo.xcprivacy
xcodebuild -quiet -project Numi.xcodeproj -scheme Numi -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/NumiDerivedDataP0C05 CODE_SIGNING_ALLOWED=NO build
test -f /tmp/NumiDerivedDataP0C05/Build/Products/Debug-iphonesimulator/Numi.app/PrivacyInfo.xcprivacy
plutil -lint /tmp/NumiDerivedDataP0C05/Build/Products/Debug-iphonesimulator/Numi.app/PrivacyInfo.xcprivacy
```

Expected: both plists validate and the privacy manifest exists at the iOS app-bundle root.

### Task 2: Publish a TestFlight release checklist

**Files:**
- Create: `docs/release/testflight-checklist.md`
- Modify: `README.md`
- Modify: `docs/backlog/current-priority-backlog.md`

**Interfaces:**
- Consumes: build settings, entitlements, app icon asset catalog, privacy manifest, and data-management documentation.
- Produces: a version-controlled release checklist linked from the README.

- [x] **Step 1: Document verified repository facts**

Create checklist sections covering `com.local.Numi`, version `1.0 (1)`, iOS 17 deployment, complete App Icon slots, CloudKit/App Group entitlements, privacy manifest presence, and the normal verification commands.

- [x] **Step 2: Document manual TestFlight gates**

Add unchecked gates for App Store Connect record creation, signing/provisioning, archive/upload, TestFlight tester groups, export-compliance answers, privacy policy URL, App Privacy label review for optional CloudKit and configured AI providers, screenshots, support URL, and real-device checks.

- [x] **Step 3: Document known product risks without hiding them**

List the unresolved P1 iCloud conflict/multi-device validation and the existing App Intents metadata warning as release decision items. Link to `docs/data-management.md` for backup and import behavior.

- [x] **Step 4: Link and verify documentation**

Add a README link to the checklist, mark P0C-05 as Partial with the repository checklist evidence, then run:

```bash
test -f docs/release/testflight-checklist.md
rg -n "testflight-checklist.md" README.md
git diff --check
swift test
```

Expected: checklist and README link exist, diff is clean, and Swift tests exit 0.

- [ ] **Step 5: Commit after user confirmation**

```bash
git add App/NumiApp/PrivacyInfo.xcprivacy Numi.xcodeproj/project.pbxproj README.md docs/release/testflight-checklist.md docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-05-testflight-release-checklist.md
git commit -m "chore: add TestFlight release checklist"
git push origin main
```
