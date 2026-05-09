#!/usr/bin/env bash
# scripts/checks/115-phase15-invariants.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Phase 1.5 invariants (issue #229 Phase 1.5) ---
echo "Checking Phase 1.5 components (issue #229 Phase 1.5)..."

if [[ -f "scripts/lint-shell-conventions.sh" ]] && [[ -x "scripts/lint-shell-conventions.sh" ]]; then
  pass "scripts/lint-shell-conventions.sh exists and is executable"
else
  fail "scripts/lint-shell-conventions.sh missing or not executable (issue #229 Phase 1.5c)"
fi

if grep -q 'bash scripts/lint-shell-conventions.sh' "$LF_FILE" 2>/dev/null; then
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
if [[ -f scripts/test-jq-filters.sh ]]; then
  JQ_LOG=$(mktemp)
  if bash scripts/test-jq-filters.sh >"$JQ_LOG" 2>&1; then
    jq_passed=$(grep -c '^  ✅ ' "$JQ_LOG" || true)
    pass "scripts/test-jq-filters.sh ($jq_passed assertions passed)"
  else
    fail "scripts/test-jq-filters.sh failed (see log below)"
    cat "$JQ_LOG"
  fi
  rm -f "$JQ_LOG"
else
  fail "scripts/test-jq-filters.sh missing"
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
if [[ -x scripts/test-closeout.sh ]]; then
  pass "scripts/test-closeout.sh present and executable"
else
  fail "scripts/test-closeout.sh missing or not executable"
fi
if [[ -f scripts/test-closeout.sh ]]; then
  CO_LOG=$(mktemp)
  if bash scripts/test-closeout.sh >"$CO_LOG" 2>&1; then
    co_passed=$(grep -c '^  ✅ ' "$CO_LOG" || true)
    pass "scripts/test-closeout.sh ($co_passed assertions passed)"
  else
    fail "scripts/test-closeout.sh failed (see log below)"
    cat "$CO_LOG"
  fi
  rm -f "$CO_LOG"
else
  fail "scripts/test-closeout.sh missing"
fi

echo ""
echo "Running verify-env.sh fixture tests..."
if [[ -f scripts/test-verify-env.sh ]]; then
  VE_LOG=$(mktemp)
  if bash scripts/test-verify-env.sh >"$VE_LOG" 2>&1; then
    ve_passed=$(grep -c '^  ✅ ' "$VE_LOG" || true)
    pass "scripts/test-verify-env.sh ($ve_passed assertions passed)"
  else
    fail "scripts/test-verify-env.sh failed (see log below)"
    cat "$VE_LOG"
  fi
  rm -f "$VE_LOG"
else
  fail "scripts/test-verify-env.sh missing"
fi

echo ""
echo "Running ADR-018 multi-task _active.md smoke test..."
if [[ -f scripts/test-active-md-multitask.sh ]]; then
  AMT_LOG=$(mktemp)
  if bash scripts/test-active-md-multitask.sh >"$AMT_LOG" 2>&1; then
    amt_passed=$(grep -c '^PASS \[' "$AMT_LOG" || true)
    pass "scripts/test-active-md-multitask.sh ($amt_passed scenarios passed)"
  else
    fail "scripts/test-active-md-multitask.sh failed (see log below)"
    cat "$AMT_LOG"
  fi
  rm -f "$AMT_LOG"
else
  fail "scripts/test-active-md-multitask.sh missing"
fi

echo ""
echo "Running verify-pr.sh classifier fixture tests (issue #227)..."
if [[ -f scripts/test-verify-pr.sh ]]; then
  VPR_LOG=$(mktemp)
  if bash scripts/test-verify-pr.sh >"$VPR_LOG" 2>&1; then
    vpr_passed=$(grep -c '^  ✅ ' "$VPR_LOG" || true)
    pass "scripts/test-verify-pr.sh ($vpr_passed assertions passed)"
  else
    fail "scripts/test-verify-pr.sh failed (see log below)"
    cat "$VPR_LOG"
  fi
  rm -f "$VPR_LOG"
else
  fail "scripts/test-verify-pr.sh missing"
fi

echo ""
