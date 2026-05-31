#!/usr/bin/env bash
# scripts/checks/035-workflow-files.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Workflow Files Check ---
echo "Checking workflow files..."

WORKFLOW_FILES=(
  ".github/workflows/agent-assign-copilot.yml"
  ".github/workflows/agent-auto-merge.yml"
  ".github/workflows/agent-auto-ready.yml"
  ".github/workflows/agent-fix-reviews.yml"
  ".github/workflows/agent-multi-dispatch.yml"
  ".github/workflows/agent-parallelism-report.yml"
  ".github/workflows/agent-relay-reviews.yml"
  ".github/workflows/agent-release-slot.yml"
  ".github/workflows/agent-review-on-push.yml"
  ".github/workflows/auto-rebase-on-merge.yml"
  ".github/workflows/backlog-to-issues.yml"
  ".github/workflows/ci-tests.yml"
  ".github/workflows/claude.yml"
  ".github/workflows/keep-warm.yml"
  ".github/workflows/lint-and-format.yml"
  ".github/workflows/validate-connections.yml"
)

for file in "${WORKFLOW_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

echo ""
