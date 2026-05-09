#!/usr/bin/env bash
# scripts/checks/145-workflow-secret-guard.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Workflow Secret Guard Check (issue #162) ---
# Every workflow that references secrets.CLAUDE_PAT or
# secrets.ANTHROPIC_API_KEY must contain a "Verify required secrets"
# step so derived repos missing those secrets get an actionable error
# instead of an obscure `gh: set GH_TOKEN` failure deep in a step.
echo "Checking workflow secret-presence guards..."
for wf in .github/workflows/*.yml; do
  [[ -f "$wf" ]] || continue
  if grep -qE 'secrets\.(CLAUDE_PAT|ANTHROPIC_API_KEY)\b' "$wf"; then
    if grep -q 'Verify required secrets' "$wf"; then
      pass "$wf has Verify required secrets guard"
    else
      fail "$wf references CLAUDE_PAT/ANTHROPIC_API_KEY but is missing the 'Verify required secrets' guard step (issue #162)"
    fi
  fi
done

echo ""
