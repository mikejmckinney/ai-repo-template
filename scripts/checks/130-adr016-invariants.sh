#!/usr/bin/env bash
# scripts/checks/130-adr016-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- ADR-016 invariants (issue #227 / pre-merge verification gate) ---
echo "Checking ADR-016 components (issue #227 / pre-merge verification)..."

ADR016_PATH="docs/decisions/adr-016-pre-merge-verification-gate.md"
if [[ -f "$ADR016_PATH" ]] \
  && grep -qE '^Accepted$' "$ADR016_PATH" 2>/dev/null; then
  pass "ADR-016 exists with Status: Accepted"
else
  fail "ADR-016 missing or Status line is not 'Accepted' ($ADR016_PATH)"
fi

if grep -q 'ADR-016' docs/decisions/README.md 2>/dev/null; then
  pass "docs/decisions/README.md indexes ADR-016"
else
  fail "docs/decisions/README.md missing ADR-016 row"
fi

if [[ -f scripts/validate-verification-evidence.py ]] \
  && grep -q 'Evidence contract: 1' .github/pull_request_template.md \
  && grep -q 'Default-branch constrained' .github/PLAN_TEMPLATE.md \
  && grep -q 'Execution-constraint routing' "$ADR016_PATH"; then
  pass "versioned execution-constraint evidence is wired into planning and ADR-016"
else
  fail "verification evidence validator, planning fields, or ADR-016 amendment missing"
fi

if [[ -f .github/workflows/agent-workflow-pr-smoke.yml ]] \
  && [[ -f .github/workflows/agent-workflow-smoke.yml ]] \
  && grep -q 'uses: ./.github/workflows/agent-workflow-smoke.yml' .github/workflows/agent-workflow-pr-smoke.yml \
  && grep -q 'validate-pr-workflow-fixtures.py' .github/workflows/agent-workflow-smoke.yml \
  && grep -q 'validate-postmerge-retro-daily.py' scripts/workflows/validate-pr-workflow-fixtures.py \
  && grep -q 'validate-weekly-review-batch.py' scripts/workflows/validate-pr-workflow-fixtures.py; then
  pass "same-commit PR harness exercises daily and weekly core scripts"
else
  fail "same-commit daily/weekly PR fixture harness is incomplete"
fi

# Plan template carries the Change class + outcome-environment lines.
if grep -q 'Change class' .github/PLAN_TEMPLATE.md 2>/dev/null \
  && grep -q 'Outcome environments' .github/PLAN_TEMPLATE.md 2>/dev/null; then
  pass ".github/PLAN_TEMPLATE.md exposes Change class + outcome environments"
else
  fail ".github/PLAN_TEMPLATE.md missing Change class / outcome environments"
fi

# Sandbox playbook lives at the documented path.
if [[ -f docs/guides/sandbox-verification.md ]]; then
  pass "docs/guides/sandbox-verification.md exists (issue #227 Phase 2)"
else
  fail "docs/guides/sandbox-verification.md missing (issue #227 Phase 2)"
fi

# The guide points to the executable classifier instead of repeating triggers.
if grep -q 'scripts/verify-pr.sh.*canonical classifier' docs/guides/agent-pipeline.md 2>/dev/null \
  && ! grep -q '| `schedule`, `workflow_dispatch`, `push`' docs/guides/agent-pipeline.md 2>/dev/null; then
  pass "agent-pipeline.md points to the canonical executable classifier"
else
  fail "agent-pipeline.md must point to verify-pr.sh without a trigger mirror"
fi

# PR completion / outcome evidence lives in the PR template.
if grep -q '^## User outcome evidence' .github/pull_request_template.md 2>/dev/null \
  && grep -q 'Implementation SHA:' .github/pull_request_template.md 2>/dev/null; then
  pass "PR template requires auditable user outcome evidence"
else
  fail "pull_request_template.md missing auditable outcome evidence"
fi

# AGENTS.md preserves outcome evidence and the specialized adapter.
if grep -q 'docs/guides/outcome-validation.md' AGENTS.md 2>/dev/null \
  && grep -q 'sandbox-verification.md' AGENTS.md 2>/dev/null \
  && ! grep -q 'Sandbox issue:' AGENTS.md 2>/dev/null; then
  pass "AGENTS.md requires outcome evidence and conditional sandbox use"
else
  fail "AGENTS.md missing outcome evidence or adapter guidance"
fi

echo ""
