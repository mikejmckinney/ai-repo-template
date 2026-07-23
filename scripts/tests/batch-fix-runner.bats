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
  cat >"$TEST_ROOT/verify.json" <<'EOF'
{
  "findings": [
    {
      "dedupe_key": "key-a",
      "verify": {
        "pre": "cant_reproduce",
        "post": "n/a",
        "notes": "Superseded on current main."
      }
    }
  ]
}
EOF
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

@test "batch fix no-diff run accepts complete cant-reproduce evidence" {
  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/verify.json"

  [ "$status" -eq 0 ]
  run grep -F 'update 2026-W24 (skipped — all actionable findings verified cant_reproduce)' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -F render "$CALL_LOG"
  [ "$status" -eq 1 ]
}

@test "batch fix no-diff run rejects pending verification" {
  jq '.findings[0].verify.pre = "pending"' "$TEST_ROOT/verify.json" >"$TEST_ROOT/pending.json"

  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/pending.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"key-a"* ]]
}

@test "batch fix no-diff run rejects missing finding verification" {
  printf '%s\n' '{"findings":[]}' >"$TEST_ROOT/missing.json"

  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/missing.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"key-a"* ]]
}

@test "batch fix no-diff run rejects fixed claim without patch" {
  jq '.findings[0].verify = {pre: "reproduced", post: "fixed", notes: "claimed fixed"}' \
    "$TEST_ROOT/verify.json" >"$TEST_ROOT/fixed.json"

  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/fixed.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"key-a"* ]]
}

@test "batch fix no-diff run rejects missing verification file" {
  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/not-found.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"not-found.json"* ]]
}

@test "batch fix workflow-only run fails with human-authored PR requirement" {
  BATCH_FIX_STRIPPED_WORKFLOWS=(.github/workflows/example.yml)

  run batch_fix_publish \
    owner/repo branch "" 0 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/verify.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *".github/workflows/example.yml"* ]]
  [[ "$output" == *"human-authored workflow PR required"* ]]
  [ ! -f "$CALL_LOG" ]
}

@test "batch fix mixed run publishes partial draft then fails for workflow follow-up" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >>"$CALL_LOG"
EOF
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >>"$CALL_LOG"
if [[ "$1 $2" == "pr create" ]]; then
  printf '%s\n' 'https://example.test/pr/18'
fi
EOF
  chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/gh"
  PATH="$TEST_ROOT/bin:$PATH"
  BATCH_FIX_STRIPPED_WORKFLOWS=(.github/workflows/example.yml)

  run batch_fix_publish \
    owner/repo branch "" 1 2026-W24 "$TEST_ROOT/batch.json" title "$TEST_ROOT/body.md" \
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/verify.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"human-authored workflow PR required"* ]]
  run grep -F 'gh pr create' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'update 2026-W24 https://example.test/pr/18' "$CALL_LOG"
  [ "$status" -eq 0 ]
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
    render_body "$TEST_ROOT/update.sh" "$TEST_ROOT/resolve.sh" "$TEST_ROOT/link.sh" \
    "$TEST_ROOT/verify.json"

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

@test "batch fix does not commit a verification-only diff" {
  mkdir -p "$TEST_ROOT/repo/retro"
  git -C "$TEST_ROOT/repo" init -q
  git -C "$TEST_ROOT/repo" config user.email test@example.com
  git -C "$TEST_ROOT/repo" config user.name test
  printf '%s\n' base >"$TEST_ROOT/repo/tracked.txt"
  git -C "$TEST_ROOT/repo" add tracked.txt
  git -C "$TEST_ROOT/repo" commit -qm base
  cp "$TEST_ROOT/verify.json" "$TEST_ROOT/repo/retro/fix-verify-test.json"
  cd "$TEST_ROOT/repo"

  batch_fix_commit_changes 'test: reject verification-only output' "" \
    "$TEST_ROOT/repo/retro/fix-verify-test.json"

  [ "$BATCH_FIX_HAS_DIFF" -eq 0 ]
  [ "$(git rev-list --count HEAD)" -eq 1 ]
  [ -f "$TEST_ROOT/repo/retro/fix-verify-test.json" ]
}

@test "native issue link helper retries keyword text until GitHub reports the relationship" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"$CALL_LOG"
if [[ "$1 $2" == "pr view" ]]; then
  printf '## Linked issues\n\nFixes #42\n'
elif [[ "$1 $2" == "api graphql" ]]; then
  [[ "$*" == *'closingIssuesReferences'* ]]
  [[ "$*" == *'-F owner=owner'* ]]
  [[ "$*" == *'-F name=repo'* ]]
  [[ "$*" == *'-F number=17'* ]]
  [[ "$*" == *'any(.number == 42)'* ]]
  count_file="${CALL_LOG}.graphql"
  count=0
  [[ -f "$count_file" ]] && count="$(cat "$count_file")"
  count=$((count + 1))
  printf '%s' "$count" >"$count_file"
  [[ "$count" -ge 2 ]] && printf 'true\n' || printf 'false\n'
fi
EOF
  chmod +x "$TEST_ROOT/bin/gh"

  run env PATH="$TEST_ROOT/bin:$PATH" CALL_LOG="$CALL_LOG" \
    LINK_VERIFY_ATTEMPTS=3 LINK_VERIFY_DELAY_SECONDS=0 \
    bash "$REPO_ROOT/scripts/workflows/lib/link-fix-pr-to-issue.sh" owner/repo 17 42

  [ "$status" -eq 0 ]
  [[ "$output" == *"native Development-graph link"* ]]
  run grep -F 'gh pr edit 17 -R owner/repo --body-file' "$CALL_LOG"
  [ "$status" -eq 0 ]
  run grep -F 'closingIssuesReferences' "$CALL_LOG"
  [ "$status" -eq 0 ]
  [ "$(cat "${CALL_LOG}.graphql")" -eq 2 ]
}

@test "native issue link helper fails when GitHub never reports the relationship" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr view" ]]; then
  printf '## Linked issues\n\nFixes #42\n'
elif [[ "$1 $2" == "api graphql" ]]; then
  printf 'false\n'
fi
EOF
  chmod +x "$TEST_ROOT/bin/gh"

  run env PATH="$TEST_ROOT/bin:$PATH" \
    LINK_VERIFY_ATTEMPTS=2 LINK_VERIFY_DELAY_SECONDS=0 \
    bash "$REPO_ROOT/scripts/workflows/lib/link-fix-pr-to-issue.sh" owner/repo 17 42

  [ "$status" -ne 0 ]
  [[ "$output" == *"GitHub did not register"* ]]
  [[ "$output" == *"owner/repo/pull/17"* ]]
}
