#!/usr/bin/env bats
#
# scripts/tests/parallelism-report-parser.bats
#
# Phase 4b wrapper around scripts/test-parallelism-report-parser.sh.
# See scripts/tests/README.md for the migration approach.

# Per-test timeout (seconds). Must be set at file-load time, before any
# test runs — bats reads this in the parent process before forking the
# subprocess for setup()/the test, so setting it inside setup() is a
# no-op (codex/cursor P2 review feedback on PR #274).
export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
}

@test "parallelism-report-parser: legacy scripts/test-parallelism-report-parser.sh passes" {
  run bash "$REPO_ROOT/scripts/test-parallelism-report-parser.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
