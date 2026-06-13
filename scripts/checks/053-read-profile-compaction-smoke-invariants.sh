#!/usr/bin/env bash
# scripts/checks/053-read-profile-compaction-smoke-invariants.sh — smoke harness wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking read-profile compaction smoke invariants..."

  SMOKE_RUNNER="scripts/smoke/read-profile-compaction-smoke.sh"
  SMOKE_VALIDATE="scripts/smoke/validate-read-profile-compaction-smoke.sh"
  SMOKE_EXTRACT="scripts/smoke/extract-cursor-agent-text.py"
  SMOKE_PROMPT=".github/prompts/read-profile-compaction-smoke.md"
  SMOKE_WORKFLOW=".github/workflows/smoke-read-profile-compaction.yml"
  FIXTURE_A="scripts/tests/fixtures/read-profile-smoke/phase-a-pass.txt"
  FIXTURE_B="scripts/tests/fixtures/read-profile-smoke/phase-b-pass.txt"
  FIXTURE_C="scripts/tests/fixtures/read-profile-smoke/phase-c-pass.txt"

  for f in "$SMOKE_RUNNER" "$SMOKE_VALIDATE" "$SMOKE_EXTRACT" "$SMOKE_PROMPT" "$SMOKE_WORKFLOW" \
    "$FIXTURE_A" "$FIXTURE_B" "$FIXTURE_C"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (read-profile compaction smoke)"
    fi
  done

  if grep -q 'Scenario E — Post-compaction read profile' .github/prompts/handshake-and-shape-smoke.md 2>/dev/null \
    && awk '/^## Scenario E/{c++} END{exit (c==1)?0:1}' .github/prompts/handshake-and-shape-smoke.md; then
    pass "handshake-and-shape-smoke has single Scenario E block"
  else
    fail "handshake-and-shape-smoke Scenario E missing or duplicated"
  fi

  if bash -n "$SMOKE_RUNNER" 2>/dev/null && bash -n "$SMOKE_VALIDATE" 2>/dev/null; then
    pass "read-profile smoke shell scripts have valid bash syntax"
  else
    fail "read-profile smoke shell script bash -n failed"
  fi

  if bash "$SMOKE_VALIDATE" A "$FIXTURE_A" >/dev/null 2>&1 \
    && bash "$SMOKE_VALIDATE" B "$FIXTURE_B" >/dev/null 2>&1 \
    && bash "$SMOKE_VALIDATE" C "$FIXTURE_C" >/dev/null 2>&1; then
    pass "validator accepts phase A/B/C fixtures"
  else
    fail "read-profile smoke validator rejected fixture(s)"
  fi

  echo ""
  return 0
fi

echo "053-read-profile-compaction-smoke-invariants.sh is sourced by test.sh only" >&2
exit 1
