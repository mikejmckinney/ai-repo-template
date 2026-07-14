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
  "README.md"
  "DESIGN.md"
  "install.sh"
  ".github/prompts/README.md"
  ".github/prompts/capture-postmortem.md"
  ".github/prompts/mirror-postmortem.md"
  ".github/prompts/shared-review-lenses.md"
  ".github/pull_request_template.md"
  ".github/PLAN_TEMPLATE.md"
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
