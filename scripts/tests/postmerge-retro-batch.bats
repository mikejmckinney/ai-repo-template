#!/usr/bin/env bats
# Post-merge retro batch improvements (#446) unit tests.

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  cd "$REPO_ROOT"
}

@test "bounded retro honors an explicit provider and falls back only when missing" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/bin" "$tmp/work"
  cat >"$tmp/work/evidence-coverage.json" <<'JSON'
{"routing_context":{"provider_resolved":"claude"}}
JSON
  cat >"$tmp/bin/bash" <<'SH'
#!/bin/bash
if [[ "$1" == *"/assemble-retro-prompt.sh" ]]; then
  : >"$5"
  exit 0
fi
if [[ "$1" == *"/run-advisory-claude.sh" ]]; then
  printf 'invoked claude\n' >"$3"
  exit 0
fi
exec /bin/bash "$@"
SH
  cat >"$tmp/bin/node" <<'SH'
#!/bin/bash
printf 'invoked opencode\n' >"$3"
SH
  chmod +x "$tmp/bin/bash" "$tmp/bin/node"

  run env PATH="$tmp/bin:$PATH" /bin/bash \
    scripts/workflows/postmerge-retro/run-postmerge-retro-bounded.sh \
    1 "$tmp/work" "$tmp/output.txt" opencode

  [ "$status" -eq 0 ]
  [[ "$output" == *"via opencode"* ]]
  [ "$(cat "$tmp/output.txt")" = "invoked opencode" ]

  rm -f "$tmp/output.txt"
  run env PATH="$tmp/bin:$PATH" CURSOR_API_KEY=cursor-test \
    /bin/bash scripts/workflows/postmerge-retro/run-postmerge-retro-bounded.sh \
    1 "$tmp/work" "$tmp/output.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"via cursor"* ]]
  [ "$(cat "$tmp/output.txt")" = "invoked opencode" ]

  run env PATH="$tmp/bin:$PATH" /bin/bash \
    scripts/workflows/postmerge-retro/run-postmerge-retro-bounded.sh \
    1 "$tmp/work" "$tmp/output.txt" unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"Bounded retro does not support provider=unknown"* ]]
  rm -rf "$tmp"
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

