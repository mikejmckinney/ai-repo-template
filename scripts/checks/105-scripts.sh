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

# Repository-owned skill instructions invoke their scripts directly. External
# package modes must instead remain identical to the deterministic lock hash.
while IFS= read -r destination; do
  while IFS= read -r script; do
    if [[ -x "$script" ]]; then
      pass "$script is executable"
    else
      fail "$script is not executable"
    fi
  done < <(find "$destination" -type f -path '*/scripts/*.sh' -print | sort)
done < <(jq -r '.ownedSkills[].destinationPath' skills-lock.json)

echo ""
