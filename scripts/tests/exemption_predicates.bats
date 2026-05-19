#!/usr/bin/env bats
# scripts/tests/exemption_predicates.bats
#
# ADR-028 exemption predicate validator tests (issue #349).
#
# Tests the four predicate functions from scripts/lib/exemption_predicates.py
# directly via the CLI entry-point. Each predicate has positive + negative cases
# plus the per-category fixture matrix for operational_process (AC12).

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  PREDICATES="$REPO_ROOT/scripts/lib/exemption_predicates.py"
  export PREDICATES
}

# ---------------------------------------------------------------------------
# Smoke: module is importable and CLI --help works
# ---------------------------------------------------------------------------

@test "exemption_predicates.py exists and is non-empty" {
  [ -s "$PREDICATES" ]
}

@test "exemption_predicates.py CLI --help exits 0" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"exemption predicate"* ]]
}

# ---------------------------------------------------------------------------
# A1 judge_decision -- positive cases
# ---------------------------------------------------------------------------

@test "judge_decision: allowlisted identity + valid header returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision     --comment-body "## Judge — DECISION

DECISION: APPROVE WITH EXEMPTION — pure-docs PR; doc_sync triggers checked."     --runtime-identity "mikejmckinney"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "judge_decision: workflow_runtime identity returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision     --comment-body "## Judge — DECISION

DECISION: APPROVE WITH EXEMPTION — operational-process PR; A3 globs match."     --runtime-identity "github-actions[bot]"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# A1 judge_decision -- negative cases
# ---------------------------------------------------------------------------

@test "judge_decision: missing header returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision     --comment-body "This looks fine to me."     --runtime-identity "mikejmckinney"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "judge_decision: hyphen-minus instead of em-dash returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision     --comment-body "## Judge - DECISION

DECISION: APPROVE WITH EXEMPTION - hyphen not em-dash."     --runtime-identity "mikejmckinney"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "judge_decision: unknown identity returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision     --comment-body "## Judge — DECISION

DECISION: APPROVE WITH EXEMPTION — valid reason."     --runtime-identity "unknown-bot-xyz"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "judge_decision: empty reason returns false" {
  cd "$REPO_ROOT"
  # Reason is a single space after em-dash -- must fail (non-empty required)
  run python3 "$PREDICATES" judge-decision     --comment-body "## Judge — DECISION

DECISION: APPROVE WITH EXEMPTION —  "     --runtime-identity "mikejmckinney"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

# ---------------------------------------------------------------------------
# A1p4 RC3 label -- positive cases
# ---------------------------------------------------------------------------

@test "label: recognized label + human applier + no subagents returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" label     --pr-labels "chore:no-plan"     --applier-login "mikejmckinney"     --subagents-dispatched ""
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "label: recognized label + applier not in subagents list returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" label     --pr-labels "smoke-test"     --applier-login "mikejmckinney"     --subagents-dispatched "github-copilot[bot],some-other-agent"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# A1p4 RC3 label -- negative cases
# ---------------------------------------------------------------------------

@test "label: subagent-applied label always rejected (RC3)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" label     --pr-labels "chore:no-plan"     --applier-login "github-copilot[bot]"     --subagents-dispatched "github-copilot[bot]"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "label: unrecognized label returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" label     --pr-labels "not-an-exemption"     --applier-login "mikejmckinney"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "label: no labels returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" label     --pr-labels ""     --applier-login "mikejmckinney"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

# ---------------------------------------------------------------------------
# A3 operational_process -- positive cases (per-category matrix AC12)
# ---------------------------------------------------------------------------

