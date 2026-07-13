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

# Plan template carries the Change class + Verification target lines.
if grep -q 'Change class' .github/PLAN_TEMPLATE.md 2>/dev/null \
  && grep -q 'Verification target' .github/PLAN_TEMPLATE.md 2>/dev/null; then
  pass ".github/PLAN_TEMPLATE.md exposes Change class + Verification target (issue #227)"
else
  fail ".github/PLAN_TEMPLATE.md missing Change class / Verification target (issue #227)"
fi

# Sandbox playbook lives at the documented path.
if [[ -f docs/guides/sandbox-verification.md ]]; then
  pass "docs/guides/sandbox-verification.md exists (issue #227 Phase 2)"
else
  fail "docs/guides/sandbox-verification.md missing (issue #227 Phase 2)"
fi

# Trigger-event matrix lives in agent-pipeline.md.
if grep -q 'Workflow verifiability matrix' docs/guides/agent-pipeline.md 2>/dev/null; then
  pass "agent-pipeline.md documents the Workflow verifiability matrix (issue #227)"
else
  fail "agent-pipeline.md missing Workflow verifiability matrix (issue #227)"
fi

# PR completion / pre-merge verification lives in PR template and resolve prompt (ADR-031).
if grep -q 'sandbox-verification.md' .github/pull_request_template.md 2>/dev/null \
  || grep -q 'pre-merge verification' .github/prompts/pr-resolve-all.md 2>/dev/null; then
  pass "PR surfaces reference pre-merge verification (issue #227)"
else
  fail "pull_request_template.md or pr-resolve-all.md missing pre-merge verification reference (issue #227)"
fi

# pr-resolve-all.md Phase 2 calls out the sandbox path.
if grep -q 'sandbox-verification.md' .github/prompts/pr-resolve-all.md 2>/dev/null \
  || grep -q 'default-branch-only workflow' .github/prompts/pr-resolve-all.md 2>/dev/null; then
  pass "pr-resolve-all.md Phase 2 references the sandbox verification path (issue #227)"
else
  fail "pr-resolve-all.md missing sandbox-verification callout (issue #227)"
fi

# AGENTS.md ties workflow verification changes to the classifier and sandbox guide.
if grep -q 'scripts/verify-pr.sh' AGENTS.md 2>/dev/null \
  && grep -q 'sandbox verification guide' AGENTS.md 2>/dev/null; then
  pass "AGENTS.md links verify-pr.sh + sandbox verification (issue #227)"
else
  fail "AGENTS.md missing issue-#227 workflow verification guidance"
fi

echo ""
