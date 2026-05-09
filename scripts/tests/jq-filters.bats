#!/usr/bin/env bats
#
# scripts/tests/jq-filters.bats
#
# Phase 4b wrapper around scripts/test-jq-filters.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "jq-filters: legacy scripts/test-jq-filters.sh passes" {
  run bash "$REPO_ROOT/scripts/test-jq-filters.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
