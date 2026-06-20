#!/usr/bin/env bats
# scripts/tests/repro-steps-validation.bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  cd "$REPO_ROOT"
}

@test "validate-postmerge-retro.py rejects follow_up without repro_steps" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'JSON'
{
  "pr": 1,
  "summary": "x",
  "follow_up_issues": [
    {
      "title": "t",
      "body": "b",
      "dedupe_key": "k"
    }
  ],
  "adr_updates": [],
  "context_pack_updates": []
}
JSON
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
  [[ "$status" -ne 0 ]]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro.py accepts follow_up with repro_steps" {
  tmp="$(mktemp -d)"
  cp scripts/tests/fixtures/postmerge-retro/sample-retro.json "$tmp/retro.json"
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
  [[ "$status" -eq 0 ]]
  run jq -e '.follow_up_issues[0].priority_band == "should-fix"' "$tmp/retro.json"
  [[ "$status" -eq 0 ]]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro-daily.py requires repro_steps on follow_up_issues" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'JSON'
{
  "run_date": "2026-06-15",
  "prs": [1],
  "findings": [
    {
      "pr": 1,
      "category": "follow_up_issues",
      "title": "t",
      "body": "b",
      "dedupe_key": "k",
      "impact": "meta-harness",
      "trigger_likelihood": "edge",
      "fix_cost": "trivial"
    }
  ]
}
JSON
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py "$tmp/daily.json"
  [[ "$status" -ne 0 ]]
  rm -rf "$tmp"
}

@test "render-fix-pr-sections.py renders verify table" {
  tmp="$(mktemp -d)"
  cat >"$tmp/fix-verify.json" <<'JSON'
{
  "run_date": "2026-06-15",
  "findings": [
    {
      "dedupe_key": "k1",
      "verify": {"pre": "reproduced", "post": "fixed", "sandbox": "n/a", "notes": ""}
    }
  ],
  "sandbox": {"issue_url": "n/a", "pr_url": "n/a", "skip_reason": "local only"}
}
JSON
  run python3 scripts/workflows/lib/render-fix-pr-sections.py "$tmp/fix-verify.json"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"## Fix verification"* ]]
  [[ "$output" == *"k1"* ]]
  rm -rf "$tmp"
}
