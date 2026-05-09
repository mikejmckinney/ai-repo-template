#!/usr/bin/env bats
#
# scripts/tests/phase4-fallback-parser.bats
#
# Phase 4b wrapper around scripts/test-phase4-fallback-parser.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "phase4-fallback-parser: legacy scripts/test-phase4-fallback-parser.sh passes" {
  run bash "$REPO_ROOT/scripts/test-phase4-fallback-parser.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
