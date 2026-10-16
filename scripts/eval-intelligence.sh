#!/usr/bin/env bash
# Needs a Mac with Apple Intelligence turned on. Slow and not deterministic, so it isn't part
# of scripts/check.sh; run it when prompts, schemas or the library change.
set -euo pipefail
cd "$(dirname "$0")/../Packages/TransmuteIntelligence"
TRANSMUTE_MODEL_TESTS=1 swift test --filter ModelTests "$@"
