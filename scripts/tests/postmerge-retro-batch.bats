#!/usr/bin/env bats
# Post-merge retro batch improvements (#446) unit tests.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  cd "$REPO_ROOT"
}

@test "extract-suggested-fix.py reads ## Suggested fix section" {
  tmp="$(mktemp -d)"
  cat >"$tmp/body.md" <<'EOF'
## Problem
Something broke.

## Suggested fix
Emit a warning when falling back to empty JSON.
EOF
  run python3 scripts/workflows/postmerge-retro/extract-suggested-fix.py "$tmp/body.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning"* ]]
  rm -rf "$tmp"
}

@test "mark-superseded-findings.py flags missing-file finding when path exists" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts/workflows/lib"
  echo "present" >"$tmp/scripts/workflows/lib/prompt_helpers.py"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-19",
  "findings": [
    {
      "pr": 1,
      "category": "follow_up_issues",
      "title": "Missing helper",
      "body": "## Problem\nscripts/workflows/lib/prompt_helpers.py is missing from the repo.",
      "dedupe_key": "test-missing-helper",
      "repro_steps": ["Look for scripts/workflows/lib/prompt_helpers.py"],
      "evidence": []
    }
  ],
  "pr_changed_files": [
    {"pr": 1, "paths": ["scripts/workflows/lib/prompt_helpers.py"]}
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/mark-superseded-findings.py \
    "$tmp/daily.json" --repo-root "$tmp" -o "$tmp/out.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].superseded_on_main == true' "$tmp/out.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "reconstruct-daily-retro-from-umbrella parses Suggested fix column" {
  tmp="$(mktemp -d)"
  cat >"$tmp/body.md" <<'EOF'
<!-- postmerge-retro:daily:2026-06-19 -->
| PR | Category | Dedupe key | Severity | Finding | Suggested fix |
|---|---|---|---|---|---|
| #1 | follow_up_issues | `key-a` | medium | Title one | Add tests |
EOF
  run python3 scripts/workflows/postmerge-retro/reconstruct-daily-retro-from-umbrella.py \
    --body-file "$tmp/body.md" -o "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].body | contains("Suggested fix")' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}
