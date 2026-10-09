#!/usr/bin/env bash
# Runs every check locally and records the result against the commit: lint, package tests
# and an unsigned build of each app. There's no hosted CI; run this before pushing.
#
#   scripts/check.sh                   run everything on HEAD and record it
#   scripts/check.sh <scheme> ...      build only those apps; recorded as PARTIAL
#   scripts/check.sh --allow-dirty     run on uncommitted work; nothing is recorded
#   scripts/check.sh --show [<commit>] print a commit's record (default HEAD)
#
# A record is the evidence that a commit passed. It lives in the repository's git directory,
# so every worktree reads the same ones and none is ever committed. Its last line is
# RESULT: PASS, RESULT: FAIL or RESULT: PARTIAL. --show exits 0 for PASS, 1 for FAIL or
# PARTIAL, and 2 when the commit has no record.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

records="$(cd "$(git rev-parse --git-common-dir)" && pwd)/transmute-check"

if [ "${1:-}" = "--show" ]; then
  commit=$(git rev-parse --verify --quiet "${2:-HEAD}^{commit}") || {
    echo "No such commit: ${2:-HEAD}" >&2
    exit 2
  }
  if [ ! -f "$records/$commit" ]; then
    echo "No check record for $commit" >&2
    exit 2
  fi
  cat "$records/$commit"
  [ "$(tail -n 1 "$records/$commit")" = "RESULT: PASS" ]
  exit $?
fi

records_result=1
schemes=()
for argument in "$@"; do
  case "$argument" in
    --allow-dirty) records_result=0 ;;
    -*)
      echo "Unknown option $argument" >&2
      exit 64
      ;;
    *) schemes+=("$argument") ;;
  esac
done

if [ "$records_result" -eq 1 ] && [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes: a record is for a commit, so commit first." >&2
  echo "To run without recording, use scripts/check.sh --allow-dirty." >&2
  exit 65
fi

commit=$(git rev-parse HEAD)
mkdir -p build
steps=()
failed=0

step() {
  local name="$1"
  shift
  echo "==> $name"
  if "$@"; then
    steps+=("PASS  $name")
  else
    steps+=("FAIL  $name")
    failed=1
  fi
}

step "SwiftLint" swiftlint lint --strict --quiet
step "swift-format" swift format lint --strict --recursive Apps Packages
step "Package tests" scripts/test-packages.sh
if [ ${#schemes[@]} -eq 0 ]; then
  step "App builds: TransmuteiOS TransmuteWatch TransmuteMac" scripts/build-apps.sh
else
  step "App builds: ${schemes[*]}" scripts/build-apps.sh "${schemes[@]}"
fi

if [ "$failed" -eq 1 ]; then
  result=FAIL
elif [ ${#schemes[@]} -gt 0 ]; then
  result=PARTIAL
else
  result=PASS
fi

if [ "$records_result" -eq 1 ]; then
  mkdir -p "$records"
  {
    echo "commit: $commit"
    echo "branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "ran:    $(date -u '+%Y-%m-%d %H:%M:%S UTC') in $(pwd)"
    printf '%s\n' "${steps[@]}"
    [ -z "$(git status --porcelain)" ] || echo "note:   the run left uncommitted changes in the tree"
    echo "RESULT: $result"
  } >|"$records/$commit"
  echo
  cat "$records/$commit"
else
  echo
  printf '%s\n' "${steps[@]}"
  echo "Not recorded: the tree had uncommitted changes."
fi

case "$result" in
  PASS) echo "All checks passed." ;;
  PARTIAL) echo "Passed, but only for ${schemes[*]}: not a full pass." ;;
  FAIL) exit 1 ;;
esac
