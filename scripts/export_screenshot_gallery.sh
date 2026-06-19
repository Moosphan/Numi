#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 15}"
OUTPUT_DIR="${1:-$ROOT/.codex-screenshots/gallery}"
RESULT_BUNDLE_DIR="${RESULT_BUNDLE_DIR:-$ROOT/.codex-screenshots/xcresults}"
RESULT_BUNDLE_PATH="$RESULT_BUNDLE_DIR/gallery.xcresult"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$RESULT_BUNDLE_DIR"
rm -f "$OUTPUT_DIR"/*.png
rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild \
  -project Numi.xcodeproj \
  -scheme Numi \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -only-testing:NumiUITests/NumiUITests/testCaptureScreenshotShowcaseGallery \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  test >/tmp/numi_gallery_xcodebuild.log

if [[ ! -d "$RESULT_BUNDLE_PATH" ]]; then
  echo "Unable to locate xcresult bundle" >&2
  exit 1
fi

python3 - "$RESULT_BUNDLE_PATH" "$OUTPUT_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
output_dir = Path(sys.argv[2])

root = json.loads(subprocess.check_output([
    "xcrun", "xcresulttool", "get",
    "--path", str(bundle),
    "--format", "json",
]))
tests_ref = root["actions"]["_values"][0]["actionResult"]["testsRef"]["id"]["_value"]

tests = json.loads(subprocess.check_output([
    "xcrun", "xcresulttool", "get",
    "--path", str(bundle),
    "--id", tests_ref,
    "--format", "json",
]))
summary_ref = tests["summaries"]["_values"][0]["testableSummaries"]["_values"][0]["tests"]["_values"][0]["subtests"]["_values"][0]["subtests"]["_values"][0]["subtests"]["_values"][0]["summaryRef"]["id"]["_value"]
summary = json.loads(subprocess.check_output([
    "xcrun", "xcresulttool", "get",
    "--path", str(bundle),
    "--id", summary_ref,
    "--format", "json",
]))

attachments = []
for activity in summary.get("activitySummaries", {}).get("_values", []):
    for attachment in activity.get("attachments", {}).get("_values", []):
        if attachment.get("uniformTypeIdentifier", {}).get("_value") != "public.png":
            continue
        name = attachment.get("name", {}).get("_value")
        payload_ref = attachment.get("payloadRef", {}).get("id", {}).get("_value")
        if not name or not payload_ref:
            continue
        attachments.append((name, payload_ref))

attachments.sort(key=lambda item: item[0])

for name, payload_ref in attachments:
    subprocess.check_call([
        "xcrun", "xcresulttool", "export",
        "--path", str(bundle),
        "--id", payload_ref,
        "--type", "file",
        "--output-path", str(output_dir / f"{name}.png"),
    ])

print(f"Exported {len(attachments)} screenshots to {output_dir}")
if len(attachments) != 10:
    raise SystemExit(f"Expected 10 screenshots, found {len(attachments)}")
PY

echo "Gallery exported to $OUTPUT_DIR"
