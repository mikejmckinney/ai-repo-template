#!/usr/bin/env bash
# scripts/checks/115-phase15-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 1.5 invariants (issue #229 Phase 1.5) ---
echo "Checking Phase 1.5 components (issue #229 Phase 1.5)..."

# Define LF_FILE locally so this module is self-contained and does not
# depend on 110-lint-format-invariants.sh having sourced first. (R1
# finding: cross-module variable coupling.) Keep the path identical to
# the one in 110- so behavior is unchanged.
LF_FILE=".github/workflows/lint-and-format.yml"

if [[ -f "scripts/lint-shell-conventions.sh" ]] && [[ -x "scripts/lint-shell-conventions.sh" ]]; then
  pass "scripts/lint-shell-conventions.sh exists and is executable"
else
  fail "scripts/lint-shell-conventions.sh missing or not executable (issue #229 Phase 1.5c)"
fi

if [[ -f "$LF_FILE" ]] && grep -q 'bash scripts/lint-shell-conventions.sh' "$LF_FILE"; then
  pass "$LF_FILE has lint-shell-conventions run step (issue #229 Phase 1.5c)"
else
  fail "$LF_FILE missing lint-shell-conventions run step (issue #229 Phase 1.5c)"
fi

if [[ -d "scripts/lib/jq" ]] && compgen -G "scripts/lib/jq/*.jq" >/dev/null 2>&1; then
  pass "scripts/lib/jq/ directory exists with at least one .jq filter"
else
  fail "scripts/lib/jq/ missing or empty (issue #229 Phase 1.5b)"
fi

# ISS-09: inline relay-cycle-count filter in agent-relay-reviews.yml must stay
# in sync with the canonical scripts/lib/jq/relay-cycle-count.jq.
# The relay job has no actions/checkout so jq -rf cannot read the file at
# runtime; the inline copy is intentional. This check prevents silent drift.
_RELAY_JQ="scripts/lib/jq/relay-cycle-count.jq"
_RELAY_WF=".github/workflows/agent-relay-reviews.yml"
if [[ -f "$_RELAY_JQ" ]] && [[ -f "$_RELAY_WF" ]]; then
  _canonical=$(grep -v '^#' "$_RELAY_JQ" | grep -v '^[[:space:]]*$')
  _inline=$(grep 'startswith("📋' "$_RELAY_WF" \
    | grep '| length' \
    | sed 's/.*jq -r //' \
    | sed "s/^'//; s/' \\\\$//; s/'$//")
  if [[ "$_canonical" == "$_inline" ]]; then
    pass "relay-cycle-count.jq matches inline filter in agent-relay-reviews.yml (ISS-09)"
  else
    fail "relay-cycle-count.jq is out of sync with inline filter in agent-relay-reviews.yml (ISS-09)"
    printf '  canonical: %s\n' "$_canonical"
    printf '  inline:    %s\n' "$_inline"
  fi
else
  fail "$_RELAY_JQ or $_RELAY_WF missing (ISS-09 sync check)"
fi
unset _RELAY_JQ _RELAY_WF _canonical _inline

for reviewer_file in ".github/agents/judge.agent.md" ".cursor/BUGBOT.md" ".gemini/styleguide.md"; do
  if grep -qi 'diff-coupling' "$reviewer_file" 2>/dev/null; then
    pass "$reviewer_file has diff-coupling gate (issue #229 Phase 1.5)"
  else
    fail "$reviewer_file missing diff-coupling gate (issue #229 Phase 1.5)"
  fi
done

echo ""
echo "Running jq filter unit tests..."
if [[ -f scripts/tests/jq-filters.bats ]]; then
  JQ_LOG=$(mktemp)
  if bats --tap scripts/tests/jq-filters.bats >"$JQ_LOG" 2>&1; then
    jq_passed=$(grep -c '^ok ' "$JQ_LOG" || true)
    pass "scripts/tests/jq-filters.bats ($jq_passed tests passed)"
  else
    fail "scripts/tests/jq-filters.bats failed (see log below)"
    cat "$JQ_LOG"
  fi
  rm -f "$JQ_LOG"
else
  fail "scripts/tests/jq-filters.bats missing"
fi

echo ""
echo "Running closeout fixture tests (issue #262)..."
# Presence + executable-bit checks first; then the fixture run.
if [[ -f Makefile ]]; then
  if grep -qE '^closeout:' Makefile; then
    pass "Makefile defines 'closeout' target"
  else
    fail "Makefile missing 'closeout' target"
  fi
else
  fail "Makefile missing"
fi
if [[ -x scripts/closeout.sh ]]; then
  pass "scripts/closeout.sh present and executable"
else
  fail "scripts/closeout.sh missing or not executable"
fi
if [[ -f scripts/tests/closeout.bats ]]; then
  pass "scripts/tests/closeout.bats present"
else
  fail "scripts/tests/closeout.bats missing"
fi
if [[ -f scripts/tests/closeout.bats ]]; then
  CO_LOG=$(mktemp)
  if bats --tap scripts/tests/closeout.bats >"$CO_LOG" 2>&1; then
    co_passed=$(grep -c '^ok ' "$CO_LOG" || true)
    pass "scripts/tests/closeout.bats ($co_passed tests passed)"
  else
    fail "scripts/tests/closeout.bats failed (see log below)"
    cat "$CO_LOG"
  fi
  rm -f "$CO_LOG"
else
  fail "scripts/tests/closeout.bats missing"
fi

echo ""
echo "Running verify-env.sh fixture tests..."
if [[ -f scripts/tests/verify-env.bats ]]; then
  VE_LOG=$(mktemp)
  if bats --tap scripts/tests/verify-env.bats >"$VE_LOG" 2>&1; then
    ve_passed=$(grep -c '^ok ' "$VE_LOG" || true)
    pass "scripts/tests/verify-env.bats ($ve_passed tests passed)"
  else
    fail "scripts/tests/verify-env.bats failed (see log below)"
    cat "$VE_LOG"
  fi
  rm -f "$VE_LOG"
else
  fail "scripts/tests/verify-env.bats missing"
fi

echo ""
echo "Running ADR-018 multi-task _active.md smoke test..."
if [[ -f scripts/tests/active-md-multitask.bats ]]; then
  AMT_LOG=$(mktemp)
  if bats --tap scripts/tests/active-md-multitask.bats >"$AMT_LOG" 2>&1; then
    amt_passed=$(grep -c '^PASS \[' "$AMT_LOG" || true)
    pass "scripts/tests/active-md-multitask.bats ($amt_passed tests passed)"
  else
    fail "scripts/tests/active-md-multitask.bats failed (see log below)"
    cat "$AMT_LOG"
  fi
  rm -f "$AMT_LOG"
else
  fail "scripts/tests/active-md-multitask.bats missing"
fi

echo ""
echo "Running verify-pr.sh classifier fixture tests (issue #227)..."
if [[ -f scripts/tests/verify-pr.bats ]]; then
  VPR_LOG=$(mktemp)
  if bats --tap scripts/tests/verify-pr.bats >"$VPR_LOG" 2>&1; then
    vpr_passed=$(grep -c '^ok ' "$VPR_LOG" || true)
    pass "scripts/tests/verify-pr.bats ($vpr_passed tests passed)"
  else
    fail "scripts/tests/verify-pr.bats failed (see log below)"
    cat "$VPR_LOG"
  fi
  rm -f "$VPR_LOG"
else
  fail "scripts/tests/verify-pr.bats missing"
fi

echo ""
