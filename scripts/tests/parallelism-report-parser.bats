#!/usr/bin/env bats
#
# scripts/tests/parallelism-report-parser.bats
#
# Phase 4b wrapper around scripts/test-parallelism-report-parser.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "parallelism-report-parser: legacy scripts/test-parallelism-report-parser.sh passes" {
  run bash "$REPO_ROOT/scripts/test-parallelism-report-parser.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
