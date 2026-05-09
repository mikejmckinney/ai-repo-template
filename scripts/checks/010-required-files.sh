#!/usr/bin/env bash
# scripts/checks/010-required-files.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Required Files Check ---
echo "Checking required files..."

REQUIRED_FILES=(
  "AI_REPO_GUIDE.md"
  "AGENTS.md"
  "AGENT.md"
  "CLAUDE.md"
  "README.md"
  "install.sh"
  ".cursor/BUGBOT.md"
  ".gemini/styleguide.md"
  ".gemini/config.yaml"
  ".github/copilot-instructions.md"
  ".github/agents/judge.agent.md"
  ".github/agents/critic.agent.md"
  ".github/agents/architect.agent.md"
  ".github/agents/pm.agent.md"
  ".github/agents/frontend.agent.md"
  ".github/agents/backend.agent.md"
  ".github/agents/qa.agent.md"
  ".github/agents/devops.agent.md"
  ".github/agents/docs.agent.md"
  ".github/agents/analyst.agent.md"
  ".claude/agents/architect.md"
  ".claude/agents/judge.md"
  ".claude/agents/critic.md"
  ".claude/agents/pm.md"
  ".claude/agents/frontend.md"
  ".claude/agents/backend.md"
  ".claude/agents/qa.md"
  ".claude/agents/devops.md"
  ".claude/agents/docs.md"
  ".claude/agents/analyst.md"
  ".github/prompts/README.md"
  ".github/prompts/repo-onboarding.md"
  ".github/prompts/pr-resolve-all.md"
  ".github/prompts/expand-backlog-entry.md"
  ".github/prompts/capture-postmortem.md"
  ".github/prompts/mirror-postmortem.md"
  ".github/prompts/pre-push-review.md"
  ".github/pull_request_template.md"
  ".github/PLAN_TEMPLATE.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

echo ""
