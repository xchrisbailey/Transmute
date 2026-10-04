#!/bin/sh
# Xcode Cloud runs this after each build action. When the action produced a build for
# TestFlight, its "What to Test" notes are the last few commit subjects.
set -eu

if [ -d "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]; then
  notes_dir="$CI_PRIMARY_REPOSITORY_PATH/TestFlight"
  mkdir -p "$notes_dir"
  git -C "$CI_PRIMARY_REPOSITORY_PATH" fetch --deepen 5 --quiet || true
  git -C "$CI_PRIMARY_REPOSITORY_PATH" log -5 --no-merges --pretty=format:"- %s" \
    > "$notes_dir/WhatToTest.en-US.txt"
fi
