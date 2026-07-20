#!/usr/bin/env bash
# Sourced by test.sh; relies on pass()/fail() and CWD == repo root.

echo "Checking generated governance surfaces..."

if python3 scripts/generate-pap-catalog.py --repo . --check; then
  pass "generated P/AP catalog is current"
else
  fail "generated P/AP catalog is stale"
fi

echo ""
