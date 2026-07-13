#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-120}"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/multi-dispatch.XXXXXX")"
  export REPO_ROOT FIXTURE_DIR MULTI_DISPATCH_TEST_MODE=1
  # shellcheck disable=SC1091
  source "$REPO_ROOT/scripts/multi-dispatch-safety.sh"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

make_issue() {
  local n="$1" body="$2" comments="${3:-}" state="${4:-open}"
  printf '%s' "$body" >"$FIXTURE_DIR/$n.body"
  printf '%s' "$comments" >"$FIXTURE_DIR/$n.comments"
  printf '%s' "$state" >"$FIXTURE_DIR/$n.state"
}

@test "extract_depends_on parses and deduplicates issue numbers" {
  make_issue 100 $'Depends-on: #51\nDepends-on: #50\nDepends-on: #51\n'
  run extract_depends_on 100
  [ "$status" -eq 0 ]
  [ "$output" = $'50\n51' ]
}

@test "extract_scope reads an explicit file list" {
  make_issue 200 "body" $'===COMMENT===\n<!-- architect-plan-files -->\n```\nsrc/api/users.py\nsrc/api/auth.py\n```\n'
  run extract_scope 200
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODE: explicit"* ]]
  [[ "$output" == *"src/api/users.py"* ]]
}

@test "extract_scope does not infer scope from role labels" {
  make_issue 201 "body"
  printf 'role:backend\n' >"$FIXTURE_DIR/201.labels"
  run extract_scope 201
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODE: none"* ]]
}

@test "classify_overlap distinguishes exact and directory overlap" {
  a="$FIXTURE_DIR/a"
  b="$FIXTURE_DIR/b"
  printf 'src/api/a.py\n' >"$a"
  printf 'src/api/a.py\n' >"$b"
  run classify_overlap "$a" "$b"
  [ "$output" = "hard" ]

  printf 'src/api/b.py\n' >"$b"
  run classify_overlap "$a" "$b"
  [ "$output" = "soft" ]

  printf 'src/worker/b.py\n' >"$b"
  run classify_overlap "$a" "$b"
  [ "$output" = "none" ]
}

@test "select_dispatchable refuses an exact overlap" {
  scope=$'===COMMENT===\n<!-- architect-plan-files -->\n```\nsrc/api/users.py\n```\n'
  make_issue 300 "first" "$scope"
  make_issue 301 "second" "$scope"
  run select_dispatchable 300 301
  [ "$status" -eq 0 ]
  [[ "$output" == *$'300\tdispatch'* ]]
  [[ "$output" == *$'301\trefuse\thard overlap with already-dispatched #300'* ]]
}
