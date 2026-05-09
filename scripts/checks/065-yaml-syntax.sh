#!/usr/bin/env bash
# scripts/checks/065-yaml-syntax.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- YAML Syntax Check ---
echo "Checking workflow YAML syntax..."

# Basic YAML check (just verifies files aren't completely broken)
for file in .github/workflows/*.yml; do
  if [[ -f "$file" ]]; then
    # Check for common YAML issues. Pattern is start-anchored (^), no end
    # anchor needed since we accept any content after `name:` or `#`.
    # shell-conventions:disable=RULE-02 reason: start-anchored, no substring-match risk
    if head -1 "$file" | grep -qE "^(name:|#).*"; then
      pass "$file has valid YAML header"
    else
      warn "$file may have YAML issues"
    fi
  fi
done

echo ""
