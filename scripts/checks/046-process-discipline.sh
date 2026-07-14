#!/usr/bin/env bash
# Verify the consolidated operating contract after ADR-026 retirement.

echo "Checking process discipline contract..."

required_sections=(
  "Startup"
  "Truth hierarchy"
  "Execution model"
  "Work style"
  "Code quality"
  "Testing and validation"
  "Documentation synchronization"
  "Clarification and critical thinking"
  "Session and handoff state"
  "Opportunity feedback"
  "Reviews"
)

for section in "${required_sections[@]}"; do
  if grep -qF "## $section" AGENTS.md; then
    pass "AGENTS.md contains $section"
  else
    fail "AGENTS.md missing $section"
  fi
done

if grep -qF "context-receipt tables" AGENTS.md \
  && ! grep -qF 'plan_compliance:' AGENTS.md \
  && ! grep -qF 'parent_compliance:' AGENTS.md \
  && ! grep -qF 'subagent_compliance:' AGENTS.md; then
  pass "AGENTS.md keeps handshake-only startup evidence"
else
  fail "AGENTS.md still requires structured compliance evidence"
fi

echo ""
