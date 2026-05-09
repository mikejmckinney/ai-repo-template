#!/usr/bin/env bats
#
# scripts/tests/coordination-sync.bats
#
# Phase 4b wrapper around scripts/test-coordination-sync.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "coordination-sync: legacy scripts/test-coordination-sync.sh passes" {
  run bash "$REPO_ROOT/scripts/test-coordination-sync.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
