#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/lib/search.sh
  source "$REPO_ROOT/scripts/lib/search.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/search-lib-test.XXXXXX")"
  printf '%s\n' alpha 'needle one' 'needle two' omega >"$TEST_ROOT/input.txt"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

without_rg() {
  local original_path="$PATH"
  local grep_path
  grep_path="$(command -v grep)"
  mkdir -p "$TEST_ROOT/bin"
  ln -sf "$grep_path" "$TEST_ROOT/bin/grep"
  PATH="$TEST_ROOT/bin"
  "$@"
  local status=$?
  PATH="$original_path"
  return "$status"
}

@test "search_fixed has matching rg and grep-fallback behavior" {
  command -v rg >/dev/null
  expected="$(search_fixed 'needle one' "$TEST_ROOT/input.txt")"

  run without_rg search_fixed 'needle one' "$TEST_ROOT/input.txt"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]

  run without_rg search_fixed 'missing text' "$TEST_ROOT/input.txt"
  [ "$status" -eq 1 ]
}

@test "search_regex has matching rg and grep-fallback behavior" {
  command -v rg >/dev/null
  expected="$(search_regex '^needle (one|two)$' "$TEST_ROOT/input.txt")"

  run without_rg search_regex '^needle (one|two)$' "$TEST_ROOT/input.txt"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]

  run without_rg search_regex '^missing$' "$TEST_ROOT/input.txt"
  [ "$status" -eq 1 ]
}
