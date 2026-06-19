#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Swift package tests =="
swift test

echo "== Generate Xcode project =="
ruby scripts/generate_xcodeproj.rb

echo "== Xcode UI tests =="
xcodebuild \
  -project Numi.xcodeproj \
  -scheme Numi \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test

echo "== Design references =="
design_count="$(find docs/design -maxdepth 1 -type f -name '*.html' | wc -l | tr -d ' ')"
if [[ "$design_count" -lt 10 ]]; then
  echo "Expected at least 10 design HTML files, found $design_count" >&2
  exit 1
fi

echo "== Cookie screenshot references =="
image_count="$(find docs/assets/cookie-ios -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
if [[ "$image_count" -lt 10 ]]; then
  echo "Expected at least 10 Cookie screenshot assets, found $image_count" >&2
  exit 1
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

echo "Verification passed."
