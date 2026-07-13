#!/usr/bin/env bash
# scripts/checks/049-advisory-review-invariants.sh — PR 2 advisory review wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking advisory review invariants..."

  ADVISORY_WORKFLOW=".github/workflows/agent-advisory-review.yml"
  ADVISORY_PROMPT=".github/prompts/pr-advisory-review.md"
  ADVISORY_DIR="scripts/workflows/advisory-review"
  UPSERT_SCRIPT="${ADVISORY_DIR}/upsert-pr-comment.sh"
  RUN_SCRIPT="${ADVISORY_DIR}/run-advisory-review.sh"
  GEMINI_SCRIPT="${ADVISORY_DIR}/run-advisory-gemini.py"
  CURSOR_SCRIPT="${ADVISORY_DIR}/run-advisory-cursor.mjs"
  ANTIGRAVITY_SCRIPT="${ADVISORY_DIR}/run-advisory-antigravity.py"
  LABELS_SCRIPT="scripts/setup/40-ensure-labels.sh"
  MARKER='ai-advisory-review:v1'

  for f in "$ADVISORY_WORKFLOW" "$ADVISORY_PROMPT" "$UPSERT_SCRIPT" "$RUN_SCRIPT" \
    "$GEMINI_SCRIPT" "$CURSOR_SCRIPT" "$ANTIGRAVITY_SCRIPT"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (advisory review)"
    fi
  done

  if [[ -f .github/scripts/run-advisory-review.sh ]] \
    || compgen -G ".github/scripts/run-advisory-*" >/dev/null 2>&1; then
    fail "legacy advisory scripts still present under .github/scripts; use ${ADVISORY_DIR}/"
  else
    pass "advisory scripts not duplicated under .github/scripts (AP8)"
  fi

  if grep -q 'ai-review:live' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow is label-gated by ai-review:live"
  else
    fail "advisory workflow missing ai-review:live gate"
  fi

  if grep -q 'pull-requests: write' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow grants pull-requests: write for PR comment API"
  else
    fail "advisory workflow missing pull-requests: write (PR comment POST 403 risk)"
  fi

  if grep -q 'scripts/workflows/advisory-review/run-advisory-review.sh' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes scripts/workflows/advisory-review (AP8)"
  else
    fail "workflow must invoke scripts/workflows/advisory-review/run-advisory-review.sh"
  fi

  if grep -q 'antigravity' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q 'ADVISORY_ANTIGRAVITY_ENABLED' "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "workflow documents antigravity provider gate"
  else
    fail "workflow missing antigravity provider wiring"
  fi

  if grep -q "$MARKER" "$ADVISORY_PROMPT" 2>/dev/null; then
    pass "advisory prompt defines sticky marker"
  else
    fail "advisory prompt missing $MARKER marker"
  fi

  if grep -q 'Session handshake' "$ADVISORY_PROMPT" 2>/dev/null \
    && grep -q 'AGENTS.md' "$ADVISORY_PROMPT" 2>/dev/null \
    && grep -q 'Do not append a' "$ADVISORY_PROMPT" 2>/dev/null; then
    pass "advisory prompt requires the AGENTS.md handshake without a receipt table"
  else
    fail "advisory prompt must require the AGENTS.md handshake without receipt bookkeeping"
  fi

  if grep -q '^ai-review:live|' "$LABELS_SCRIPT" 2>/dev/null; then
    pass "ai-review:live declared in label setup"
  else
    fail "ai-review:live missing from $LABELS_SCRIPT"
  fi

  if grep -q '^implementation-complete|' "$LABELS_SCRIPT" 2>/dev/null; then
    pass "implementation-complete declared in label setup (PR 3 hook)"
  else
    fail "implementation-complete missing from $LABELS_SCRIPT"
  fi

  if grep -qF -- '-F body=@' "$UPSERT_SCRIPT" 2>/dev/null \
    && ! grep -qF -- '-f body=@' "$UPSERT_SCRIPT" 2>/dev/null; then
    pass "upsert-pr-comment uses gh api -F body=@ (not -f, which posts literal @path)"
  else
    fail "upsert-pr-comment.sh must use -F body=@ for file-loaded comment bodies"
  fi

  if bash -n "$UPSERT_SCRIPT" 2>/dev/null && bash -n "$RUN_SCRIPT" 2>/dev/null; then
    pass "advisory shell scripts have valid bash syntax"
  else
    fail "advisory shell script bash -n failed"
  fi

  if grep -q 'fast", value: "false"' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'GITHUB_RUN_ID' "$CURSOR_SCRIPT" 2>/dev/null \
    && grep -q 'buildCursorModelConfig' "$CURSOR_SCRIPT" 2>/dev/null; then
    pass "run-advisory-cursor.mjs pins composer-2.5 standard tier and logs GITHUB_RUN_ID context"
  else
    fail "run-advisory-cursor.mjs must set SDK fast=false for composer-2.5 and log workflow run context"
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x "$UPSERT_SCRIPT" "$RUN_SCRIPT" 2>/dev/null; then
      pass "advisory shell scripts pass shellcheck"
    else
      warn "advisory shell scripts shellcheck findings (non-fatal)"
    fi
  else
    warn "shellcheck not installed; skipped advisory script lint"
  fi

  if grep -q 'ai-review:full' "$ADVISORY_WORKFLOW" 2>/dev/null \
    && grep -q "github.event.label.name == 'ai-review:full'" "$ADVISORY_WORKFLOW" 2>/dev/null; then
    pass "advisory workflow re-runs when ai-review:full is labeled (with ai-review:live)"
  else
    fail "advisory workflow must re-run on ai-review:full label when ai-review:live is present"
  fi

  echo ""
  return 0
fi

echo "049-advisory-review-invariants.sh is sourced by test.sh only" >&2
exit 1
