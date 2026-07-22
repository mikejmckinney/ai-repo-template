#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "advisory normalization owns provider model and no-findings output" {
  cat >"$TMP_DIR/input.md" <<'EOF'
<!-- ai-advisory-review:v1 -->

## Advisory Review Snapshot

Head: `model-authored-head`
Provider: `opencode`
Mode: advisory, non-blocking

### Findings to consider

| ID | Severity | Lens | Area | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|

### Not blocking

These findings are optional input while implementation continues.
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "1111111111111111111111111111111111111111" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis full \
    --diff-included 120 \
    --diff-total 120 \
    --truncated no \
    --changed-files 3

  [ "$status" -eq 0 ]
  grep -q '^Provider: `opencode / openai/gpt-5.6-sol`$' "$TMP_DIR/output.md"
  grep -q '^No findings identified at this head\.$' "$TMP_DIR/output.md"
  ! grep -q '^|---|---|---|---|---|---|---|$' "$TMP_DIR/output.md"
  grep -q 'ai-advisory-memory:v1' "$TMP_DIR/output.md"
  grep -q '"reviewed_head":"1111111111111111111111111111111111111111"' "$TMP_DIR/output.md"
}

@test "advisory normalization preserves actual findings" {
  cat >"$TMP_DIR/input.md" <<'EOF'
## Advisory Review Snapshot

### Findings to consider

| ID | Severity | Lens | Area | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|
| ADV-01 | high | Correctness | parser | It fails. | Fix it. | yes |

### Not blocking
EOF
  printf '%s\n' '{"provider":"antigravity","model":"agent:antigravity-preview-05-2026"}' >"$TMP_DIR/provider.json"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "2222222222222222222222222222222222222222" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis incremental \
    --diff-included 42 \
    --diff-total 42 \
    --truncated no \
    --changed-files 1

  [ "$status" -eq 0 ]
  grep -q '^Provider: `antigravity / agent:antigravity-preview-05-2026`$' "$TMP_DIR/output.md"
  grep -q '^| ADV-01 | high |' "$TMP_DIR/output.md"
  ! grep -q '^No findings identified' "$TMP_DIR/output.md"
}

@test "advisory memory selects an incremental range only for compatible state" {
  repo="$TMP_DIR/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -qm base
  base=$(git -C "$repo" rev-parse HEAD)
  printf 'first\n' >>"$repo/file.txt"
  git -C "$repo" commit -qam first
  reviewed=$(git -C "$repo" rev-parse HEAD)
  printf 'second\n' >>"$repo/file.txt"
  git -C "$repo" commit -qam second
  head=$(git -C "$repo" rev-parse HEAD)
  printf '<!-- ai-advisory-memory:v1 {"base_sha":"%s","reviewed_head":"%s","provider":"opencode","model":"openai/gpt-5.6-sol"} -->\n' \
    "$base" "$reviewed" >"$TMP_DIR/snapshot.md"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/select-advisory-range.py" \
    --repo "$repo" \
    --snapshot "$TMP_DIR/snapshot.md" \
    --base "$base" \
    --head "$head" \
    --expected-provider opencode \
    --event-action synchronize

  [ "$status" -eq 0 ]
  [ "$(jq -r .review_basis <<<"$output")" = incremental ]
  [ "$(jq -r .diff_base <<<"$output")" = "$reviewed" ]
}

@test "advisory memory forces full review at readiness and provider changes" {
  repo="$TMP_DIR/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -qm base
  base=$(git -C "$repo" rev-parse HEAD)
  printf 'head\n' >>"$repo/file.txt"
  git -C "$repo" commit -qam head
  head=$(git -C "$repo" rev-parse HEAD)
  printf '<!-- ai-advisory-memory:v1 {"base_sha":"%s","reviewed_head":"%s","provider":"cursor","model":"cursor-grok-4.5-medium"} -->\n' \
    "$base" "$base" >"$TMP_DIR/snapshot.md"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/select-advisory-range.py" \
    --repo "$repo" --snapshot "$TMP_DIR/snapshot.md" --base "$base" --head "$head" \
    --expected-provider opencode --event-action synchronize
  [ "$status" -eq 0 ]
  [ "$(jq -r .review_basis <<<"$output")" = full ]
  [ "$(jq -r .reason <<<"$output")" = provider-changed ]

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/select-advisory-range.py" \
    --repo "$repo" --snapshot "$TMP_DIR/snapshot.md" --base "$base" --head "$head" \
    --expected-provider cursor --event-action ready_for_review
  [ "$status" -eq 0 ]
  [ "$(jq -r .review_basis <<<"$output")" = full ]
  [ "$(jq -r .reason <<<"$output")" = ready-for-review ]
}
