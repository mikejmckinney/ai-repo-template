#!/usr/bin/env bats
#
# scripts/tests/auto-rebase-overlapping.bats
#
# Phase 4b wrapper around scripts/test-auto-rebase-overlapping.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "auto-rebase-overlapping: legacy scripts/test-auto-rebase-overlapping.sh passes" {
  run bash "$REPO_ROOT/scripts/test-auto-rebase-overlapping.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
