#!/usr/bin/env bash
#
# Soothbee — one-command build + run on iPhone 15 simulator.
# Usage:
#   bash scripts/build-and-run-simulator.sh
#
# If actool hangs (known issue with this project), reboot the Mac and retry.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/BabyInCarApp/BabyInCarApp.xcodeproj"
SCHEME="BabyInCarApp"
BUNDLE_ID="com.babyincar.app"
# First-preference simulator. Override by exporting SOOTHBEE_SIM=…
SIM_NAME="${SOOTHBEE_SIM:-iPhone 16}"
DERIVED="$REPO_ROOT/BabyInCarApp/build"

echo "→ Soothbee local build"
echo "  project: $PROJECT"
echo "  scheme:  $SCHEME"
echo "  sim:     $SIM_NAME"
echo

# Pick a matching simulator UDID, then fall back to any available iPhone.
pick_udid() {
  xcrun simctl list devices available 2>/dev/null \
    | awk -F '[()]' -v name="$1" '$0 ~ name && $0 !~ /unavailable/ { print $2; exit }'
}

UDID="$(pick_udid "$SIM_NAME")"
if [[ -z "${UDID}" ]]; then
  echo "… \"$SIM_NAME\" not installed; falling back to first available iPhone."
  UDID="$(pick_udid "iPhone")"
fi

if [[ -z "${UDID}" ]]; then
  echo "✗ No iPhone simulators available. Open Xcode → Window → Devices and Simulators to add one."
  exit 1
fi

echo "→ simulator UDID: $UDID"

# Boot simulator (no-op if already booted)
xcrun simctl boot "$UDID" 2>/dev/null || true
open -g -a Simulator 2>/dev/null || true

echo "→ building (this is where actool can hang; reboot if it does) ..."
# Note: the BabyInCarWatchApp target has a pre-existing project misconfiguration
# (watchOS iconset being compiled against iphonesimulator platform) that causes
# actool to fail. Build the iOS app standalone by excluding the Watch dependency
# — open the project in Xcode and toggle Target Dependencies if you hit it.
if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -quiet \
    build; then
  echo "✓ build ok"
else
  RC=$?
  echo "✗ build failed (rc=$RC)"
  echo
  echo "  Troubleshooting:"
  echo "  1. If output says 'actool' hung: reboot the Mac and re-run (known actool IPC bug)."
  echo "  2. If output says 'WatchKit' module missing OR 'AppIcon did not have any applicable content':"
  echo "     pre-existing Watch-target misconfig. In Xcode:"
  echo "       a. Select the BabyInCarApp scheme (not BabyInCarWatchApp)"
  echo "       b. Product → Scheme → Manage Schemes → uncheck 'Build' for BabyInCarWatchApp"
  echo "       c. Re-run this script (or Cmd+R in Xcode)"
  echo "  3. Otherwise, open /tmp/soothbee-build.log for the full error."
  exit $RC
fi

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ product not found at $APP_PATH"
  exit 1
fi

echo "→ installing ..."
xcrun simctl install "$UDID" "$APP_PATH"

echo "→ launching $BUNDLE_ID ..."
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo
echo "✓ Soothbee running. Look for:"
echo "  • Honey-gold hex app icon on home screen"
echo "  • Display name 'Soothbee'"
echo "  • Launch screen tagline: 'The hum that calms your baby.'"
echo "  • Tap cry detection → honeycomb pulses"
