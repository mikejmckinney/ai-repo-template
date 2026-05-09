#!/usr/bin/env bash
# scripts/checks/070-phase4-fallback-parser.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 4 fallback parser unit tests (issue #108 regression cover) ---
echo "Running Phase 4 fallback parser unit tests..."
if [[ -f scripts/test-phase4-fallback-parser.sh ]]; then
  PARSER_LOG=$(mktemp)
  if bash scripts/test-phase4-fallback-parser.sh >"$PARSER_LOG" 2>&1; then
    parser_passed=$(grep -c '^  ✅ ' "$PARSER_LOG" || true)
    pass "scripts/test-phase4-fallback-parser.sh ($parser_passed assertions passed)"
  else
    fail "scripts/test-phase4-fallback-parser.sh failed (see log below)"
    cat "$PARSER_LOG"
  fi
  rm -f "$PARSER_LOG"
else
  fail "scripts/test-phase4-fallback-parser.sh missing"
fi

echo ""
