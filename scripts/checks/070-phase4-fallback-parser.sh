#!/usr/bin/env bash
# scripts/checks/070-phase4-fallback-parser.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 4 fallback parser unit tests (issue #108 regression cover) ---
echo "Running Phase 4 fallback parser unit tests..."
if [[ -f scripts/tests/phase4-fallback-parser.bats ]]; then
  PARSER_LOG=$(mktemp)
  if bats --tap scripts/tests/phase4-fallback-parser.bats >"$PARSER_LOG" 2>&1; then
    parser_passed=$(grep -c '^ok ' "$PARSER_LOG" || true)
    pass "scripts/tests/phase4-fallback-parser.bats ($parser_passed tests passed)"
  else
    fail "scripts/tests/phase4-fallback-parser.bats failed (see log below)"
    cat "$PARSER_LOG"
  fi
  rm -f "$PARSER_LOG"
else
  fail "scripts/tests/phase4-fallback-parser.bats missing"
fi

echo ""
