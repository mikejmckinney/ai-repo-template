#!/usr/bin/env bash
# scripts/checks/090-auto-rebase.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Auto-rebase-on-merge Library Tests (#116) ---
# Exercises the library used by .github/workflows/auto-rebase-on-merge.yml
# (should_rebase_pr / attempt_rebase / format_*_comment). If these
# regress, the workflow could force-push to PRs it shouldn't or fail to
# act on PRs it should. Hard-fail keeps regressions out of CI.
echo "Running auto-rebase-on-merge unit tests..."
if [[ -f scripts/tests/auto-rebase-overlapping.bats ]]; then
  ARO_LOG=$(mktemp)
  if bats --tap scripts/tests/auto-rebase-overlapping.bats >"$ARO_LOG" 2>&1; then
    aro_passed=$(grep -c '^ok ' "$ARO_LOG" || true)
    pass "scripts/tests/auto-rebase-overlapping.bats ($aro_passed tests passed)"
  else
    fail "scripts/tests/auto-rebase-overlapping.bats failed (see log below)"
    cat "$ARO_LOG"
  fi
  rm -f "$ARO_LOG"
else
  fail "scripts/tests/auto-rebase-overlapping.bats missing"
fi

echo ""
