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
| PR | Category | Key | Impact | Trigger | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|
| #1 | follow_up_issues | `key-a` | incorrect-behavior | edge | should-fix | Title one | Add tests |
EOF
  run python3 scripts/workflows/postmerge-retro/reconstruct-daily-retro-from-umbrella.py \
    --body-file "$tmp/body.md" -o "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].body | contains("Suggested fix")' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].impact == "incorrect-behavior"' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].priority_band == "should-fix"' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "classify-finding-priority derives fix-now for incorrect-behavior + common" {
  run python3 scripts/workflows/postmerge-retro/classify-finding-priority.py \
    --impact incorrect-behavior --trigger common --fix-cost moderate
  [ "$status" -eq 0 ]
  [ "$output" = "fix-now" ]
}

@test "classify-finding-priority derives should-fix for incorrect-behavior + edge" {
  run python3 scripts/workflows/postmerge-retro/classify-finding-priority.py \
    --impact incorrect-behavior --trigger edge --fix-cost trivial
  [ "$status" -eq 0 ]
  [ "$output" = "should-fix" ]
}

@test "classify-finding-priority derives should-fix for trivial regression guard" {
  run python3 scripts/workflows/postmerge-retro/classify-finding-priority.py \
    --impact incorrect-behavior --trigger edge --fix-cost trivial --guard true
  [ "$status" -eq 0 ]
  [ "$output" = "should-fix" ]
}

@test "classify-finding-priority derives defer for meta-harness fringe guard" {
  run python3 scripts/workflows/postmerge-retro/classify-finding-priority.py \
    --impact meta-harness --trigger fringe --fix-cost trivial --guard true
  [ "$status" -eq 0 ]
  [ "$output" = "defer" ]
}

@test "classify-finding-priority derives defer for dx-perf-doc fringe" {
  run python3 scripts/workflows/postmerge-retro/classify-finding-priority.py \
    --impact dx-perf-doc --trigger fringe --fix-cost trivial
  [ "$status" -eq 0 ]
  [ "$output" = "defer" ]
}

@test "validate-postmerge-retro rejects deprecated severity" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'EOF'
{
  "pr": 1,
  "summary": "test",
  "follow_up_issues": [
    {
      "title": "t",
      "body": "b",
      "dedupe_key": "k",
      "severity": "low",
      "repro_steps": ["step"],
      "impact": "meta-harness",
      "trigger_likelihood": "edge",
      "fix_cost": "trivial"
    }
  ],
  "adr_updates": [],
  "context_pack_updates": []
}
EOF
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"severity is deprecated"* ]]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro rejects LLM-emitted priority_band" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'EOF'
{
  "pr": 1,
  "summary": "test",
  "follow_up_issues": [
    {
      "title": "t",
      "body": "b",
      "dedupe_key": "k",
      "priority_band": "defer",
      "repro_steps": ["step"],
      "impact": "meta-harness",
      "trigger_likelihood": "edge",
      "fix_cost": "trivial"
    }
  ],
  "adr_updates": [],
  "context_pack_updates": []
}
EOF
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"priority_band is derived"* ]]
  rm -rf "$tmp"
}

