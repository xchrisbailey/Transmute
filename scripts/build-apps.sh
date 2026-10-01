#!/usr/bin/env bash
# Builds every app target for its simulator (or the Mac) without signing.
# Usage: scripts/build-apps.sh [scheme ...]
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet

schemes=("$@")
[ ${#schemes[@]} -eq 0 ] && schemes=(TransmuteiOS TransmuteWatch TransmuteMac)

for scheme in "${schemes[@]}"; do
  case "$scheme" in
    TransmuteiOS) destination="generic/platform=iOS Simulator" ;;
    TransmuteWatch) destination="generic/platform=watchOS Simulator" ;;
    TransmuteMac) destination="platform=macOS" ;;
    *) echo "Unknown scheme $scheme" >&2; exit 1 ;;
  esac
  echo "--- Build $scheme"
  xcodebuild build \
    -project Transmute.xcodeproj \
    -scheme "$scheme" \
    -destination "$destination" \
    -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    | tee "build/$scheme.log" | grep -E "error:|warning: .*\.swift|BUILD (SUCCEEDED|FAILED)" || true
  test "${PIPESTATUS[0]}" -eq 0
done
