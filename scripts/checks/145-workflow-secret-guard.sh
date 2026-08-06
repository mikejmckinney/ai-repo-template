#!/usr/bin/env bash
# scripts/checks/145-workflow-secret-guard.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Workflow Secret Guard Check (issue #162) ---
echo "Checking workflow secret-presence guards..."

if grep -q '^\.env$' .gitignore 2>/dev/null; then
  pass ".gitignore excludes the standalone .env secret file"
else
  fail ".gitignore must exclude the standalone .env secret file"
fi

_claude_pat_refs=$(git grep -n 'CLAUDE_PAT' -- \
  .github/workflows scripts docs/guides AGENTS.md AI_REPO_GUIDE.md 2>/dev/null || true)
_claude_pat_refs=$(printf '%s\n' "$_claude_pat_refs" \
  | grep -v '^scripts/checks/145-workflow-secret-guard.sh:' || true)
if [[ -z "$_claude_pat_refs" ]]; then
  pass "active automation uses job-scoped GitHub tokens instead of CLAUDE_PAT"
else
  fail "active automation still references retired CLAUDE_PAT"
  printf '%s\n' "$_claude_pat_refs"
fi

# Workflows using an Anthropic model credential must fail clearly when the
# credential is absent instead of surfacing an obscure provider error later.
for wf in .github/workflows/*.yml; do
  [[ -f "$wf" ]] || continue
  if grep -qE 'secrets\.ANTHROPIC_API_KEY\b' "$wf"; then
    if grep -q 'Verify required secrets' "$wf"; then
      pass "$wf has Verify required secrets guard"
    else
      fail "$wf references ANTHROPIC_API_KEY but is missing the 'Verify required secrets' guard step (issue #162)"
    fi
  fi
done

echo ""
