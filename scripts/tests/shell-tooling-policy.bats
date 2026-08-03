#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

scan_count_commands() {
  rg -n --glob '*.sh' --glob '!**/tests/**' \
    'grep[[:space:]]+(-[[:alpha:]]*c([[:space:]]|$)|--count([[:space:]]|$))' "$1"
}

@test "production shell scripts do not use grep count modes" {
  run scan_count_commands "$REPO_ROOT/scripts"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "count policy detects short and long grep count options" {
  mkdir -p "$BATS_TEST_TMPDIR/scripts/tests"
  printf '%s\n' 'grep -c needle input' >"$BATS_TEST_TMPDIR/scripts/short.sh"
  printf '%s\n' 'grep --count needle input' >"$BATS_TEST_TMPDIR/scripts/long.sh"
  printf '%s\n' 'grep -c ignored fixture' >"$BATS_TEST_TMPDIR/scripts/tests/fixture.sh"

  run scan_count_commands "$BATS_TEST_TMPDIR/scripts"

  [ "$status" -eq 0 ]
  [[ "$output" == *"short.sh"* ]]
  [[ "$output" == *"long.sh"* ]]
  [[ "$output" != *"fixture.sh"* ]]
}
