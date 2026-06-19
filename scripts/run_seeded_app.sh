#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROFILE="${1:-showcase}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 15}"
DEV_STORE_ID="${NUMI_DEV_STORE_ID:-seeded-${PROFILE}}"
RESET_FLAG="${NUMI_SEED_RESET:-1}"
BUNDLE_ID="${BUNDLE_ID:-com.local.Numi}"

ruby scripts/generate_xcodeproj.rb >/dev/null

xcodebuild \
  -project Numi.xcodeproj \
  -scheme Numi \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  build >/dev/null

APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug-iphonesimulator/Numi.app' | head -n 1)"
if [[ -z "${APP_PATH}" ]]; then
  echo "Unable to find built Numi.app" >&2
  exit 1
fi

SIMULATOR_ID="$(xcrun simctl list devices available | awk -F '[()]' -v name="${SIMULATOR_NAME}" '$0 ~ name { print $2; exit }')"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "Unable to find simulator named ${SIMULATOR_NAME}" >&2
  exit 1
fi

xcrun simctl boot "${SIMULATOR_ID}" >/dev/null 2>&1 || true
xcrun simctl uninstall "${SIMULATOR_ID}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
xcrun simctl install "${SIMULATOR_ID}" "${APP_PATH}"
SIMCTL_CHILD_NUMI_SEED_PROFILE="${PROFILE}" \
SIMCTL_CHILD_NUMI_SEED_RESET="${RESET_FLAG}" \
SIMCTL_CHILD_NUMI_DEV_STORE_ID="${DEV_STORE_ID}" \
xcrun simctl launch \
  --terminate-running-process \
  "${SIMULATOR_ID}" \
  "${BUNDLE_ID}"

echo "Launched bundle=${BUNDLE_ID} profile=${PROFILE} on ${SIMULATOR_NAME} with NUMI_DEV_STORE_ID=${DEV_STORE_ID}"
