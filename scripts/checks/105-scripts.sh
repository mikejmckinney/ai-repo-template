#!/usr/bin/env bash
# scripts/checks/105-scripts.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Scripts Check ---
echo "Checking scripts..."

# Check scripts are executable
for script in scripts/*.sh; do
  [ -f "$script" ] || continue
  if [[ -x "$script" ]]; then
    pass "$script is executable"
  else
    warn "$script is not executable"
  fi
done

# Skill instructions invoke these files directly, so a missing Git executable
# bit breaks the documented entrypoint before the script can report an error.
while IFS= read -r script; do
  if [[ -x "$script" ]]; then
    pass "$script is executable"
  else
    fail "$script is not executable"
  fi
done < <(find .opencode/skills -type f -path '*/scripts/*.sh' -print | sort)

echo ""
