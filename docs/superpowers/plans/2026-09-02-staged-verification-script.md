# Staged Verification Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `scripts/verify.sh` a deterministic, one-command verification entry point that identifies a failed phase and permits focused reruns.

**Architecture:** A Bash `run_stage` helper prints a stable start/pass/fail marker and exits on the first failing command. The default run executes all stages. `NUMI_VERIFY_STAGES` accepts a comma-separated stage list for diagnosis while preserving the default full path.

**Tech Stack:** Bash, Python 3 pytest, SwiftPM, Xcode/iOS Simulator.

## Global Constraints

- Work in the current checkout; do not create a worktree.
- Keep `./scripts/verify.sh` as the documented full verification command.
- Use ignored `build/verify-derived-data`, never a personal DerivedData path.
- Treat the checked-in `Numi.xcodeproj` as the verification input. `generate_xcodeproj.rb` is non-idempotent and may only run when that project file is absent.
- Check catalogs with `--allow-duplicates` while the existing 585 catalog-ownership duplicates remain tracked technical debt; do not suppress their warnings.
- Do not commit until the user has reviewed verified changes.

---

### Task 1: Define the script's observable stage contract

**Files:**
- Create: `scripts/tests/test_verify.py`
- Test: `scripts/tests/test_verify.py`

**Interfaces:**
- Consumes: `NUMI_VERIFY_STAGES` and fake `swift` / `python3` commands placed first in `PATH`.
- Produces: a testable contract that selected stages execute in sequence and a failed stage stops all later stages.

- [x] **Step 1: Write failing subprocess tests**

```python
def run_verify(tmp_path: Path, stages: str, statuses: dict[str, int]):
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls_path = tmp_path / "calls.txt"
    for command, status in statuses.items():
        executable = fake_bin / command
        executable.write_text(
            "#!/usr/bin/env bash\n"
            f"printf '%s ' '$0' \"$@\" >> '{calls_path}'\n"
            f"printf '\\n' >> '{calls_path}'\nexit {status}\n"
        )
        executable.chmod(0o755)
    result = subprocess.run(
        ["bash", "scripts/verify.sh"],
        cwd=Path(__file__).resolve().parents[2],
        env={**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}", "NUMI_VERIFY_STAGES": stages},
        capture_output=True,
        text=True,
    )
    return result, calls_path.read_text().splitlines() if calls_path.exists() else []

def test_selected_stages_run_in_order(tmp_path: Path):
    result, calls = run_verify(tmp_path, "swift-test,localization", {"swift": 0, "python3": 0})
    assert result.returncode == 0, result.stderr
    assert calls == ["swift test", "python3 scripts/check_localization.py --allow-duplicates"]
    assert "== [swift-test] Swift package tests ==" in result.stdout
    assert "== [localization] Localization catalog validation ==" in result.stdout

def test_failed_stage_is_reported_and_stops_later_stages(tmp_path: Path):
    result, calls = run_verify(tmp_path, "swift-test,localization", {"swift": 19, "python3": 0})
    assert result.returncode == 19
    assert calls == ["swift test"]
    assert "== [swift-test] Swift package tests FAILED ==" in result.stderr
    assert "Verification stopped at stage: Swift package tests" in result.stderr
```

- [x] **Step 2: Run the new tests to demonstrate the missing interface**

Run: `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest scripts/tests/test_verify.py -q`

Expected: FAIL because the script neither accepts `NUMI_VERIFY_STAGES` nor prints stage-specific failure markers.

### Task 2: Implement stage selection and all required phases

**Files:**
- Modify: `scripts/verify.sh`
- Test: `scripts/tests/test_verify.py`

**Interfaces:**
- Consumes: `NUMI_VERIFY_STAGES`, `SIMULATOR_NAME` (default `iPhone 15`), `NUMI_DERIVED_DATA_PATH` (default `$ROOT/build/verify-derived-data`).
- Produces: `swift-test`, `localization`, `xcode-project`, `xcode-build`, `ui-tests`, and `references` stages.

- [x] **Step 1: Add the selector and wrapper before any stage calls**

```bash
selected_stage() {
  local candidate
  IFS=',' read -r -a selected <<< "${NUMI_VERIFY_STAGES:-swift-test,localization,xcode-project,xcode-build,ui-tests,references}"
  for candidate in "${selected[@]}"; do
    [[ "$candidate" == "$1" ]] && return 0
  done
  return 1
}

run_stage() {
  local identifier="$1" title="$2"
  shift 2
  echo "== [$identifier] $title =="
  if "$@"; then
    echo "== [$identifier] $title passed =="
  else
    local status=$?
    echo "== [$identifier] $title FAILED ==" >&2
    echo "Verification stopped at stage: $title" >&2
    return "$status"
  fi
}
```

