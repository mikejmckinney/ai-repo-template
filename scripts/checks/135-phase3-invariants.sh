#!/usr/bin/env bash
# scripts/checks/135-phase3-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 3 invariants (issue #229 Phase 3 / pre-push Critic) ---
echo "Checking Phase 3 components (issue #229 Phase 3 / pre-push review)..."

PRE_PUSH_PROMPT=".github/prompts/pre-push-review.md"
if [[ -f "$PRE_PUSH_PROMPT" ]]; then
  # Frontmatter present (the prompts/README schema).
  if head -1 "$PRE_PUSH_PROMPT" | grep -q '^---$'; then
    pass "$PRE_PUSH_PROMPT has YAML frontmatter"
  else
    fail "$PRE_PUSH_PROMPT missing YAML frontmatter (prompts/README schema)"
  fi
fi

# "Work style" rule references the prompt as a SHOULD (now in process_work_style.md per ADR-021).
if grep -q 'pre-push-review.md' .context/rules/process_work_style.md 2>/dev/null \
  && grep -q 'SHOULD' .context/rules/process_work_style.md 2>/dev/null \
  && grep -q 'non-trivial' .context/rules/process_work_style.md 2>/dev/null; then
  pass "process_work_style.md references pre-push-review.md (issue #229 Phase 3)"
else
  fail "process_work_style.md missing pre-push-review.md SHOULD reference (issue #229 Phase 3)"
fi

# DevOps role MUSTs the prompt for shell/workflow changes. Role definition
# lives at .agents/devops.md (canonical, ADR-023).
if grep -q 'pre-push-review.md' .agents/devops.md 2>/dev/null \
  && grep -q 'MUST' .agents/devops.md 2>/dev/null; then
  pass ".agents/devops.md MUSTs pre-push-review.md for shell/workflow changes"
else
  fail ".agents/devops.md missing pre-push-review.md MUST (issue #229 Phase 3)"
fi

# Critic role documents the three invocation surfaces. Role definition
# lives at .agents/critic.md (canonical, ADR-023).
if grep -q 'PLAN-GATE' .agents/critic.md 2>/dev/null \
  && grep -q 'DIFF-GATE' .agents/critic.md 2>/dev/null \
  && grep -q 'PRE-PUSH' .agents/critic.md 2>/dev/null; then
  pass ".agents/critic.md documents PLAN-GATE / DIFF-GATE / PRE-PUSH surfaces"
else
  fail ".agents/critic.md missing PRE-PUSH invocation surface (issue #229 Phase 3)"
fi

# Prompts index lists the new prompt.
if grep -q 'pre-push-review.md' .github/prompts/README.md 2>/dev/null; then
  pass ".github/prompts/README.md indexes pre-push-review.md"
else
  fail ".github/prompts/README.md missing pre-push-review.md index entry"
fi

# agent-best-practices.md links to the prompt.
if grep -q 'pre-push-review.md' docs/guides/agent-best-practices.md 2>/dev/null; then
  pass "agent-best-practices.md links pre-push-review.md"
else
  fail "agent-best-practices.md missing pre-push-review.md link (issue #229 Phase 3)"
fi

echo ""
