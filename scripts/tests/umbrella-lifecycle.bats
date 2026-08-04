#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/workflows/lib/umbrella-lifecycle.sh
  source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/umbrella-lifecycle-test.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "umbrella resolver honors JSON then sidecar references" {
  printf '%s\n' '{"umbrella_issue":42}' >"$TEST_ROOT/batch.json"

  run umbrella_resolve_issue key "$TEST_ROOT/batch.json" "$TEST_ROOT/missing-finder.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 42 ]

  printf '%s\n' '{}' >"$TEST_ROOT/batch.json"
  printf '%s\n' 43 >"$TEST_ROOT/umbrella-issue.txt"
  run umbrella_resolve_issue key "$TEST_ROOT/batch.json" "$TEST_ROOT/missing-finder.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 43 ]
}

@test "umbrella resolver rejects an invalid explicit reference" {
  UMBRELLA_ISSUE_NUM=not-a-number

  run umbrella_resolve_issue key "" "$TEST_ROOT/missing-finder.sh"

  [ "$status" -eq 1 ]
}

@test "umbrella reference writer updates JSON and sidecar" {
  printf '%s\n' '{"run_week":"2026-W24"}' >"$TEST_ROOT/batch.json"

  run umbrella_write_issue_ref "$TEST_ROOT/batch.json" ' 51 ' true

  [ "$status" -eq 0 ]
  run jq -e '.umbrella_issue == 51' "$TEST_ROOT/batch.json"
  [ "$status" -eq 0 ]
  [ "$(<"$TEST_ROOT/umbrella-issue.txt")" = 51 ]
}

@test "umbrella fix-link updater replaces the pending marker" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "issue view" ]]; then
  printf '%s\n' '<!-- weekly-review:2026-W24 -->' 'Draft fix PR (if created): (pending — fix job)'
elif [[ "$1 $2" == "issue edit" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == --body-file ]]; then
      cp "$2" "$GH_EDITED_BODY"
      exit 0
    fi
    shift
  done
fi
EOF
  chmod +x "$TEST_ROOT/bin/gh"
  export GH_EDITED_BODY="$TEST_ROOT/edited.md"
  PATH="$TEST_ROOT/bin:$PATH"

  run umbrella_update_fix_link \
    owner/repo 51 '<!-- weekly-review:2026-W24 -->' 'https://example.test/pr/1'

  [ "$status" -eq 0 ]
  run grep -F 'Draft fix PR (if created): https://example.test/pr/1' "$GH_EDITED_BODY"
  [ "$status" -eq 0 ]
}