- [x] **Step 2: Route existing commands through six explicit stages**

```bash
verify_references() {
  local design_count image_count
  design_count="$(find docs/design -maxdepth 1 -type f -name '*.html' | wc -l | tr -d ' ')"
  image_count="$(find docs/assets/cookie-ios -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
  [[ "$design_count" -ge 10 ]] && [[ "$image_count" -ge 10 ]]
  python3 - <<'PY'
import pathlib, re
missing = [path for path in re.findall(r"!\\[[^]]*\\]\\(([^)]+)\\)", pathlib.Path("style.md").read_text()) if not pathlib.Path(path).exists()]
assert not missing, f"style.md has missing image refs: {missing}"
for path in ["docs/prd/local-first-bookkeeping-prd.md", "docs/tech/ios-swiftui-technical-solution.md", "docs/backlog/ios-swiftui-backlog.md", "style.md"]:
    assert pathlib.Path(path).exists(), f"Missing required doc: {path}"
PY
}

run_stage swift-test "Swift package tests" swift test
run_stage localization "Localization catalog validation" python3 scripts/check_localization.py --allow-duplicates
run_stage xcode-project "Generate Xcode project" ruby scripts/generate_xcodeproj.rb
run_stage xcode-build "Xcode Debug build" xcodebuild -project Numi.xcodeproj -scheme Numi -destination "platform=iOS Simulator,name=${SIMULATOR_NAME:-iPhone 15}" -derivedDataPath "${NUMI_DERIVED_DATA_PATH:-$ROOT/build/verify-derived-data}" build
run_stage ui-tests "Key iOS UI tests" xcodebuild -project Numi.xcodeproj -scheme Numi -destination "platform=iOS Simulator,name=${SIMULATOR_NAME:-iPhone 15}" -derivedDataPath "${NUMI_DERIVED_DATA_PATH:-$ROOT/build/verify-derived-data}" -only-testing:NumiUITests/NumiUITests/testTabsAndAddRecordSheetAreReachable -only-testing:NumiUITests/NumiUITests/testAddingExpenseAppearsInTransactionsList -only-testing:NumiUITests/NumiUITests/testEditingExpenseUpdatesList -only-testing:NumiUITests/NumiUITests/testDeletingExpenseCanBeUndone -only-testing:NumiUITests/NumiUITests/testCanSwitchAppLanguageAtRuntimeFromSettings test
run_stage references "Design and document references" verify_references
```

- [x] **Step 3: Verify syntax and focused tests**

Run: `bash -n scripts/verify.sh && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest scripts/tests/test_verify.py -q`

Expected: exit `0`; test output proves stage order and stop-on-first-failure behavior.

### Task 3: Document and run the real verification contract

**Files:**
- Modify: `README.md:148-157`
- Modify: `docs/backlog/current-priority-backlog.md`
- Test: `scripts/verify.sh`

**Interfaces:**
- Consumes: `./scripts/verify.sh` and optional `NUMI_VERIFY_STAGES=swift-test,localization`.
- Produces: documentation matching the script and a P0A-04 completion update only after the full command exits successfully.

- [x] **Step 1: Add this focused-retry example below the existing README command**

```markdown
NUMI_VERIFY_STAGES=swift-test,localization ./scripts/verify.sh
```

- [x] **Step 2: Run real non-simulator stages**

Run: `NUMI_VERIFY_STAGES=swift-test,localization,references ./scripts/verify.sh`

Expected: exit `0` with a start/pass marker for every selected stage.

- [x] **Step 3: Run full verification on iPhone 15**

Run: `./scripts/verify.sh`

Expected: exit `0`; output names all six stages.

- [x] **Step 4: Check final diff and wait for approval**

Run: `git diff --check && git diff -- scripts/verify.sh scripts/tests/test_verify.py README.md docs/backlog/current-priority-backlog.md`

Expected: no whitespace errors or unrelated source changes.

- [ ] **Step 5: Commit only after user approval**

```bash
git add scripts/verify.sh scripts/tests/test_verify.py README.md docs/backlog/current-priority-backlog.md docs/superpowers/plans/2026-09-02-staged-verification-script.md
git commit -m "chore: stage project verification"
```

## Self-Review

- Coverage: SwiftPM tests, catalog scan, project generation, Xcode build, key UI tests, and existing reference checks each have a named stage.
- Diagnostics: the wrapper emits the failed stage and never runs a later stage after failure.
- Reproducibility: all Xcode commands share a repository-local derived-data location and a configurable, fixed simulator name.
- Scope: catalog duplicates remain visible warnings but are deliberately not folded into this script-refactor change.
