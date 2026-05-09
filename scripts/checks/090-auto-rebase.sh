#!/usr/bin/env bash
# scripts/checks/090-auto-rebase.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root. Bats invocation
# is wrapped by run_bats_check() from scripts/lib/bats-helpers.sh (issue #280).

# --- Auto-rebase-on-merge Library Tests (#116) ---
# Exercises the library used by .github/workflows/auto-rebase-on-merge.yml
# (should_rebase_pr / attempt_rebase / format_*_comment). If these
# regress, the workflow could force-push to PRs it shouldn't or fail to
# act on PRs it should. Hard-fail keeps regressions out of CI.
echo "Running auto-rebase-on-merge unit tests..."
run_bats_check scripts/tests/auto-rebase-overlapping.bats

echo ""
