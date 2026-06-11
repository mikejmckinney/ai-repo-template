#!/usr/bin/env bash
# scripts/checks/051-final-feedback-invariants.sh — PR 3 final feedback consolidation wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking final feedback consolidation invariants..."

  FINALIZE_WORKFLOW=".github/workflows/agent-review-finalize.yml"
  FINALIZE_PROMPT=".github/prompts/pr-final-feedback-consolidation.md"
  FEEDBACK_DIR="scripts/workflows/pr-feedback"
  COLLECT_SCRIPT="${FEEDBACK_DIR}/collect-pr-feedback.sh"
  RUN_SCRIPT="${FEEDBACK_DIR}/run-feedback-consolidation.sh"
  UPSERT_SCRIPT="scripts/workflows/advisory-review/upsert-pr-comment.sh"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  MARKER='ai-feedback-inbox:v1'

  for f in "$FINALIZE_WORKFLOW" "$FINALIZE_PROMPT" "$COLLECT_SCRIPT" "$RUN_SCRIPT" "$UPSERT_SCRIPT"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (final feedback consolidation)"
    fi
  done

  if grep -q 'implementation-complete' "$FINALIZE_WORKFLOW" 2>/dev/null; then
    pass "finalize workflow is label-gated by implementation-complete"
  else
    fail "finalize workflow missing implementation-complete gate"
  fi

  if grep -q 'workflow_dispatch' "$FINALIZE_WORKFLOW" 2>/dev/null \
    && grep -q 'inputs:' "$FINALIZE_WORKFLOW" 2>/dev/null; then
    pass "finalize workflow supports manual workflow_dispatch"
  else
    fail "finalize workflow must support workflow_dispatch with PR input"
  fi

  if grep -q 'pull-requests: write' "$FINALIZE_WORKFLOW" 2>/dev/null; then
    pass "finalize workflow grants pull-requests: write for PR comment API"
  else
    fail "finalize workflow missing pull-requests: write"
  fi

  if grep -q 'scripts/workflows/pr-feedback/run-feedback-consolidation.sh' "$FINALIZE_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes scripts/workflows/pr-feedback (AP8)"
  else
    fail "workflow must invoke scripts/workflows/pr-feedback/run-feedback-consolidation.sh"
  fi

  if grep -q "$MARKER" "$FINALIZE_PROMPT" 2>/dev/null; then
    pass "finalize prompt defines sticky marker"
  else
    fail "finalize prompt missing $MARKER marker"
  fi

  if grep -q 'Must fix before merge' "$FINALIZE_PROMPT" 2>/dev/null \
    && grep -q 'Already resolved / stale feedback' "$FINALIZE_PROMPT" 2>/dev/null \
    && grep -q 'claude-fix' "$FINALIZE_PROMPT" 2>/dev/null; then
    pass "finalize prompt defines inbox sections and claude-fix interaction"
  else
    fail "finalize prompt missing required inbox sections"
  fi

  if grep -q '^implementation-complete|' "$LABELS_SCRIPT" 2>/dev/null; then
    pass "implementation-complete declared in label setup"
  else
    fail "implementation-complete missing from $LABELS_SCRIPT"
  fi

  if bash -n "$COLLECT_SCRIPT" 2>/dev/null && bash -n "$RUN_SCRIPT" 2>/dev/null; then
    pass "pr-feedback shell scripts have valid bash syntax"
  else
    fail "pr-feedback shell script bash -n failed"
  fi

  if grep -q 'advisory-comments.md' "$COLLECT_SCRIPT" 2>/dev/null \
    && grep -q 'reviews.json' "$COLLECT_SCRIPT" 2>/dev/null; then
    pass "collect-pr-feedback emits expected artifact files"
  else
    fail "collect-pr-feedback.sh must write advisory-comments.md and reviews.json"
  fi

  echo ""
  return 0
fi

echo "051-final-feedback-invariants.sh is sourced by test.sh only" >&2
exit 1
