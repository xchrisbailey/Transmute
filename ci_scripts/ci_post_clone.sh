#!/bin/sh
# Xcode Cloud runs this after cloning, before it resolves packages and builds.
# The Xcode project isn't checked in, so generate it from project.yml, and sign with the
# team in the workflow's TRANSMUTE_TEAM_ID environment variable, because Config/Local.xcconfig
# is gitignored. See docs/TESTFLIGHT.md.
set -eu
cd "$CI_PRIMARY_REPOSITORY_PATH"

if [ -z "${TRANSMUTE_TEAM_ID:-}" ]; then
  echo "error: set TRANSMUTE_TEAM_ID in the Xcode Cloud workflow's environment" >&2
  exit 1
fi

cat > Config/Local.xcconfig <<XCCONFIG
DEVELOPMENT_TEAM = $TRANSMUTE_TEAM_ID
TRANSMUTE_MAC_ENTITLEMENTS = Apps/TransmuteMac/TransmuteMac.entitlements
TRANSMUTE_MAC_WIDGETS_ENTITLEMENTS = Apps/TransmuteMacWidgets/TransmuteMacWidgets.entitlements
XCCONFIG

brew install xcodegen
xcodegen generate
