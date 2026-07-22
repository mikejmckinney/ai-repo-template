#!/usr/bin/env bash
# scripts/checks/010-required-files.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Public Entrypoints Check ---
echo "Checking public entrypoints..."

REQUIRED_FILES=(
  "AI_REPO_GUIDE.md"
  "AGENTS.md"
  "AGENT.md"
  "CLAUDE.md"
  "README.md"
  "DESIGN.md"
  "install.sh"
  "test.sh"
  ".cursorignore"
  ".github/prompts/README.md"
  ".github/prompts/capture-postmortem.md"
  ".github/prompts/mirror-postmortem.md"
  ".github/prompts/shared-review-lenses.md"
  ".github/CODEOWNERS"
  ".github/pull_request_template.md"
  ".github/PLAN_TEMPLATE.md"
  ".github/ISSUE_TEMPLATE/bug_report.md"
  ".github/ISSUE_TEMPLATE/feature_request.md"
  ".github/ISSUE_TEMPLATE/agent_init.md"
  ".github/ISSUE_TEMPLATE/config.yml"
  ".github/workflows/agent-advisory-review.yml"
  ".github/workflows/agent-auto-merge.yml"
  ".github/workflows/agent-postmerge-retro.yml"
  ".github/workflows/agent-weekly-review.yml"
  ".github/workflows/ci-tests.yml"
  ".github/workflows/lint-and-format.yml"
  "scripts/setup.sh"
  "scripts/verify-env.sh"
  "scripts/verify-pr.sh"
  "scripts/diag-hang-snapshot.sh"
  "scripts/diag-sandbox.sh"
  "scripts/archive-opencode-database.sh"
  "scripts/cleanup-codespace-caches.sh"
  "scripts/diagnose-opencode-session.sh"
  "scripts/format.sh"
  "scripts/check-markdown-links.py"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

if [[ -f ".context/onboarding-state.json" ]]; then
  pass ".context/onboarding-state.json exists"
elif onboarding_result=$(".agents/skills/repo-onboarding/scripts/classify-mode.sh" --repo "$PWD" 2>&1); then
  if jq -e '
    .mode == "complete" and
    any(.warnings[]; contains("legacy derived repository"))
  ' <<<"$onboarding_result" >/dev/null; then
    warn "legacy derived repository has no onboarding state; backfill complete state after orientation"
  else
    fail ".context/onboarding-state.json is missing"
  fi
else
  fail ".context/onboarding-state.json is missing and onboarding classification failed: $onboarding_result"
fi

if printf '@AGENTS.md\n' | cmp -s - CLAUDE.md; then
  pass "CLAUDE.md is the exact AGENTS.md pointer"
else
  fail "CLAUDE.md must contain exactly @AGENTS.md followed by a newline"
fi

for retired_file in .pre-commit-config.yaml .pre-commit-config.yaml.template; do
  if [[ -e "$retired_file" ]]; then
    fail "$retired_file is retired but still present"
  else
    pass "$retired_file is absent"
  fi
done

echo ""
