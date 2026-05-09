#!/usr/bin/env bash
# scripts/checks/055-script-syntax.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Script Syntax Check ---
echo "Checking script syntax..."

if bash -n install.sh 2>/dev/null; then
  pass "install.sh has valid bash syntax"
else
  fail "install.sh has syntax errors"
fi

if bash -n test.sh 2>/dev/null; then
  pass "test.sh has valid bash syntax"
else
  fail "test.sh has syntax errors"
fi

echo ""
