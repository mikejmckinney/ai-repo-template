#!/usr/bin/env bats
#
# scripts/tests/pr-iteration-stats.bats
#
# Phase 4b wrapper around scripts/test-pr-iteration-stats.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "pr-iteration-stats: legacy scripts/test-pr-iteration-stats.sh passes" {
  run bash "$REPO_ROOT/scripts/test-pr-iteration-stats.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
