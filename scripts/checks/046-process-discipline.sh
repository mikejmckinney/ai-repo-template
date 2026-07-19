#!/usr/bin/env bash
# Verify the consolidated operating contract after ADR-026 retirement.

echo "Checking process discipline contract..."

required_sections=(
  "Truth hierarchy"
  "Execution model"
  "Domain: Code Quality"
  "Clarification and ambiguity"
  "Critical thinking and communication"
  "Opportunity feedback channel"
  "Session-state cadence"
  "Work style, testing, validation"
  "Reviews"
  "Repo Orchestration Patterns"
)

for section in "${required_sections[@]}"; do
  if grep -qF "## $section" AGENTS.md; then
    pass "AGENTS.md contains $section"
  else
    fail "AGENTS.md missing $section"
  fi
done

if ! grep -qF 'Session handshake' AGENTS.md \
  && ! grep -qF 'plan_compliance:' AGENTS.md \
  && ! grep -qF 'parent_compliance:' AGENTS.md \
  && ! grep -qF 'subagent_compliance:' AGENTS.md; then
  pass "AGENTS.md omits retired handshake and structured compliance evidence"
else
  fail "AGENTS.md still requires retired handshake or structured compliance evidence"
fi

if ! grep -qF 'role_relevance' AGENTS.md \
  && ! grep -qF 'role_relevance' .context/state/agent_state_comment_template.md \
  && ! grep -qF 'role_relevance' docs/guides/opportunity-feedback-examples.md \
  && grep -qF 'Amendment 2026-07-14' docs/decisions/adr-027-opportunity-feedback-channel.md; then
  pass "opportunity feedback uses the amended role-free field set"
else
  fail "opportunity feedback role-free field set is not synchronized"
fi

if grep -qF 'implementation-plan:v2:begin' .github/PLAN_TEMPLATE.md \
  && grep -qF 'implementation-plan:v2:end' .github/PLAN_TEMPLATE.md \
  && grep -qF 'implementation-plan:v2:begin' .github/ISSUE_TEMPLATE/feature_request.md \
  && grep -qF 'implementation-plan:v2:begin' .github/ISSUE_TEMPLATE/bug_report.md \
  && grep -qF 'implementation-plan:v2:begin' .github/ISSUE_TEMPLATE/agent_init.md \
  && grep -qF 'Revision history' .github/PLAN_TEMPLATE.md \
  && grep -qF 'Canonical plan:' .github/pull_request_template.md \
  && ! grep -qF 'Original plan:' .github/pull_request_template.md \
  && ! grep -qF 'Revisions:' .github/pull_request_template.md; then
  pass "new issues use one mutable plan block and retain one canonical PR pointer"
else
  fail "implementation plan templates missing the v2 issue-body contract"
fi

if grep -qF 'empty bootstrap commit' AGENTS.md \
  && grep -qF 'commit and push' AGENTS.md \
  && grep -qF 'before updating' AGENTS.md; then
  pass "work becomes durable before each changed-turn state update"
else
  fail "AGENTS.md missing early draft/checkpoint durability ordering"
fi

RECOVERY_SKILL=.agents/skills/session-recovery/SKILL.md
if grep -qF 'active issue' "$RECOVERY_SKILL" \
  && grep -qF 'linked PR' "$RECOVERY_SKILL" \
  && grep -qF 'agent-state:v1' "$RECOVERY_SKILL" \
  && grep -qF 'offline' "$RECOVERY_SKILL"; then
  pass "session recovery requires GitHub hydration with an offline fallback"
else
  fail "session recovery does not require current issue/PR/live-state hydration"
fi

echo ""