@test "reconstruct-daily-retro-from-umbrella parses 10-column triage table" {
  tmp="$(mktemp -d)"
  cat >"$tmp/body.md" <<'EOF'
<!-- postmerge-retro:daily:2026-06-19 -->
| PR | Category | Key | Impact | trigger_likelihood | fix_cost | regression_guard | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|---|---|
| #1 | follow_up_issues | `key-a` | incorrect-behavior | edge | moderate | false | should-fix | Title one | Add tests |
EOF
  run python3 scripts/workflows/postmerge-retro/reconstruct-daily-retro-from-umbrella.py \
    --body-file "$tmp/body.md" -o "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].fix_cost == "moderate"' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].regression_guard == false' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].body | contains("Suggested fix")' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].impact == "incorrect-behavior"' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].priority_band == "should-fix"' "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run python3 -S scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "reconstruct-daily-retro-from-umbrella preserves v2 AP11 observations" {
  tmp="$(mktemp -d)"
  cat >"$tmp/body.md" <<'EOF'
<!-- postmerge-retro:daily:2026-07-23 -->
| PR | Category | Key | Impact | Magnitude | trigger_likelihood | Scope | Reversibility | fix_cost | Confidence | Uncertainty | regression_guard | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| #1 | follow_up_issues | `key-v2` | incorrect-behavior | material | common | broad | hard | moderate | high | none | false | fix-now | Wrong output | Correct it |
EOF
  run python3 scripts/workflows/postmerge-retro/reconstruct-daily-retro-from-umbrella.py \
    --body-file "$tmp/body.md" -o "$tmp/daily.json"
  [ "$status" -eq 0 ]
  run jq -e '.findings[0] | .triage_version == 2 and .impact_magnitude == "material" and .affected_scope == "broad" and .reversibility == "hard" and .confidence == "high" and .uncertainty == "none" and .priority_band == "fix-now"' \
    "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "reconstruct-daily-retro-from-umbrella parses legacy 8-column table" {
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

@test "legacy fringe reconstruction pins placeholder fix cost and defer band" {
  tmp="$(mktemp -d)"
  cat >"$tmp/body.md" <<'EOF'
<!-- postmerge-retro:daily:2026-06-19 -->
| PR | Category | Key | Impact | Trigger | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|
| #1 | follow_up_issues | `key-fringe` | dx-perf-doc | fringe | defer | Rare documentation gap | Add a cheap check |
EOF

  run python3 scripts/workflows/postmerge-retro/reconstruct-daily-retro-from-umbrella.py \
    --body-file "$tmp/body.md" -o "$tmp/daily.json"

  [ "$status" -eq 0 ]
  run jq -e '.findings[0] | .fix_cost == "trivial" and .regression_guard == false and .priority_band == "defer"' \
    "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "umbrella-findings-table migrates legacy severity header" {
  run python3 - <<'PY'
from pathlib import Path
import importlib.util

path = Path("scripts/workflows/postmerge-retro/umbrella-findings-table.py")
spec = importlib.util.spec_from_file_location("umbrella_findings_table", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

body = """## Findings

| PR | Category | Dedupe key | Severity | Suggested action |
|---|---|---|---|---|
| #1 | follow_up_issues | `k` | low | fix |

## Meta
x
"""
out, migrated = mod.migrate_findings_table(body)
assert migrated
assert mod.FINDINGS_HEADER in out
assert "Severity" not in out.split("## Meta")[0]
PY
  [ "$status" -eq 0 ]
}

@test "umbrella-findings-table format_row emits triage columns" {
  run python3 - <<'PY'
from pathlib import Path
import importlib.util

path = Path("scripts/workflows/postmerge-retro/umbrella-findings-table.py")
spec = importlib.util.spec_from_file_location("umbrella_findings_table", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

row = mod.format_row(
    {
        "pr": 42,
        "category": "follow_up_issues",
        "dedupe_key": "adr-k",
        "impact": "dx-perf-doc",
        "impact_magnitude": "bounded",
        "trigger_likelihood": "common",
        "affected_scope": "limited",
        "reversibility": "easy",
        "fix_cost": "trivial",
        "confidence": "high",
        "uncertainty": "none",
        "regression_guard": True,
        "priority_band": "defer",
        "title": "T",
    },
    suggested_fix="Do thing",
)
assert "| trigger_likelihood |" not in row
assert "| common |" in row
assert "| true |" in row
assert "| bounded |" in row
assert "| limited | easy |" in row
PY
  [ "$status" -eq 0 ]
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
  ]
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
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"priority_band is derived"* ]]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro accepts automation-derived priority_band on final validation" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'EOF'
{
  "pr": 486,
  "summary": "test",
  "evidence_complete": true,
  "follow_up_issues": [
    {
      "title": "t",
      "body": "b",
      "dedupe_key": "k",
      "priority_band": "should-fix",
      "repro_steps": ["step"],
      "impact": "incorrect-behavior",
      "trigger_likelihood": "edge",
      "fix_cost": "trivial"
    }
  ],
  "merge_commit_sha": "58300efc5a87de5bc9d25c8e47d87af245a726d7"
}
EOF
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py \
    --allow-derived-priority "$tmp/retro.json"
  [ "$status" -eq 0 ]
  run jq -e '.follow_up_issues[0].priority_band == "should-fix"' "$tmp/retro.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro preserves a guarded fringe finding as defer" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'EOF'
{
  "pr": 562,
  "summary": "guarded fringe finding",
  "follow_up_issues": [
    {
      "title": "Rare invariant gap",
      "body": "A rare path lacks a cheap invariant.",
      "dedupe_key": "rare-invariant-gap",
      "repro_steps": ["Exercise the rare path"],
      "triage_version": 2,
      "impact": "meta-harness",
      "impact_magnitude": "bounded",
      "trigger_likelihood": "fringe",
      "affected_scope": "isolated",
      "reversibility": "easy",
      "fix_cost": "trivial",
      "confidence": "high",
      "uncertainty": "none",
      "regression_guard": true
    }
  ]
}
EOF

  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"

  [ "$status" -eq 0 ]
  run jq -e '.follow_up_issues[0] | .regression_guard == true and .priority_band == "defer"' \
    "$tmp/retro.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro rejects retired output buckets" {
  tmp="$(mktemp -d)"
  cat >"$tmp/base.json" <<'EOF'
{
  "pr": 99,
  "summary": "retired bucket fixture",
  "follow_up_issues": []
}
EOF
  for bucket in adr_updates context_pack_updates; do
    jq --arg bucket "$bucket" '. + {($bucket): []}' "$tmp/base.json" >"$tmp/retro.json"
    run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py "$tmp/retro.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$bucket is retired"* ]]
  done
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

@test "mark-superseded-findings.py keeps quality findings actionable" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts/lib"
  printf '%s\n' present >"$tmp/scripts/lib/helper.sh"
  cat >"$tmp/weekly.json" <<'EOF'
{
  "run_week": "2026-W29",
  "findings": [
    {
      "category": "follow_up_issues",
      "title": "Helper lacks tests",
      "body": "scripts/lib/helper.sh exists but has a lack of tests.",
      "dedupe_key": "helper-lacks-tests",
      "repro_steps": ["Review scripts/lib/helper.sh"],
      "evidence": ["scripts/lib/helper.sh"]
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/mark-superseded-findings.py \
    "$tmp/weekly.json" --repo-root "$tmp" --mode weekly
  [ "$status" -eq 0 ]
  run jq -e '.findings[0].superseded_on_main != true' "$tmp/weekly.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "mark-superseded-findings.py rejects traversal absolute and symlink escapes" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo" "$tmp/outside"
  printf '%s\n' present >"$tmp/outside/secret.txt"
  ln -s "$tmp/outside" "$tmp/repo/escape"
  cat >"$tmp/repo/weekly.json" <<EOF
{
  "run_week": "2026-W29",
  "findings": [
    {
      "category": "follow_up_issues",
      "title": "Missing traversal",
      "body": "../outside/secret.txt is missing",
      "dedupe_key": "traversal",
      "repro_steps": ["Check ../outside/secret.txt"],
      "evidence": ["../outside/secret.txt"]
    },
    {
      "category": "follow_up_issues",
      "title": "Missing absolute",
      "body": "$tmp/outside/secret.txt is missing",
      "dedupe_key": "absolute",
      "repro_steps": ["Check absolute path"],
      "evidence": ["$tmp/outside/secret.txt"]
    },
    {
      "category": "follow_up_issues",
      "title": "Missing symlink target",
      "body": "escape/secret.txt is missing",
      "dedupe_key": "symlink",
      "repro_steps": ["Check escape/secret.txt"],
      "evidence": ["escape/secret.txt"]
    }
  ]
}
EOF
  run --separate-stderr python3 scripts/workflows/postmerge-retro/mark-superseded-findings.py \
    "$tmp/repo/weekly.json" --repo-root "$tmp/repo" --mode weekly
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"outside repository"* ]]
  [[ "$stderr" != *"$tmp/outside"* ]]
  run jq -e '[.findings[] | .superseded_on_main == true] | any | not' "$tmp/repo/weekly.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "postmerge schemas distinguish bounded and full evidence" {
  run node - <<'NODE'
const fs = require('fs');
const path = require('path');
const Ajv2020 = require(path.resolve('.github/agent-runtime/node_modules/ajv/dist/2020')).default;
const ajv = new Ajv2020({ strict: false });
const bounded = JSON.parse(fs.readFileSync('.github/schemas/postmerge-retro-bounded.schema.json', 'utf8'));
const full = JSON.parse(fs.readFileSync('.github/schemas/postmerge-retro.schema.json', 'utf8'));
const base = { pr: 1, summary: 'bounded', follow_up_issues: [] };
if (!ajv.validate(bounded, base)) throw new Error(ajv.errorsText());
if (ajv.validate(bounded, { ...base, evidence_complete: true })) throw new Error('bounded accepted evidence_complete');
if (ajv.validate(full, base)) throw new Error('full accepted missing evidence_complete');
if (!ajv.validate(full, { ...base, evidence_complete: true })) throw new Error(ajv.errorsText());
NODE
  [ "$status" -eq 0 ]
}

@test "postmerge LLM schema rejects derived priority_band" {
  run node - <<'NODE'
const fs = require('fs');
const path = require('path');
const Ajv2020 = require(path.resolve('.github/agent-runtime/node_modules/ajv/dist/2020')).default;
const schema = JSON.parse(fs.readFileSync('.github/schemas/postmerge-retro.schema.json', 'utf8'));
const finding = {
  title: 't', body: 'b', dedupe_key: 'k', repro_steps: ['step'],
  impact: 'meta-harness', trigger_likelihood: 'edge', fix_cost: 'trivial',
  priority_band: 'defer'
};
const valid = new Ajv2020({ strict: false }).validate(schema, {
  pr: 1, summary: 's', evidence_complete: true, follow_up_issues: [finding]
});
if (valid) throw new Error('schema accepted derived priority_band');
NODE
  [ "$status" -eq 0 ]
}

@test "sample bounded retro fixture validates against its invocation schema" {
  run node - <<'NODE'
const fs = require('fs');
const path = require('path');
const Ajv2020 = require(path.resolve('.github/agent-runtime/node_modules/ajv/dist/2020')).default;
const schema = JSON.parse(fs.readFileSync('.github/schemas/postmerge-retro-bounded.schema.json', 'utf8'));
const fixture = JSON.parse(fs.readFileSync('scripts/tests/fixtures/postmerge-retro/sample-retro.json', 'utf8'));
const ajv = new Ajv2020({ strict: false });
if (!ajv.validate(schema, fixture)) throw new Error(ajv.errorsText());
NODE
  [ "$status" -eq 0 ]
}

@test "daily validator requires deterministic schema fields" {
  tmp="$(mktemp -d)"
  printf '%s\n' '{"run_date":"2026-07-21","prs":[],"findings":[]}' >"$tmp/daily.json"
  run python3 -S scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py "$tmp/daily.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"window_hours"* ]]
  rm -rf "$tmp"
}

@test "daily and weekly counters exclude superseded findings" {
  tmp="$(mktemp -d)"
  printf '%s\n' '{"findings":[{"superseded_on_main":true},{"superseded_on_main":false},{}]}' >"$tmp/batch.json"
  run python3 scripts/workflows/postmerge-retro/count-daily-retro-findings.py "$tmp/batch.json"
  [ "$status" -eq 0 ]
  [ "$output" = 2 ]
  run python3 scripts/workflows/weekly-review/count-weekly-findings.py "$tmp/batch.json"
  [ "$status" -eq 0 ]
  [ "$output" = 2 ]
  rm -rf "$tmp"
}

@test "daily fixable counter includes only should-fix and fix-now findings" {
  tmp="$(mktemp -d)"
  cat >"$tmp/batch.json" <<'EOF'
{"findings":[
  {"priority_band":"defer"},
  {"priority_band":"should-fix","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}},
  {"priority_band":"fix-now","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}},
  {"priority_band":"fix-now","superseded_on_main":true}
]}
EOF

  run python3 scripts/workflows/postmerge-retro/count-daily-retro-findings.py "$tmp/batch.json"
  [ "$status" -eq 0 ]
  [ "$output" = 3 ]

  run python3 scripts/workflows/postmerge-retro/count-daily-retro-fixable-findings.py "$tmp/batch.json"
  [ "$status" -eq 0 ]
  [ "$output" = 2 ]

  rm -rf "$tmp"
}

@test "daily workflow gates the fix pass on fixable findings" {
  workflow=".github/workflows/agent-postmerge-retro.yml"

  run grep -Fq 'fixable_findings_count: ${{ steps.meta.outputs.fixable_findings_count }}' "$workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'steps.meta.outputs.fixable_findings_count != '\''0'\''' "$workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'FIXABLE_JSON=".artifacts/postmerge-retro/daily-${RUN_DATE}/daily-retro-fixable.json"' "$workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'route-fixable-findings.py' "$workflow"
  [ "$status" -eq 0 ]
  run grep -Fq 'run-postmerge-retro-fix.sh "$FIXABLE_JSON"' "$workflow"
  [ "$status" -eq 0 ]

}

@test "postmerge provider timeout terminates a stuck command" {
  source scripts/workflows/lib/postmerge-provider-timeout.sh

  run --separate-stderr run_postmerge_provider_with_timeout \
    1 cursor full-evidence bash -c 'sleep 10'

  [ "$status" -eq 124 ]
  [[ "$stderr" == *"cursor full-evidence timed out after 1s"* ]]
}

@test "postmerge routes both Cursor paths through the provider timeout" {
  run python3 - <<'PY'
from pathlib import Path

script = Path("scripts/workflows/postmerge-retro/run-postmerge-retro.sh").read_text(encoding="utf-8")
assert 'run_postmerge_provider_with_timeout "$provider_timeout_seconds" cursor bounded' in script
assert 'run_postmerge_provider_with_timeout "$provider_timeout_seconds" cursor full-evidence' in script
assert 'POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS' in script
PY
  [ "$status" -eq 0 ]
}

@test "Cursor full-evidence runner exits after writing output" {
  run python3 - <<'PY'
from pathlib import Path

script = Path("scripts/workflows/postmerge-retro/run-postmerge-retro-full-cursor.mjs").read_text(encoding="utf-8")
write_index = script.index("writeFileSync(outFile, text, \"utf8\");")
exit_index = script.index("process.exit(0);", write_index)
assert exit_index > write_index
PY
  [ "$status" -eq 0 ]
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
{"run_date":"2026-06-19","findings":[],"pr_evidence_coverage":[{"pr":1,"routing_context":{"provenance":{"version":1,"provider":"opencode","requested_model":"requested","observed_model":"observed"}},"provider_attempts":[{"provider":"opencode","status":"success","evidence_route":"bounded"}]}]}
```
EOF
  run python3 scripts/workflows/postmerge-retro/parse-daily-json-snapshot.py "$tmp/snapshot.md"
  [ "$status" -eq 0 ]
  snapshot="$output"
  run jq -e '.run_date == "2026-06-19"' <<<"$snapshot"
  [ "$status" -eq 0 ]
  run jq -e '.pr_evidence_coverage[0].routing_context.provenance.observed_model == "observed"' <<<"$snapshot"
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

@test "compute-evidence-coverage detects diff truncation" {
  tmp="$(mktemp -d)"
  head -c 5000 /dev/zero | tr '\0' 'a' >"$tmp/diff.patch"
  echo "noop.txt" >"$tmp/changed-files.txt"
  touch "$tmp/noop.txt"
  run python3 scripts/workflows/postmerge-retro/compute-evidence-coverage.py \
    "$tmp" --pr 1 --diff-limit 1000 --repo-root "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"would_truncate": true'* ]]
  [[ "$output" == *'"diff_total": 5000'* ]]
  [[ "$output" == *'"diff_included": 1000'* ]]
  rm -rf "$tmp"
}

@test "render-evidence-coverage-meta renders summary warning for truncated PR" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "prs": [9],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 9,
      "diff_included": 10000,
      "diff_total": 450000,
      "head_included": 1000,
      "head_total": 1000,
      "would_truncate": true,
      "head_truncated": false,
      "evidence_route": "bounded",
      "routing_context": {
        "adaptive_enabled": false,
        "provider_resolved": "cursor",
        "cursor_available": true,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py --section summary "$tmp/daily.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[!WARNING]"* ]]
  [[ "$output" == *"Evidence truncated"* ]]
  [[ "$output" == *"PR #9"* ]]
  [[ "$output" == *"postmerge-retro:truncation-summary:start"* ]]
  rm -rf "$tmp"
}

@test "render-evidence-coverage-meta summary empty when no truncation" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "prs": [1],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 1,
      "diff_included": 100,
      "diff_total": 100,
      "head_included": 50,
      "head_total": 50,
      "would_truncate": false,
      "evidence_route": "bounded",
      "routing_context": {
        "adaptive_enabled": false,
        "provider_resolved": "cursor",
        "cursor_available": true,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py --section summary "$tmp/daily.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "$tmp"
}

@test "render-evidence-coverage-meta merges summary into legacy umbrella body" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "prs": [9],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 9,
      "diff_included": 10000,
      "diff_total": 20601,
      "head_included": 1000,
      "head_total": 1000,
      "would_truncate": true,
      "evidence_route": "bounded",
      "routing_context": {
        "adaptive_enabled": false,
        "provider_resolved": "cursor",
        "cursor_available": true,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  cat >"$tmp/body.md" <<'EOF'
## Summary

**PRs in this update:** #9

## Findings

| PR | Category | Key | Impact | trigger_likelihood | fix_cost | regression_guard | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|---|---|
| 9 | test | `key-1` | low | low | low | none | info | x | y |

## Meta

**Evidence coverage**

- PR #9 — diff 10000/20601 (truncated); route: bounded; provider: cursor; antigravity: false
EOF
  run python3 - "$tmp/body.md" "$tmp/daily.json" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

body = Path(sys.argv[1]).read_text(encoding="utf-8")
data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
path = Path("scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py")
spec = importlib.util.spec_from_file_location("render_evidence_coverage_meta", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
records = data.get("pr_evidence_coverage") or []
print(mod.merge_summary_into_body(body, records))
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"[!WARNING]"* ]]
  [[ "$output" == *"Evidence truncated"* ]]
  [[ "$output" == *"## Findings"* ]]
  [[ "$output" == *"postmerge-retro:truncation-summary:start"* ]]
  rm -rf "$tmp"
}

@test "render-evidence-coverage-meta renders bounded fallback line" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "prs": [9],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 9,
      "diff_included": 300000,
      "diff_total": 450000,
      "head_included": 1000,
      "head_total": 2000,
      "would_truncate": true,
      "evidence_route": "bounded-fallback",
      "routing_context": {
        "adaptive_enabled": true,
        "provider_resolved": "gemini",
        "cursor_available": false,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py "$tmp/daily.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR #9"* ]]
  [[ "$output" == *"route: bounded-fallback"* ]]
  [[ "$output" == *"antigravity unavailable"* ]]
  rm -rf "$tmp"
}

@test "merge-daily-retro-json includes pr_evidence_coverage sidecars" {
  tmp="$(mktemp -d)"
  cat >"$tmp/pr-1-retro.json" <<'EOF'
{"pr": 1, "summary": "s", "follow_up_issues": []}
EOF
  cat >"$tmp/pr-1-evidence-coverage.json" <<'EOF'
{"pr": 1, "diff_included": 10, "diff_total": 20, "head_included": 5, "head_total": 5, "would_truncate": true, "evidence_route": "bounded", "routing_context": {"adaptive_enabled": false, "provider_resolved": "cursor", "cursor_available": true, "antigravity_available": false}}
EOF
  run python3 scripts/workflows/postmerge-retro/merge-daily-retro-json.py 2026-06-20 "$tmp/pr-1-retro.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"pr_evidence_coverage"'* ]]
  [[ "$output" == *'"evidence_route": "bounded"'* ]]
  rm -rf "$tmp"
}

@test "merge-daily-retro-json preserves failed PR sidecars" {
  tmp="$(mktemp -d)"
  cat >"$tmp/pr-1-retro.json" <<'EOF'
{"pr": 1, "summary": "completed", "follow_up_issues": []}
EOF
  cat >"$tmp/pr-2-failure.json" <<'EOF'
{"pr": 2, "stage": "analysis", "reason": "provider cascade exhausted"}
EOF

  run python3 scripts/workflows/postmerge-retro/merge-daily-retro-json.py \
    2026-07-16 "$tmp/pr-1-retro.json"

  [ "$status" -eq 0 ]
  run jq -e '.failed_prs == [{"pr": 2, "stage": "analysis", "reason": "provider cascade exhausted"}]' <<<"$output"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "daily retro isolates per-PR failures before finalization" {
  run python3 - <<'PY'
from pathlib import Path

text = Path("scripts/workflows/postmerge-retro/run-postmerge-retro-daily.sh").read_text(encoding="utf-8")
assert 'if bash "$SCRIPT_DIR/run-postmerge-retro.sh"' in text
assert 'failure.json' in text
PY

  [ "$status" -eq 0 ]
}

@test "validate-postmerge-retro-daily accepts pr_evidence_coverage" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "window_hours": 24,
  "summary": "test",
  "prs": [1],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 1,
      "diff_included": 1,
      "diff_total": 2,
      "head_included": 1,
      "head_total": 2,
      "would_truncate": true,
      "evidence_route": "bounded",
      "routing_context": {
        "adaptive_enabled": false,
        "provider_resolved": "cursor",
        "cursor_available": true,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py "$tmp/daily.json"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "render-evidence-coverage-meta summary empty for full-evidence-cursor route" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-06-20",
  "prs": [99],
  "findings": [],
  "pr_evidence_coverage": [
    {
      "pr": 99,
      "diff_included": 10000,
      "diff_total": 20601,
      "head_included": 54923,
      "head_total": 139030,
      "would_truncate": true,
      "head_truncated": true,
      "evidence_route": "full-evidence-cursor",
      "routing_context": {
        "adaptive_enabled": true,
        "provider_resolved": "cursor",
        "cursor_available": true,
        "antigravity_available": false
      }
    }
  ]
}
EOF
  run python3 scripts/workflows/postmerge-retro/render-evidence-coverage-meta.py --section summary "$tmp/daily.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "$tmp"
}

@test "compute-evidence-coverage adaptive default routes truncated PR to full-evidence-cursor" {
  tmp="$(mktemp -d)"
  head -c 5000 /dev/zero | tr '\0' 'a' >"$tmp/diff.patch"
  echo "noop.txt" >"$tmp/changed-files.txt"
  touch "$tmp/noop.txt"
  export CURSOR_API_KEY="test-key"
  unset POSTMERGE_RETRO_ADAPTIVE_EVIDENCE
  run python3 scripts/workflows/postmerge-retro/compute-evidence-coverage.py \
    "$tmp" --pr 7 --diff-limit 1000 --repo-root "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"evidence_route": "full-evidence-cursor"'* ]]
  [[ "$output" == *'"adaptive_enabled": true'* ]]
  unset CURSOR_API_KEY
  rm -rf "$tmp"
}

@test "assemble-retro-prompt full-evidence references diff.patch path" {
  tmp="$(mktemp -d)"
  repo_root="$(pwd)"
  mkdir -p "$tmp/evidence"
  printf '{"number": 1, "title": "t", "body": "b", "html_url": "https://example/pr/1", "head": {"sha": "abc"}, "merge_commit_sha": "def", "merged_at": "2026-01-01T00:00:00Z", "merged": true}' >"$tmp/evidence/pr.json"
  echo "[]" >"$tmp/evidence/labels.json"
  echo "[]" >"$tmp/evidence/reviews.json"
  echo "[]" >"$tmp/evidence/review-comments.json"
  echo "summary" >"$tmp/evidence/summary.txt"
  echo "README.md" >"$tmp/evidence/changed-files.txt"
  readme_backup="$(mktemp)"
  cp "$repo_root/README.md" "$readme_backup"
  echo "FULL_EVIDENCE_MUST_NOT_INLINE_THIS_CONTENT" >"$repo_root/README.md"
  head -c 200 /dev/zero | tr '\0' 'x' >"$tmp/evidence/diff.patch"
  run bash scripts/workflows/postmerge-retro/assemble-retro-prompt.sh \
    1 "$tmp/evidence" full-evidence "$tmp/prompt.md"
  cp "$readme_backup" "$repo_root/README.md"
  rm -f "$readme_backup"
  [ "$status" -eq 0 ]
  [[ "$(cat "$tmp/prompt.md")" == *"diff.patch"* ]]
  [[ "$(cat "$tmp/prompt.md")" == *"full-evidence"* ]]
  [[ "$(cat "$tmp/prompt.md")" != *"### Diff (truncated excerpt)"* ]]
  [[ "$(cat "$tmp/prompt.md")" != *"FULL_EVIDENCE_MUST_NOT_INLINE_THIS_CONTENT"* ]]
  [[ "$(cat "$tmp/prompt.md")" == *"context-files.txt"* ]]
  [[ "$(cat "$tmp/prompt.md")" == *"$tmp/evidence/diff.patch"* ]]
  [[ "$(cat "$tmp/prompt.md")" == *'"evidence_complete": true'* ]]
  rm -rf "$tmp"
}

@test "assemble-retro-prompt bounded mode omits full-evidence completion field" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/evidence"
  printf '{"number":1,"title":"t","body":"b","html_url":"https://example/pr/1","head":{"sha":"abc"},"merge_commit_sha":"def","merged_at":"2026-01-01T00:00:00Z","merged":true}' >"$tmp/evidence/pr.json"
  printf '%s\n' '[]' >"$tmp/evidence/labels.json"
  printf '%s\n' '[]' >"$tmp/evidence/reviews.json"
  printf '%s\n' '[]' >"$tmp/evidence/review-comments.json"
  printf '%s\n' summary >"$tmp/evidence/summary.txt"
  printf '%s\n' README.md >"$tmp/evidence/changed-files.txt"
  printf '%s\n' diff >"$tmp/evidence/diff.patch"
  run bash scripts/workflows/postmerge-retro/assemble-retro-prompt.sh \
    1 "$tmp/evidence" bounded "$tmp/prompt.md"
  [ "$status" -eq 0 ]
  [[ "$(cat "$tmp/prompt.md")" == *"Omit \`evidence_complete\`"* ]]
  [[ "$(cat "$tmp/prompt.md")" != *'"evidence_complete": true'* ]]
  rm -rf "$tmp"
}

@test "post-merge collector supplies check runs with the workflow token" {
  run python3 - <<'PY'
from pathlib import Path

collector = Path("scripts/workflows/lib/collect-pr-evidence.sh").read_text(encoding="utf-8")
workflow = Path(".github/workflows/agent-postmerge-retro.yml").read_text(encoding="utf-8")
prompt = Path("scripts/workflows/postmerge-retro/assemble-retro-prompt.sh").read_text(encoding="utf-8")
validator = Path("scripts/workflows/postmerge-retro/validate-opencode-retrieval.py").read_text(encoding="utf-8")

assert 'commits/${head_sha}/check-runs' in collector
assert 'GH_TOKEN="$GITHUB_TOKEN"' in collector
assert "checks: read" in workflow
assert "checks.json" in prompt
assert '"checks.json"' in validator
PY

  [ "$status" -eq 0 ]
}

@test "full-evidence HEAD warning identifies only the bounded snapshot limit" {
  tmp="$(mktemp -d)"
  cat >"$tmp/coverage.json" <<'EOF'
{
  "pr": 131,
  "diff_included": 1,
  "diff_total": 1,
  "head_included": 50008,
  "head_total": 69796,
  "would_truncate": true,
  "diff_truncated": false,
  "head_truncated": true,
  "omitted_head_paths": ["scripts/tests/opencode-provider.bats"],
  "evidence_route": "full-evidence-opencode"
}
EOF

  run --separate-stderr python3 scripts/workflows/postmerge-retro/compute-evidence-coverage.py \
    --warn-record "$tmp/coverage.json"

  [ "$status" -eq 0 ]
  [[ "$stderr" == *"bounded HEAD snapshot would truncate"* ]]
  [[ "$stderr" == *"full-evidence-opencode retrieves full paths"* ]]
  rm -rf "$tmp"
}

@test "validate-postmerge-retro requires completion for full-evidence output" {
  tmp="$(mktemp -d)"
  cat >"$tmp/retro.json" <<'JSON'
{
  "pr": 1,
  "summary": "Evidence retrieval stopped before the complete diff was read.",
  "evidence_complete": false,
  "follow_up_issues": []
}
JSON

  run python3 scripts/workflows/postmerge-retro/validate-postmerge-retro.py \
    --require-evidence-complete "$tmp/retro.json"

  [ "$status" -eq 1 ]
  [[ "$output" == *"evidence_complete must be true"* ]]
  rm -rf "$tmp"
}

@test "validate-opencode-retrieval requires evidence beyond auto-loaded AGENTS.md" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/src" "$tmp/repo/.artifacts/work"
  echo "diff" >"$tmp/repo/.artifacts/work/diff.patch"
  echo "{}" >"$tmp/repo/.artifacts/work/pr.json"
  echo "summary" >"$tmp/repo/.artifacts/work/summary.txt"
  echo "src/app.py" >"$tmp/repo/.artifacts/work/changed-files.txt"
  printf 'AGENTS.md\nREADME.md\n' >"$tmp/repo/.artifacts/work/context-files.txt"
  echo "instructions" >"$tmp/repo/AGENTS.md"
  echo "app" >"$tmp/repo/src/app.py"
  echo "readme" >"$tmp/repo/README.md"
  cat >"$tmp/repo/.artifacts/work/retrieval-trace.json" <<JSON
{
  "paths": [
    "$tmp/repo/.artifacts/work/diff.patch",
    "$tmp/repo/.artifacts/work/pr.json",
    "$tmp/repo/.artifacts/work/summary.txt",
    "$tmp/repo/.artifacts/work/changed-files.txt",
    "src/app.py",
    "README.md"
  ]
  }
JSON

  run python3 scripts/workflows/postmerge-retro/validate-opencode-retrieval.py \
    "$tmp/repo/.artifacts/work/retrieval-trace.json" \
    "$tmp/repo/.artifacts/work" "$tmp/repo"
  [ "$status" -eq 0 ]

  jq 'del(.paths[] | select(. == "README.md"))' \
    "$tmp/repo/.artifacts/work/retrieval-trace.json" \
    >"$tmp/repo/.artifacts/work/missing-context-trace.json"
  run python3 scripts/workflows/postmerge-retro/validate-opencode-retrieval.py \
    "$tmp/repo/.artifacts/work/missing-context-trace.json" \
    "$tmp/repo/.artifacts/work" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"README.md"* ]]

  jq 'del(.paths[0])' "$tmp/repo/.artifacts/work/retrieval-trace.json" \
    >"$tmp/repo/.artifacts/work/incomplete-trace.json"
  run python3 scripts/workflows/postmerge-retro/validate-opencode-retrieval.py \
    "$tmp/repo/.artifacts/work/incomplete-trace.json" \
    "$tmp/repo/.artifacts/work" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"diff.patch"* ]]
  rm -rf "$tmp"
}

@test "truncated daily evidence routes through Claude when available" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo"
  head -c 5000 /dev/zero | tr '\0' 'a' >"$tmp/diff.patch"
  printf 'README.md\n' >"$tmp/changed-files.txt"
  printf 'readme\n' >"$tmp/repo/README.md"

  run env CLAUDE_BIN=/bin/true CLAUDE_CODE_OAUTH_TOKEN=claude-test \
    OPENCODE_BIN=/bin/true OPENROUTER_API_KEY=openrouter-test \
    OPENCODE_GITHUB_TOKEN=github-read-test CURSOR_API_KEY=cursor-test \
    GEMINI_API_KEY=gemini-test \
    python3 scripts/workflows/postmerge-retro/compute-evidence-coverage.py \
    "$tmp" --pr 7 --diff-limit 1000 --repo-root "$tmp/repo"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"evidence_route": "full-evidence-claude"'* ]]
  [[ "$output" == *'"provider_resolved": "claude"'* ]]
  rm -rf "$tmp"
}

@test "weekly Claude retrieval requires observed repository reads and path-backed findings" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/src"
  printf 'source\n' >"$tmp/repo/src/app.py"
  printf 'startup\n' >"$tmp/repo/README.md"
  cat >"$tmp/review.json" <<'JSON'
{"summary":"review","follow_up_issues":[{"title":"Finding","body":"Body","dedupe_key":"repo-finding","repro_steps":["Run"],"evidence":["README.md:1"],"triage_version":2,"impact":"incorrect-behavior","impact_magnitude":"bounded","trigger_likelihood":"edge","affected_scope":"isolated","reversibility":"easy","fix_cost":"trivial","confidence":"high","uncertainty":"none"}]}
JSON
  printf '{"paths":["src/app.py"],"github_calls":0,"tools":["Read"]}\n' >"$tmp/trace.json"

  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 0 ]

  for evidence in README.md#L1 README.md#L1-L1 README.md:1-1 README.md:1:7; do
    jq --arg evidence "$evidence" '.follow_up_issues[0].evidence = [$evidence]' \
      "$tmp/review.json" >"$tmp/location-review.json"
    run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
      "$tmp/trace.json" "$tmp/location-review.json" "$tmp/repo"
    [ "$status" -eq 0 ]
  done

  sed 's/README.md:1/missing.md:1/' "$tmp/review.json" >"$tmp/missing-review.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/missing-review.json" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid or missing repository file paths"* ]]

  printf '{"paths":[],"directories":["src"],"github_calls":0,"tools":["Grep"]}\n' >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 0 ]

  printf '{"paths":[],"directories":["%s"],"github_calls":0,"tools":["Grep"]}\n' \
    "$tmp/repo" >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 0 ]

  printf '{"paths":[],"directories":"src","github_calls":0,"tools":["Grep"]}\n' >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"directories must be an array of strings"* ]]

  printf '{"paths":[],"directories":["src/app.py"],"github_calls":0,"tools":["Grep"]}\n' >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"repository read"* ]]

  printf '{"paths":[],"directories":["/tmp"],"github_calls":0,"tools":["Grep"]}\n' >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"repository read"* ]]

  printf '{"paths":[],"github_calls":1,"tools":["mcp__github_read__get_repository"]}\n' >"$tmp/trace.json"
  run python3 scripts/workflows/weekly-review/validate-claude-retrieval.py \
    "$tmp/trace.json" "$tmp/review.json" "$tmp/repo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"repository read"* ]]
  rm -rf "$tmp"
}

@test "run-postmerge-retro-antigravity rejects oversized payload" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/.github/prompts" "$tmp/workdir"
  echo "system" >"$tmp/repo/.github/prompts/post-merge-retro.md"
  echo "agents" >"$tmp/repo/AGENTS.md"
  echo "task" >"$tmp/prompt.md"
  head -c 5000000 /dev/zero | tr '\0' 'z' >"$tmp/workdir/diff.patch"
  echo '{"number": 1}' >"$tmp/workdir/pr.json"
  export GEMINI_API_KEY="dummy"
  export POSTMERGE_RETRO_ANTIGRAVITY_PAYLOAD_LIMIT=1000
  run python3 scripts/workflows/postmerge-retro/run-postmerge-retro-antigravity.py \
    "$tmp/repo" "$tmp/workdir" "$tmp/prompt.md" "$tmp/out.txt"
  [ "$status" -eq 3 ]
  unset GEMINI_API_KEY POSTMERGE_RETRO_ANTIGRAVITY_PAYLOAD_LIMIT
  rm -rf "$tmp"
}

@test "compute-evidence-coverage --set-route bounded-fallback emits warning" {
  tmp="$(mktemp -d)"
  cat >"$tmp/coverage.json" <<'EOF'
{
  "pr": 9,
  "diff_included": 1000,
  "diff_total": 5000,
  "head_included": 100,
  "head_total": 100,
  "would_truncate": true,
  "diff_truncated": true,
  "head_truncated": false,
  "evidence_route": "full-evidence-cursor",
  "routing_context": {
    "adaptive_enabled": true,
    "provider_resolved": "cursor",
    "cursor_available": true,
    "antigravity_available": false
  }
}
EOF
  run --separate-stderr python3 scripts/workflows/postmerge-retro/compute-evidence-coverage.py \
    --warn-record "$tmp/coverage.json" --set-route bounded-fallback
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"fell back to bounded"* ]]
  [[ "$(jq -r .evidence_route "$tmp/coverage.json")" == "bounded-fallback" ]]
  rm -rf "$tmp"
}

@test "append-merge-index-markers places invisible markers in Meta only" {
  tmp="$(mktemp -d)"
  cat >"$tmp/daily.json" <<'EOF'
{
  "run_date": "2026-07-05",
  "pr_merges": [{"pr": 99, "merge_commit_sha": "abc123def456"}]
}
EOF
  cat >"$tmp/body.md" <<'EOF'
## Findings

| PR | Category | Key | Impact | trigger_likelihood | fix_cost | regression_guard | Band | Finding | Suggested fix |
|---|---|---|---|---|---|---|---|---|---|
| 99 | test | `k` | incorrect-behavior | edge | trivial | false | defer | f | s |
**Indexed merge commits (automation):**
<!-- postmerge-retro:merge:deadbeef pr:88 -->

## Meta

**Evidence coverage**

- PR #99 — route: bounded
EOF
  run python3 - "$tmp/daily.json" "$tmp/body.md" "$tmp/out.md" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

# Inline the merge script's python block (same as append-merge-index-markers.sh)
body_raw = Path(sys.argv[2]).read_text(encoding="utf-8")
daily = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
out = Path(sys.argv[3])

import re
MERGE_INDEX_START = "<!-- postmerge-retro:merge-index:start -->"
MERGE_INDEX_END = "<!-- postmerge-retro:merge-index:end -->"
MARKER_RE = re.compile(r"<!-- postmerge-retro:merge:[0-9a-f]{7,40} pr:\d+ -->", re.IGNORECASE)
LEGACY_HEADING_RE = re.compile(
    r"\n\*\*Indexed merge commits \(automation\):\*\*\n"
    r"(?:<!-- postmerge-retro:merge:[^>]+ -->\n?)*",
    re.IGNORECASE,
)
LEGACY_INDEX_BLOCK_RE = re.compile(
    rf"\n?{re.escape(MERGE_INDEX_START)}.*?{re.escape(MERGE_INDEX_END)}\n?",
    re.DOTALL | re.IGNORECASE,
)

def _existing_markers(text):
    return MARKER_RE.findall(text)

def _new_markers(daily, body):
    markers = []
    for row in daily.get("pr_merges") or []:
        pr = row.get("pr")
        sha = str(row.get("merge_commit_sha") or "").strip().lower()
        if not pr or not sha:
            continue
        marker = f"<!-- postmerge-retro:merge:{sha} pr:{pr} -->"
        if marker not in body and marker not in markers:
            markers.append(marker)
    return markers

def _strip_legacy_visible_blocks(text):
    return LEGACY_HEADING_RE.sub("\n", text)

def _strip_merge_index_region(meta_tail):
    meta_tail = LEGACY_INDEX_BLOCK_RE.sub("\n", meta_tail)
    return MARKER_RE.sub("", meta_tail)

def _merge_index_block(markers):
    if not markers:
        return ""
    return "\n".join([MERGE_INDEX_START, *markers, MERGE_INDEX_END, ""])

existing = _existing_markers(body_raw)
body = _strip_legacy_visible_blocks(body_raw)
incoming = _new_markers(daily, body_raw)
all_markers = []
for marker in existing + incoming:
    if marker not in all_markers:
        all_markers.append(marker)
block = _merge_index_block(all_markers)
head, meta_tail = body.split("## Meta", 1)
meta_tail = _strip_merge_index_region(meta_tail).lstrip("\n")
merged = head.rstrip() + "\n\n## Meta\n\n" + block + meta_tail
out.write_text(merged)
PY
  [ "$status" -eq 0 ]
  merged="$(cat "$tmp/out.md")"
  [[ "$merged" != *"Indexed merge commits (automation)"* ]]
  [[ "$merged" == *"postmerge-retro:merge-index:start"* ]]
  [[ "$merged" == *"postmerge-retro:merge:abc123def456 pr:99"* ]]
  [[ "$merged" == *"postmerge-retro:merge:deadbeef pr:88"* ]]
  [[ "$merged" != *"## Findings"* ]] || true
  [[ "$merged" == *"## Meta"* ]]
  rm -rf "$tmp"
}
