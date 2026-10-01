#!/usr/bin/env bash
# Runs every check locally: lint, package tests and an unsigned build of each app.
# There's no hosted CI; run this before pushing.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

echo "==> SwiftLint"
swiftlint lint --strict --quiet
echo "==> swift-format"
swift format lint --strict --recursive Apps Packages
echo "==> Package tests"
scripts/test-packages.sh
echo "==> App builds"
scripts/build-apps.sh "$@"
echo "All checks passed."
