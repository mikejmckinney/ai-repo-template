#!/usr/bin/env bash
# scripts/checks/075-parallelism-report-parser.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Parallelism report parser unit tests (issue #49 / ADR-009) ---
# Includes a live-format assertion against agent_ownership.md so that
# format-changing PRs to the ownership table fail CI at the change PR
# rather than at the next overlap report.
echo "Running parallelism report parser unit tests..."
if [[ -f scripts/test-parallelism-report-parser.sh ]]; then
  PR_PARSER_LOG=$(mktemp)
  if bash scripts/test-parallelism-report-parser.sh >"$PR_PARSER_LOG" 2>&1; then
    pr_parser_passed=$(grep -c '^  ✅ ' "$PR_PARSER_LOG" || true)
    pass "scripts/test-parallelism-report-parser.sh ($pr_parser_passed assertions passed)"
  else
    fail "scripts/test-parallelism-report-parser.sh failed (see log below)"
    cat "$PR_PARSER_LOG"
  fi
  rm -f "$PR_PARSER_LOG"
else
  fail "scripts/test-parallelism-report-parser.sh missing"
fi

echo ""
