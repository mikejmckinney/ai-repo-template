#!/usr/bin/env bats
#
# scripts/tests/closeout.bats
#
# Phase 4b wrapper around scripts/test-closeout.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "closeout: legacy scripts/test-closeout.sh passes" {
  run bash "$REPO_ROOT/scripts/test-closeout.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
