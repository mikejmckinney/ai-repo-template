#!/usr/bin/env bash
# scripts/checks/095-issue-templates.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Issue Templates Check ---
echo "Checking issue templates..."

ISSUE_TEMPLATES=(
  ".github/ISSUE_TEMPLATE/bug_report.md"
  ".github/ISSUE_TEMPLATE/feature_request.md"
  ".github/ISSUE_TEMPLATE/agent_init.md"
  ".github/ISSUE_TEMPLATE/config.yml"
)

for file in "${ISSUE_TEMPLATES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

echo ""
