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
{"findings": []}
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
  [ "$(sed -n '1p' "$TMP_DIR/output.md")" = '<!-- ai-advisory-review:v1 -->' ]
}

@test "advisory normalization rejects model-authored severity findings" {
  cat >"$TMP_DIR/input.md" <<'EOF'
{"findings":[{
  "id":"ADV-01","lens":"Correctness","area":"parser",
  "finding":"It fails.","suggested_action":"Fix it.","still_present_at_head":true,
  "triage_version":2,"impact":"incorrect-behavior","impact_magnitude":"material",
  "trigger_likelihood":"common","affected_scope":"broad","reversibility":"hard",
  "fix_cost":"moderate","confidence":"high","uncertainty":"none","severity":"high"
}]}
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

  [ "$status" -ne 0 ]
  [[ "$output" == *"severity is deprecated"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
}

@test "advisory normalization rejects null deprecated fields by presence" {
  cat >"$TMP_DIR/base.json" <<'EOF'
{"findings":[{
  "id":"ADV-01","lens":"Correctness","area":"parser",
  "finding":"It fails.","suggested_action":"Fix it.","still_present_at_head":true,
  "triage_version":2,"impact":"incorrect-behavior","impact_magnitude":"material",
  "trigger_likelihood":"common","affected_scope":"broad","reversibility":"hard",
  "fix_cost":"moderate","confidence":"high","uncertainty":"none"
}]}
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

  for field in severity priority_band; do
    jq --arg field "$field" '.findings[0][$field] = null' \
      "$TMP_DIR/base.json" >"$TMP_DIR/input.md"
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

    [ "$status" -ne 0 ]
    [[ "$output" == *"$field"* ]]
    [ ! -e "$TMP_DIR/output.md" ]
  done
}

@test "advisory normalization rejects model-authored band tables" {
  cat >"$TMP_DIR/input.md" <<'EOF'
## Advisory Review Snapshot

### Findings to consider

| ID | Band | Lens | Area | AP11 evidence | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|---|
| ADV-01 | fix-now | Correctness | parser | material/common/broad/hard/moderate/high; uncertainty: none | It fails. | Fix it. | yes |

### Not blocking

These findings are optional input while implementation continues. CI and maintainer decisions remain authoritative.
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

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

  [ "$status" -ne 0 ]
  [[ "$output" == *"structured advisory output must be valid JSON"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
}

@test "advisory normalization classifies structured AP11 findings" {
  cat >"$TMP_DIR/input.md" <<'EOF'
{
  "findings": [
    {
      "id": "ADV-01",
      "lens": "Correctness",
      "area": "parser",
      "finding": "Normal input produces the wrong result.",
      "suggested_action": "Correct the parser and add a regression test.",
      "still_present_at_head": true,
      "triage_version": 2,
      "impact": "incorrect-behavior",
      "impact_magnitude": "material",
      "trigger_likelihood": "common",
      "affected_scope": "broad",
      "reversibility": "hard",
      "fix_cost": "moderate",
      "confidence": "high",
      "uncertainty": "none",
      "regression_guard": false
    }
  ]
}
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

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
  grep -q '^| ADV-01 | fix-now |' "$TMP_DIR/output.md"
  grep -q 'material/common/broad/hard/moderate/high' "$TMP_DIR/output.md"
  ! grep -q 'Severity' "$TMP_DIR/output.md"
}

@test "advisory normalization rejects malformed non-empty findings" {
  cat >"$TMP_DIR/input.md" <<'EOF'
## Advisory Review Snapshot

### Findings to consider

There may be a correctness problem, but I did not use the required table.

### Not blocking
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "3333333333333333333333333333333333333333" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis full \
    --diff-included 10 \
    --diff-total 10 \
    --truncated no \
    --changed-files 1

  [ "$status" -ne 0 ]
  [[ "$output" == *"structured advisory output must be valid JSON"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
}

@test "advisory normalization rejects substantive preamble" {
  cat >"$TMP_DIR/input.md" <<'EOF'
Model-authored analysis must trigger provider fallback.

<!-- ai-advisory-review:v1 -->

## Advisory Review Snapshot

### Findings to consider

No findings identified at this head.

### Not blocking
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "3333333333333333333333333333333333333333" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis full \
    --diff-included 10 \
    --diff-total 10 \
    --truncated no \
    --changed-files 1

  [ "$status" -ne 0 ]
  [[ "$output" == *"structured advisory output must be valid JSON"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
}

@test "advisory normalization rejects invalid finding fields" {
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"
  cat >"$TMP_DIR/valid.json" <<'EOF'
{"findings":[{
  "id":"ADV-01","lens":"Correctness","area":"parser",
  "finding":"It fails.","suggested_action":"Fix it.","still_present_at_head":true,
  "triage_version":2,"impact":"incorrect-behavior","impact_magnitude":"material",
  "trigger_likelihood":"common","affected_scope":"broad","reversibility":"hard",
  "fix_cost":"moderate","confidence":"high","uncertainty":"none"
}]}
EOF
  invalid_filters=(
    '.findings[0].id = "invalid"'
    '.findings[0].lens = "Style"'
    '.findings[0].still_present_at_head = "maybe"'
  )

  for filter in "${invalid_filters[@]}"; do
    jq "$filter" "$TMP_DIR/valid.json" >"$TMP_DIR/input.md"
    rm -f "$TMP_DIR/output.md"
    run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
      --input "$TMP_DIR/input.md" \
      --output "$TMP_DIR/output.md" \
      --provider-metadata "$TMP_DIR/provider.json" \
      --head "3333333333333333333333333333333333333333" \
      --base "0000000000000000000000000000000000000000" \
      --review-basis full \
      --diff-included 10 \
      --diff-total 10 \
      --truncated no \
      --changed-files 1

    [ "$status" -ne 0 ]
    [[ "$output" == *"findings[0]"* ]]
    [ ! -e "$TMP_DIR/output.md" ]
  done
}

@test "advisory normalization rejects structured output without a findings array" {
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"
  printf '%s\n' '{"summary":"no findings"}' >"$TMP_DIR/input.md"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "3333333333333333333333333333333333333333" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis full \
    --diff-included 10 \
    --diff-total 10 \
    --truncated no \
    --changed-files 1

  [ "$status" -ne 0 ]
  [[ "$output" == *"requires a findings array"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
}

@test "advisory runner falls back after malformed provider output" {
  base=$(git -C "$REPO_ROOT" rev-parse HEAD^)
  head=$(git -C "$REPO_ROOT" rev-parse HEAD)
  mkdir -p "$TMP_DIR/bin"
  cat >"$TMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "api repos/example/repo/pulls/506" ]]; then
  jq -n --arg base "$ADVISORY_TEST_BASE" '{title:"test",body:"test",html_url:"https://example.test/pr/506",base:{sha:$base}}'
elif [[ "$1 $2" == "api repos/example/repo/issues/506/comments" ]]; then
  printf '[]\n'
else
  printf 'unexpected gh call: %s\n' "$*" >&2
  exit 1
fi
EOF
  chmod +x "$TMP_DIR/bin/gh"
  cat >"$TMP_DIR/providers.sh" <<'EOF'
init_advisory_provider_credentials() { :; }
list_advisory_providers() { printf '%s\n' first second; }
EOF
  cat >"$TMP_DIR/invoke.sh" <<'EOF'
invoke_advisory_llm() {
  local output_file="$2" provider="$3"
  printf '%s\n' "$provider" >>"$ADVISORY_TEST_ATTEMPTS"
  printf '{"provider":"%s","model":"test-model"}\n' "$provider" >"$ADVISORY_PROVIDER_METADATA_FILE"
  if [[ "$provider" == first ]]; then
    printf 'malformed output\n' >"$output_file"
  else
    printf '%s\n' '{"findings":[]}' >"$output_file"
  fi
}
EOF
  cat >"$TMP_DIR/upsert.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cp "$3" "$ADVISORY_TEST_POSTED"
EOF
  chmod +x "$TMP_DIR/upsert.sh"

  run env \
    PATH="$TMP_DIR/bin:$PATH" \
    GITHUB_REPOSITORY=example/repo \
    GITHUB_EVENT_ACTION=synchronize \
    ADVISORY_TEST_BASE="$base" \
    ADVISORY_TEST_ATTEMPTS="$TMP_DIR/attempts" \
    ADVISORY_TEST_POSTED="$TMP_DIR/posted.md" \
    ADVISORY_PROVIDER_LIB="$TMP_DIR/providers.sh" \
    ADVISORY_INVOKE_LIB="$TMP_DIR/invoke.sh" \
    ADVISORY_UPSERT_SCRIPT="$TMP_DIR/upsert.sh" \
    bash "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh" 506 "$head" false

  [ "$status" -eq 0 ]
  [ "$(tr '\n' ' ' <"$TMP_DIR/attempts")" = "first second " ]
  grep -q '^Provider: `second / test-model`$' "$TMP_DIR/posted.md"
  grep -q '^No findings identified at this head\.$' "$TMP_DIR/posted.md"
}

@test "advisory runner fails when every provider output is malformed" {
  base=$(git -C "$REPO_ROOT" rev-parse HEAD^)
  head=$(git -C "$REPO_ROOT" rev-parse HEAD)
  mkdir -p "$TMP_DIR/bin"
  cat >"$TMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "api repos/example/repo/pulls/506" ]]; then
  jq -n --arg base "$ADVISORY_TEST_BASE" '{title:"test",body:"test",html_url:"https://example.test/pr/506",base:{sha:$base}}'
elif [[ "$1 $2" == "api repos/example/repo/issues/506/comments" ]]; then
  printf '[]\n'
else
  exit 1
fi
EOF
  chmod +x "$TMP_DIR/bin/gh"
  cat >"$TMP_DIR/providers.sh" <<'EOF'
init_advisory_provider_credentials() { :; }
list_advisory_providers() { printf '%s\n' first second; }
EOF
  cat >"$TMP_DIR/invoke.sh" <<'EOF'
invoke_advisory_llm() {
  local output_file="$2" provider="$3"
  printf '%s\n' "$provider" >>"$ADVISORY_TEST_ATTEMPTS"
  printf '{"provider":"%s","model":"test-model"}\n' "$provider" >"$ADVISORY_PROVIDER_METADATA_FILE"
  printf 'malformed output\n' >"$output_file"
}
EOF

  run env \
    PATH="$TMP_DIR/bin:$PATH" \
    GITHUB_REPOSITORY=example/repo \
    GITHUB_EVENT_ACTION=synchronize \
    ADVISORY_TEST_BASE="$base" \
    ADVISORY_TEST_ATTEMPTS="$TMP_DIR/attempts" \
    ADVISORY_PROVIDER_LIB="$TMP_DIR/providers.sh" \
    ADVISORY_INVOKE_LIB="$TMP_DIR/invoke.sh" \
    bash "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh" 506 "$head" false

  [ "$status" -ne 0 ]
  [[ "$output" == *"Advisory provider cascade exhausted"* ]]
  [ "$(tr '\n' ' ' <"$TMP_DIR/attempts")" = "first second " ]
}

@test "oversized advisory output drops memory and preserves a canonical warning" {
  base=$(git -C "$REPO_ROOT" rev-parse HEAD^)
  head=$(git -C "$REPO_ROOT" rev-parse HEAD)
  mkdir -p "$TMP_DIR/bin"
  cat >"$TMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "api repos/example/repo/pulls/506" ]]; then
  jq -n --arg base "$ADVISORY_TEST_BASE" '{title:"test",body:"test",html_url:"https://example.test/pr/506",base:{sha:$base}}'
elif [[ "$1 $2" == "api repos/example/repo/issues/506/comments" ]]; then
  printf '[]\n'
else
  exit 1
fi
EOF
  chmod +x "$TMP_DIR/bin/gh"
  cat >"$TMP_DIR/providers.sh" <<'EOF'
init_advisory_provider_credentials() { :; }
list_advisory_providers() { printf '%s\n' opencode; }
EOF
  cat >"$TMP_DIR/invoke.sh" <<'EOF'
invoke_advisory_llm() {
  local output_file="$2" long_finding
  printf '%s\n' '{"provider":"opencode","model":"test-model"}' >"$ADVISORY_PROVIDER_METADATA_FILE"
  long_finding=$(printf 'x%.0s' {1..2000})
  jq -n --arg finding "$long_finding" '{findings:[{
    id:"ADV-01", lens:"Correctness", area:"parser", finding:$finding,
    suggested_action:"Fix it.", still_present_at_head:true,
    triage_version:2, impact:"incorrect-behavior", impact_magnitude:"material",
    trigger_likelihood:"common", affected_scope:"broad", reversibility:"hard",
    fix_cost:"moderate", confidence:"high", uncertainty:"none", regression_guard:false
  }]}' >"$output_file"
}
EOF
  cat >"$TMP_DIR/upsert.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cp "$3" "$ADVISORY_TEST_POSTED"
EOF
  chmod +x "$TMP_DIR/upsert.sh"

  run env \
    PATH="$TMP_DIR/bin:$PATH" \
    GITHUB_REPOSITORY=example/repo \
    GITHUB_EVENT_ACTION=synchronize \
    ADVISORY_REVIEW_COMMENT_LIMIT=1000 \
    ADVISORY_TEST_BASE="$base" \
    ADVISORY_TEST_POSTED="$TMP_DIR/posted.md" \
    ADVISORY_PROVIDER_LIB="$TMP_DIR/providers.sh" \
    ADVISORY_INVOKE_LIB="$TMP_DIR/invoke.sh" \
    ADVISORY_UPSERT_SCRIPT="$TMP_DIR/upsert.sh" \
    bash "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh" 506 "$head" false

  [ "$status" -eq 0 ]
  ! grep -q 'ai-advisory-memory:v1' "$TMP_DIR/posted.md"
  grep -q '^| ADV-01 | defer | Reliability and performance | Advisory output |' "$TMP_DIR/posted.md"
  grep -q 'exceeded the 1000-byte comment limit' "$TMP_DIR/posted.md"
  [ "$(wc -c <"$TMP_DIR/posted.md" | tr -d ' ')" -le 1000 ]

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/select-advisory-range.py" \
    --repo "$REPO_ROOT" \
    --snapshot "$TMP_DIR/posted.md" \
    --base "$base" \
    --head "$head" \
    --expected-provider opencode \
    --event-action synchronize
  [ "$status" -eq 0 ]
  [ "$(jq -r .review_basis <<<"$output")" = full ]
  [ "$(jq -r .reason <<<"$output")" = no-memory ]
}

@test "advisory normalization rejects the legacy sample row" {
  cat >"$TMP_DIR/input.md" <<'EOF'
## Advisory Review Snapshot

### Findings to consider

| ID | Severity | Lens | Area | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|
| ADV-01 | … | … | … | … | … | yes/no |

### Not blocking

These findings are optional input while implementation continues. CI and maintainer decisions remain authoritative.
EOF
  printf '%s\n' '{"provider":"opencode","model":"openai/gpt-5.6-sol"}' >"$TMP_DIR/provider.json"

  run python3 "$REPO_ROOT/scripts/workflows/advisory-review/normalize-advisory-snapshot.py" \
    --input "$TMP_DIR/input.md" \
    --output "$TMP_DIR/output.md" \
    --provider-metadata "$TMP_DIR/provider.json" \
    --head "4444444444444444444444444444444444444444" \
    --base "0000000000000000000000000000000000000000" \
    --review-basis full \
    --diff-included 10 \
    --diff-total 10 \
    --truncated no \
    --changed-files 1

  [ "$status" -ne 0 ]
  [[ "$output" == *"structured advisory output must be valid JSON"* ]]
  [ ! -e "$TMP_DIR/output.md" ]
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