@test "merge-daily-retro-json propagates triage on adr_updates" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'EOF'
{
  "pr": 99,
  "summary": "adr triage fixture",
  "follow_up_issues": [],
  "adr_updates": [
    {
      "adr": "docs/decisions/adr-019-per-role-model-tiering.md",
      "title": "Clarify model tier table",
      "body": "ADR table is ambiguous.",
      "dedupe_key": "adr-tier-clarity",
      "impact": "dx-perf-doc",
      "trigger_likelihood": "fringe",
      "fix_cost": "moderate"
    }
  ],
  "context_pack_updates": []
}
EOF
  run python3 scripts/workflows/postmerge-retro/merge-daily-retro-json.py 2026-06-20 "$tmp/retro.json"
  [ "$status" -eq 0 ]
  merged="$output"
  run jq -e '.findings[0].category == "adr_updates"' <<<"$merged"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].priority_band == "defer"' <<<"$merged"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "mark-superseded-findings.py does not supersede on path substring false positive" {
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
      "title": "Missing backup helper",
      "body": "## Problem\nscripts/workflows/lib/prompt_helpers.py.bak is missing from the repo.",
      "dedupe_key": "test-substring-fp",
      "repro_steps": ["Look for scripts/workflows/lib/prompt_helpers.py.bak"],
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
  run jq -e '.findings[0].superseded_on_main != true' "$tmp/out.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "mark-superseded-findings.py flags missing-directory finding when dir exists" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts/workflows/lib"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-19",
  "findings": [
    {
      "pr": 1,
      "category": "follow_up_issues",
      "title": "Missing lib dir",
      "body": "## Problem\nscripts/workflows/lib is absent from the repo.",
      "dedupe_key": "test-missing-dir",
      "repro_steps": ["Check scripts/workflows/lib"],
      "evidence": []
    }
  ],
  "pr_changed_files": [
    {"pr": 1, "paths": ["scripts/workflows/lib"]}
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/mark-superseded-findings.py \
    "$tmp/daily.json" --repo-root "$tmp" -o "$tmp/out.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].superseded_on_main == true' "$tmp/out.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].superseded_reason | contains("directory")' "$tmp/out.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "parse-daily-json-snapshot.py rejects truncated snapshot bodies" {
  tmp="$(mktemp -d)"
  cat >"$tmp/snapshot.md" <<'EOF'
<!-- postmerge-retro:daily-json:2026-06-19 run:1 attempt:1 -->
```json
{"run_date": "2026-06-19"
/* TRUNCATED — retrieve full JSON from the Actions workflow artifact */
```
<!-- postmerge-retro:daily-json:truncated -->
EOF
  run --separate-stderr python3 scripts/workflows/postmerge-retro/parse-daily-json-snapshot.py "$tmp/snapshot.md"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"truncated"* ]]
  rm -rf "$tmp"
}

@test "parse-daily-json-snapshot.py accepts valid snapshot JSON" {
  tmp="$(mktemp -d)"
  cat >"$tmp/snapshot.md" <<'EOF'
<!-- postmerge-retro:daily-json:2026-06-19 run:1 attempt:1 -->
```json
{"run_date": "2026-06-19", "findings": []}
```
EOF
  run python3 scripts/workflows/postmerge-retro/parse-daily-json-snapshot.py "$tmp/snapshot.md"
  [ "$status" -eq 0 ]
  run jq -e '.run_date == "2026-06-19"' <<<"$output"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "daily-retro-select-prs.sh falls back to merge_commit_sha when mergeCommit empty" {
  tmp="$(mktemp -d)"
  stub_bin="$tmp/bin"
  mkdir -p "$stub_bin"
  cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "search" && "$2" == "issues" ]]; then
  echo '[{"body": "<!-- postmerge-retro:merge:abc123def456 pr:90 -->"}]'
  exit 0
fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  json_field=""
  jq_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) shift; json_field="$1" ;;
      --jq) shift; jq_filter="$1" ;;
    esac
    shift
  done
  if [[ "$json_field" == "mergeCommit" && "$jq_filter" == *"mergeCommit.oid"* ]]; then
    exit 0
  fi
  if [[ "$json_field" == "merge_commit_sha" && "$jq_filter" == *"merge_commit_sha"* ]]; then
    echo "abc123def456"
    exit 0
  fi
fi
if [[ "$1" == "repo" && "$2" == "view" ]]; then
  echo '{"nameWithOwner": "org/repo"}'
  exit 0
fi
exit 0
EOF
  chmod +x "$stub_bin/gh"

  export PATH="$stub_bin:$PATH"
  export GITHUB_REPOSITORY="org/repo"
  export POSTMERGE_RETRO_ONLY_PRS="90"
  export POSTMERGE_RETRO_IGNORE_RETRO_DEDUPE=""
  export RUN_DATE="2026-06-30"

  run --separate-stderr bash scripts/workflows/postmerge-retro/daily-retro-select-prs.sh
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
  [[ "$stderr" == *"merge_commit_sha abc123def456 already indexed"* ]]
  rm -rf "$tmp"
}
