#!/usr/bin/env bash
# scripts/checks/060-markdown-structure.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Markdown Structure Checks ---
echo "Checking markdown structure..."

# Check that key files have headers
for file in AI_REPO_GUIDE.md AGENTS.md README.md .context/00_INDEX.md; do
  if [[ -f "$file" ]] && head -5 "$file" | grep -q "^#"; then
    pass "$file has a header"
  else
    warn "$file missing header"
  fi
done

echo ""
