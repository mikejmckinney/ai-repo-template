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

if grep -qF 'implementation-plan:v1' .github/PLAN_TEMPLATE.md \
  && grep -qiF 'edit' .github/PLAN_TEMPLATE.md \
  && grep -qF 'Revision history' .github/PLAN_TEMPLATE.md \
  && grep -qF 'Canonical plan:' .github/pull_request_template.md \
  && ! grep -qF 'Original plan:' .github/pull_request_template.md \
  && ! grep -qF 'Revisions:' .github/pull_request_template.md; then
  pass "implementation plans use one mutable canonical comment"
else
  fail "implementation plan templates still permit fragmented revision comments"
fi

RECOVERY_SKILL=.opencode/skills/session-recovery/SKILL.md
if grep -qF 'active issue' "$RECOVERY_SKILL" \
  && grep -qF 'linked PR' "$RECOVERY_SKILL" \
  && grep -qF 'agent-state:v1' "$RECOVERY_SKILL" \
  && grep -qF 'offline' "$RECOVERY_SKILL"; then
  pass "session recovery requires GitHub hydration with an offline fallback"
else
  fail "session recovery does not require current issue/PR/live-state hydration"
fi

if grep -qF '### Post-compaction recovery gate' AGENTS.md \
  && grep -qF 'session-recovery' AGENTS.md \
  && grep -qF 'exact session ID' AGENTS.md \
  && grep -qF 'post-compaction' AGENTS.md \
  && grep -qF 'Do not treat the compaction summary alone as sufficient context' AGENTS.md; then
  pass "AGENTS.md blocks post-compaction work until exact-session recovery"
else
  fail "AGENTS.md lacks the mandatory post-compaction recovery gate"
fi

echo ""