@test "operational_process: .github/workflows/** matches (workflows category)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".github/workflows/ci.yml"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .github/actions/** matches (actions category, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".github/actions/my-action/action.yml"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .github/agents/** matches (agents-copilot category)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".github/agents/judge.agent.md"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .claude/agents/** matches (agents-claude category, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".claude/agents/judge.md"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .context/rules/agent_ownership.md matches (agent-ownership, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".context/rules/agent_ownership.md"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .context/rules/domain_*.md matches (domain-rules category, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".context/rules/domain_code_quality.md"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .context/rules/repo_*.md matches (repo-rules category, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".context/rules/repo_orchestration_patterns.md"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: install.sh matches (install-sh category)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths "install.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: test.sh matches (test-sh category)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths "test.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: Makefile matches (makefile category)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths "Makefile"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "operational_process: .github/actions/**/*.js matches (js-payload-via-actions, AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".github/actions/label-sync/index.js"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# A3 operational_process -- negative cases
# ---------------------------------------------------------------------------

@test "operational_process: docs/** does NOT match (negative control AC12)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths "docs/README.md"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "operational_process: mixed paths one outside glob set returns false without fallback" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ".github/workflows/ci.yml,docs/decisions/adr-999.md"     --pr-body ""
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "operational_process: empty changed-paths returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process     --changed-paths ""     --pr-body "operational_process exemption"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "operational_process: grep fallback phrase in PR body returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process \
    --changed-paths "docs/guides/some-guide.md" \
    --pr-body "This is a shared procedural prompt update." \
    --issue-body "See .github/prompts/op-issue-workflow.md for details."
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# A4 adr_clause -- positive cases
# ---------------------------------------------------------------------------

@test "adr_clause: active entry with null expiry returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-011#plan-as-comment-exemption-≤20LOC-single-role"     --now "2026-05-19"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "adr_clause: active entry with future expiry returns true" {
  cd "$REPO_ROOT"
  TMPFILE="$(mktemp --suffix=.yaml)"
  cat > "$TMPFILE" <<'REGEOF'
schema: "adr_exemption_registry:v1"
entries:
  - clause_id: "ADR-999#future-expiry-clause"
    scope: ["docs/**"]
    expires_at: "2099-12-31"
    granted_by: "test"
    notes: "synthetic"
expired: []
REGEOF
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-999#future-expiry-clause"     --now "2026-05-19"     --registry-file "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# A4 adr_clause -- negative cases
# ---------------------------------------------------------------------------

@test "adr_clause: expired entry returns false" {
  cd "$REPO_ROOT"
  TMPFILE="$(mktemp --suffix=.yaml)"
  cat > "$TMPFILE" <<'REGEOF'
schema: "adr_exemption_registry:v1"
entries: []
expired:
  - clause_id: "ADR-999#moved-to-expired"
    scope: ["docs/**"]
    granted_by: "test"
    expired_at: "2025-06-01"
    replacement_clause_id: null
REGEOF
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-999#moved-to-expired"     --now "2026-05-19"     --registry-file "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "adr_clause: past expiry date returns false" {
  cd "$REPO_ROOT"
  TMPFILE="$(mktemp --suffix=.yaml)"
  cat > "$TMPFILE" <<'REGEOF'
schema: "adr_exemption_registry:v1"
entries:
  - clause_id: "ADR-999#past-expiry"
    scope: ["docs/**"]
    expires_at: "2025-01-01"
    granted_by: "test"
    notes: "synthetic"
expired: []
REGEOF
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-999#past-expiry"     --now "2026-05-19"     --registry-file "$TMPFILE"
  rm -f "$TMPFILE"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "adr_clause: unknown clause_id returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-999#totally-unknown-clause-xyz"     --now "2026-05-19"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "adr_clause: malformed clause_id (no slug) returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" adr-clause     --clause-id "ADR-028"     --now "2026-05-19"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "adr_clause: malformed clause_id (not ADR-NNN format) returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" adr-clause     --clause-id "not-an-adr-clause-id"     --now "2026-05-19"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

# ---------------------------------------------------------------------------
# A1 judge_decision -- A1p4 RC1 subagent exclusion
# ---------------------------------------------------------------------------

@test "judge_decision: allowlisted identity in excluded_logins returns false (A1p4 RC1)" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" judge-decision \
    --comment-body "## Judge â DECISION

DECISION: APPROVE WITH EXEMPTION â operational-process PR; A3 globs match." \
    --runtime-identity "copilot-pull-request-reviewer[bot]" \
    --subagents-dispatched "copilot-pull-request-reviewer[bot]"
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

# ---------------------------------------------------------------------------
# A3 operational_process -- grep fallback issue cross-reference (ADR-028 A3)
# ---------------------------------------------------------------------------

@test "operational_process: grep fallback without issue body ref returns false" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process \
    --changed-paths "docs/guides/some-guide.md" \
    --pr-body "This is a shared procedural prompt update." \
    --issue-body "No procedural prompt reference here."
  [ "$status" -ne 0 ]
  [ "$output" = "false" ]
}

@test "operational_process: grep fallback with pr-resolve-all.md issue ref returns true" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" operational-process \
    --changed-paths "docs/guides/some-guide.md" \
    --pr-body "exempt per ADR-014" \
    --issue-body "Tracked under .github/prompts/pr-resolve-all.md workflow."
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

# ---------------------------------------------------------------------------
# Self-check: all fixtures pass
# ---------------------------------------------------------------------------

@test "exemption_predicates.py --self-check passes all fixtures" {
  cd "$REPO_ROOT"
  run python3 "$PREDICATES" --self-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"fixtures passed"* ]]
  # Verify no FAIL lines in output
  [[ "$output" != *"[FAIL]"* ]]
}
