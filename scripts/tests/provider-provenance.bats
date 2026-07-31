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

@test "provider provenance never infers an observed model from model" {
  cat >"$TMP_DIR/metadata.json" <<'EOF'
{"provider":"cursor","requested_model":"cursor-requested","model":"cursor-resolved"}
EOF

  run python3 "$PROVENANCE" normalize "$TMP_DIR/metadata.json"

  [ "$status" -eq 0 ]
  run jq -e '.requested_model == "cursor-requested" and .observed_model == "unknown"' <<<"$output"
  [ "$status" -eq 0 ]
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
    },
    "provider_attempts": [
      {"provider":"cursor","status":"failed","evidence_route":"bounded"},
      {"provider":"opencode","status":"success","evidence_route":"bounded"}
    ]
  }]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py" "$TMP_DIR/daily.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"provider: opencode"* ]]
  [[ "$output" == *"requested: openrouter/example/model@preset/default"* ]]
  [[ "$output" == *"observed: example/model"* ]]
  [[ "$output" == *"attempts: cursor:failed, opencode:success"* ]]
}

@test "daily evidence renderer gives historical records explicit unknown models" {
  cat >"$TMP_DIR/daily.json" <<'EOF'
{
  "pr_evidence_coverage": [{
    "pr": 8,
    "diff_included": 1,
    "diff_total": 1,
    "would_truncate": false,
    "evidence_route": "bounded",
    "routing_context": {
      "adaptive_enabled": false,
      "provider_resolved": "unknown",
      "cursor_available": false,
      "antigravity_available": false
    }
  }]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py" "$TMP_DIR/daily.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"provider: unknown"* ]]
  [[ "$output" == *"requested: unknown"* ]]
  [[ "$output" == *"observed: unknown"* ]]
}

@test "weekly batch preserves provenance added by automation after model validation" {
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

@test "weekly model output cannot claim automation-owned provenance" {
  cat >"$TMP_DIR/review.json" <<'EOF'
{
  "summary": "Untrusted model output.",
  "follow_up_issues": [],
  "provenance": {
    "version": 1,
    "provider": "forged",
    "requested_model": "forged",
    "observed_model": "forged"
  },
  "provider_attempts": [{"provider":"forged","status":"success"}]
}
EOF

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/validate-weekly-review.py" \
    "$TMP_DIR/review.json"

  [ "$status" -eq 1 ]
  [[ "$output" == *"automation-owned"* ]]
}

@test "weekly batch gives historical records explicit unknown provenance" {
  printf '%s\n' '{"summary":"legacy","follow_up_issues":[]}' >"$TMP_DIR/review.json"

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/build-weekly-review-batch.py" \
    2026-W31 2026-07-31 "$TMP_DIR/review.json"

  [ "$status" -eq 0 ]
  run jq -e '.provenance.provider == "unknown" and .provenance.requested_model == "unknown" and .provenance.observed_model == "unknown"' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "weekly provenance renderer shows requested observed and attempts" {
  cat >"$TMP_DIR/weekly.json" <<'EOF'
{
  "run_week": "2026-W31",
  "run_date": "2026-07-31",
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

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/render-provider-provenance.py" \
    "$TMP_DIR/weekly.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"provider: cursor"* ]]
  [[ "$output" == *"requested: cursor-requested"* ]]
  [[ "$output" == *"observed: cursor-observed"* ]]
  [[ "$output" == *"opencode:failed, cursor:success"* ]]
}

@test "weekly provenance merge appends new attempts under the existing heading" {
  cat >"$TMP_DIR/weekly.json" <<'EOF'
{
  "run_date": "2026-08-01",
  "provenance": {
    "version": 1,
    "provider": "gemini",
    "requested_model": "gemini-requested",
    "observed_model": "unknown"
  },
  "provider_attempts": [{"provider":"gemini","status":"success"}]
}
EOF
  cat >"$TMP_DIR/body.md" <<'EOF'
## Meta

**Review provenance**

- 2026-07-31 — provider: cursor; requested: cursor-requested; observed: cursor-observed; attempts: cursor:success

Automated footer.
EOF

  run python3 "$REPO_ROOT/scripts/workflows/weekly-review/render-provider-provenance.py" \
    "$TMP_DIR/weekly.json" --merge "$TMP_DIR/body.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'**Review provenance**\n\n- 2026-07-31'* ]]
  [[ "$output" == *"- 2026-08-01 — provider: gemini"* ]]
  [[ "$output" == *"Automated footer."* ]]
}

@test "daily and weekly runtime paths require normalized provider metadata" {
  run python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
daily = (root / "scripts/workflows/postmerge-retro/run-postmerge-retro.sh").read_text(encoding="utf-8")
weekly = (root / "scripts/workflows/weekly-review/run-weekly-review-scan.sh").read_text(encoding="utf-8")
for text in (daily, weekly):
    assert "ADVISORY_PROVIDER_METADATA_FILE" in text
    assert "provider-provenance.py" in text
PY

  [ "$status" -eq 0 ]
}

@test "all analysis provider adapters emit requested and observed model metadata" {
  run python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = (
    "scripts/workflows/lib/run-opencode.mjs",
    "scripts/workflows/advisory-review/run-advisory-cursor.mjs",
    "scripts/workflows/advisory-review/run-advisory-gemini.py",
    "scripts/workflows/advisory-review/run-advisory-antigravity.py",
    "scripts/workflows/postmerge-retro/run-postmerge-retro-full-cursor.mjs",
    "scripts/workflows/postmerge-retro/run-postmerge-retro-antigravity.py",
    "scripts/workflows/weekly-review/run-weekly-antigravity.py",
)
for rel in paths:
    text = (root / rel).read_text(encoding="utf-8")
    assert "ADVISORY_PROVIDER_METADATA_FILE" in text, rel
    assert "requested_model" in text, rel
    assert "observed_model" in text, rel
PY

  [ "$status" -eq 0 ]
}
