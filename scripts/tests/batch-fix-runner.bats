#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/workflows/lib/run-batch-fix.sh
  source "$REPO_ROOT/scripts/workflows/lib/run-batch-fix.sh"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/batch-fix-runner-test.XXXXXX")"
  export CALL_LOG="$TEST_ROOT/calls.log"
  printf '%s\n' '{"findings":[{"category":"follow_up_issues","dedupe_key":"key-a","repro_steps":["step"]}]}' \
    >"$TEST_ROOT/batch.json"
  cat >"$TEST_ROOT/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'update %s\n' "$*" >>"$CALL_LOG"
EOF
  cat >"$TEST_ROOT/resolve.sh" <<'EOF'
#!/usr/bin/env bash
printf '42\n'
EOF
  cat >"$TEST_ROOT/link.sh" <<'EOF'
#!/usr/bin/env bash
printf 'link %s\n' "$*" >>"$CALL_LOG"
EOF
  chmod +x "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh"
  fix_phase_log() {
    printf 'phase %s\n' "$1" >>"$CALL_LOG"
  }
  render_body() {
    printf '%s\n' rendered >"$TEST_ROOT/body.md"
    printf 'render\n' >>"$CALL_LOG"
  }
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "batch fix writes cadence-neutral verification stubs" {
  run batch_fix_write_verify_stub \
    "$TEST_ROOT/verify.json" weekly run_week 2026-W24 "$TEST_ROOT/batch.json"

  [ "$status" -eq 0 ]
  run jq -e '.run_kind == "weekly" and .run_week == "2026-W24" and .findings[0].dedupe_key == "key-a"' \
    "$TEST_ROOT/verify.json"
  [ "$status" -eq 0 ]
}

@test "batch fix no-diff run without PR records skip and does not publish" {
  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh"

  [ "$status" -eq 0 ]
  run grep -F 'update 2026-W24 (skipped — no code changes; see fix-verify.json if present)' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -F render "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "batch fix no-diff rerun preserves existing PR body" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >>"$CALL_LOG"
if [[ "$1 $2" == "pr view" ]]; then
  printf '%s\n' 'https://example.test/pr/17'
fi
EOF
  chmod +x "$TEST_ROOT/bin/gh"
  PATH="$TEST_ROOT/bin:$PATH"

  run batch_fix_publish \
    owner/repo branch 17 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh"

  [ "$status" -eq 0 ]
  run grep -F 'gh pr edit' "$CALL_LOG"
  [ "$status" -eq 1 ]
  run grep -F 'link owner/repo 17 42' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'update 2026-W24 https://example.test/pr/17' "$CALL_LOG"
  [ "$status" -eq 0 ]
}

@test "batch fix commit includes untracked outputs" {
  mkdir -p "$TEST_ROOT/repo"
  git -C "$TEST_ROOT/repo" init -q
  git -C "$TEST_ROOT/repo" config user.email test@example.com
  git -C "$TEST_ROOT/repo" config user.name test
  printf '%s\n' base >"$TEST_ROOT/repo/tracked.txt"
  git -C "$TEST_ROOT/repo" add tracked.txt
  git -C "$TEST_ROOT/repo" commit -qm base
  printf '%s\n' generated >"$TEST_ROOT/repo/generated.txt"
  cd "$TEST_ROOT/repo"

  batch_fix_commit_changes 'test: include generated output'

  [ "$BATCH_FIX_HAS_DIFF" -eq 1 ]
  run git show --name-only --format= HEAD
  [ "$status" -eq 0 ]
  [[ "$output" == *"generated.txt"* ]]
}
