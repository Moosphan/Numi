#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly DEFAULT_STAGES="swift-test,localization,xcode-project,xcode-build,ui-tests,references"
readonly REQUESTED_STAGES="${NUMI_VERIFY_STAGES:-$DEFAULT_STAGES}"
readonly SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 15}"
readonly DERIVED_DATA_PATH="${NUMI_DERIVED_DATA_PATH:-$ROOT/build/verify-derived-data}"

IFS=',' read -r -a selected_stages <<< "$REQUESTED_STAGES"

stage_is_selected() {
  local requested
  for requested in "${selected_stages[@]}"; do
    [[ "$requested" == "$1" ]] && return 0
  done
  return 1
}

validate_stage_names() {
  local stage
  for stage in "${selected_stages[@]}"; do
    case "$stage" in
      swift-test|localization|xcode-project|xcode-build|ui-tests|references) ;;
      *)
        echo "Unknown verification stage: $stage" >&2
        echo "Available stages: $DEFAULT_STAGES" >&2
        exit 2
        ;;
    esac
  done
}

run_stage() {
  local identifier="$1"
  local title="$2"
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

verify_references() {
  local design_count image_count

  design_count="$(find docs/design -maxdepth 1 -type f -name '*.html' | wc -l | tr -d ' ')"
  if [[ "$design_count" -lt 10 ]]; then
    echo "Expected at least 10 design HTML files, found $design_count" >&2
    return 1
  fi

  image_count="$(find docs/assets/cookie-ios -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
  if [[ "$image_count" -lt 10 ]]; then
    echo "Expected at least 10 Cookie screenshot assets, found $image_count" >&2
    return 1
  fi

python3 - <<'PY'
import pathlib
import re
import sys

for md_path in ["style.md"]:
    md = pathlib.Path(md_path).read_text()
    refs = re.findall(r"!\[[^\]]*\]\(([^)]+)\)", md)
    missing = [p for p in refs if not pathlib.Path(p).exists()]
    if missing:
        print(f"{md_path} has missing image refs:", file=sys.stderr)
        for p in missing:
            print(p, file=sys.stderr)
        sys.exit(1)

required_docs = [
    "docs/prd/local-first-bookkeeping-prd.md",
    "docs/tech/ios-swiftui-technical-solution.md",
    "docs/backlog/ios-swiftui-backlog.md",
    "style.md",
]
for path in required_docs:
    if not pathlib.Path(path).exists():
        print(f"Missing required doc: {path}", file=sys.stderr)
        sys.exit(1)
PY
}

generate_xcode_project_if_needed() {
  if [[ -f Numi.xcodeproj/project.pbxproj ]]; then
    echo "Using checked-in Xcode project; generation skipped."
    return 0
  fi

  ruby scripts/generate_xcodeproj.rb
}

prepare_simulator() {
  xcrun simctl boot "$SIMULATOR_NAME" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_NAME" -b
}

validate_stage_names

if stage_is_selected swift-test; then
  run_stage swift-test "Swift package tests" swift test
fi

if stage_is_selected localization; then
  run_stage localization "Localization catalog validation" python3 scripts/check_localization.py --allow-duplicates
fi

if stage_is_selected xcode-project; then
  run_stage xcode-project "Generate Xcode project" generate_xcode_project_if_needed
fi

if stage_is_selected xcode-build; then
  run_stage xcode-build "Xcode Debug build" xcodebuild \
    -project Numi.xcodeproj \
    -scheme Numi \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

if stage_is_selected ui-tests; then
  run_stage ui-tests "Boot iOS Simulator" prepare_simulator
  run_stage ui-tests "Key iOS UI tests" xcodebuild \
    -project Numi.xcodeproj \
    -scheme Numi \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -only-testing:NumiUITests/NumiUITests/testTabsAndAddRecordSheetAreReachable \
    -only-testing:NumiUITests/NumiUITests/testAddingExpenseAppearsInTransactionsList \
    -only-testing:NumiUITests/NumiUITests/testEditingExpenseUpdatesList \
    -only-testing:NumiUITests/NumiUITests/testDeletingExpenseCanBeUndone \
    -only-testing:NumiUITests/NumiUITests/testCanSwitchAppLanguageAtRuntimeFromSettings \
    test
fi

if stage_is_selected references; then
  run_stage references "Design and document references" verify_references
fi

echo "Verification passed."
