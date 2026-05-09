#!/usr/bin/env bash
# scripts/checks/105-scripts.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Scripts Check ---
echo "Checking scripts..."

SCRIPT_FILES=(
  "scripts/README.md"
  "scripts/setup.sh"
  "scripts/verify-env.sh"
  "scripts/verify-pr.sh"
  "scripts/db-reset.sh"
  "scripts/auto-rebase-overlapping.sh"
  "scripts/multi-dispatch-safety.sh"
  "scripts/parse-ownership-table.sh"
  "scripts/pr-iteration-stats.sh"
)

for file in "${SCRIPT_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

# Check scripts are executable
for script in scripts/*.sh; do
  [ -f "$script" ] || continue
  if [[ -x "$script" ]]; then
    pass "$script is executable"
  else
    warn "$script is not executable"
  fi
done

echo ""
