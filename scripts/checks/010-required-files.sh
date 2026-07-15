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
  "README.md"
  "DESIGN.md"
  "install.sh"
  "test.sh"
  ".cursorignore"
  ".pre-commit-config.yaml.template"
  ".github/prompts/README.md"
  ".github/prompts/capture-postmortem.md"
  ".github/prompts/mirror-postmortem.md"
  ".github/prompts/shared-review-lenses.md"
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
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

echo ""
