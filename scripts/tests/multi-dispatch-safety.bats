#!/usr/bin/env bats
#
# scripts/tests/multi-dispatch-safety.bats
#
# Phase 4b wrapper around scripts/test-multi-dispatch-safety.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "multi-dispatch-safety: legacy scripts/test-multi-dispatch-safety.sh passes" {
  run bash "$REPO_ROOT/scripts/test-multi-dispatch-safety.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
