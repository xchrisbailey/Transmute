#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../Packages"
for package in */; do
  echo "--- Test ${package%/}"
  (cd "$package" && swift test)
done
