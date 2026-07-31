#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PROVENANCE="$REPO_ROOT/scripts/workflows/lib/provider-provenance.py"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

@test "provider provenance normalizes OpenCode requested and observed models" {
  cat >"$TMP_DIR/metadata.json" <<'EOF'
{"provider":"opencode","model":"openrouter/example/model@preset/default","observed_model":"example/model"}
EOF

  run python3 "$PROVENANCE" normalize "$TMP_DIR/metadata.json"

  [ "$status" -eq 0 ]
  run jq -e '.version == 1 and .provider == "opencode" and .requested_model == "openrouter/example/model@preset/default" and .observed_model == "example/model"' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "provider provenance preserves explicit unknown observed model" {
  cat >"$TMP_DIR/metadata.json" <<'EOF'
{"provider":"gemini","model":"gemini-test","requested_model":"gemini-test","observed_model":"unknown"}
EOF

  run python3 "$PROVENANCE" normalize "$TMP_DIR/metadata.json"

  [ "$status" -eq 0 ]
  run jq -e '.requested_model == "gemini-test" and .observed_model == "unknown"' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "provider provenance rejects missing provider" {
  printf '%s\n' '{"model":"test"}' >"$TMP_DIR/metadata.json"

  run python3 "$PROVENANCE" normalize "$TMP_DIR/metadata.json"

  [ "$status" -eq 1 ]
  [[ "$output" == *"provider"* ]]
}

@test "daily evidence renderer includes requested and observed model" {
  cat >"$TMP_DIR/daily.json" <<'EOF'
{
  "run_date": "2026-07-31",
  "prs": [7],
  "findings": [],
  "pr_evidence_coverage": [{
    "pr": 7,
    "diff_included": 10,
    "diff_total": 10,
    "head_included": 5,
    "head_total": 5,
    "would_truncate": false,
    "evidence_route": "bounded",
    "routing_context": {
      "adaptive_enabled": true,
      "provider_resolved": "opencode",
      "cursor_available": false,
      "antigravity_available": false,
      "provenance": {
        "version": 1,
        "provider": "opencode",
        "requested_model": "openrouter/example/model@preset/default",
        "observed_model": "example/model"
      }
    }
  }]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py" "$TMP_DIR/daily.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"provider: opencode"* ]]
  [[ "$output" == *"requested: openrouter/example/model@preset/default"* ]]
  [[ "$output" == *"observed: example/model"* ]]
}

@test "weekly batch preserves automation-owned provenance and attempts" {
  cat >"$TMP_DIR/review.json" <<'EOF'
{
  "summary": "No findings.",
  "follow_up_issues": [],
  "provenance": {
    "version": 1,
    "provider": "cursor",
    "requested_model": "cursor-requested",
    "observed_model": "cursor-observed"
  },
  "provider_attempts": [
    {"provider":"opencode","status":"failed"},
    {"provider":"cursor","status":"success"}
  ]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/build-weekly-review-batch.py" \
    2026-W31 2026-07-31 "$TMP_DIR/review.json"

  [ "$status" -eq 0 ]
  run jq -e '.provenance.provider == "cursor" and .provenance.observed_model == "cursor-observed" and (.provider_attempts | length) == 2' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "weekly batch gives historical records explicit unknown provenance" {
  printf '%s\n' '{"summary":"legacy","follow_up_issues":[]}' >"$TMP_DIR/review.json"

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/build-weekly-review-batch.py" \
    2026-W31 2026-07-31 "$TMP_DIR/review.json"

  [ "$status" -eq 0 ]
  run jq -e '.provenance.provider == "unknown" and .provenance.requested_model == "unknown" and .provenance.observed_model == "unknown"' <<<"$output"
  [ "$status" -eq 0 ]
}
