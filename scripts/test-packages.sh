#!/usr/bin/env bash
# Runs `swift test` for every local package.
set -euo pipefail
cd "$(dirname "$0")/../Packages"
for package in */; do
  echo "::group::Test ${package%/}"
  (cd "$package" && swift test)
  echo "::endgroup::"
done
