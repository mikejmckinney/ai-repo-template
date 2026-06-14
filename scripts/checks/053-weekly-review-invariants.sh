#!/usr/bin/env bash
# scripts/checks/053-weekly-review-invariants.sh — weekly repo review wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking weekly review invariants..."

  WEEKLY_WORKFLOW=".github/workflows/agent-weekly-review.yml"
  WEEKLY_PROMPT=".github/prompts/weekly-repo-review.md"
  WEEKLY_FIX_PROMPT=".github/prompts/weekly-repo-review-fix.md"
  WEEKLY_DIR="scripts/workflows/weekly-review"
  SCAN_SCRIPT="${WEEKLY_DIR}/run-weekly-review-scan.sh"
  WEEKLY_SCRIPT="${WEEKLY_DIR}/run-weekly-review-weekly.sh"
  FIX_SCRIPT="${WEEKLY_DIR}/run-weekly-review-fix.sh"
  UMBRELLA_SCRIPT="${WEEKLY_DIR}/create-umbrella-issue.sh"
  UMBRELLA_LINK_SCRIPT="${WEEKLY_DIR}/update-umbrella-fix-link.sh"
  RESOLVE_UMBRELLA_SCRIPT="${WEEKLY_DIR}/resolve-umbrella-issue.sh"
  WRITE_UMBRELLA_REF_SCRIPT="${WEEKLY_DIR}/write-umbrella-issue-ref.sh"
  LINK_SCRIPT="scripts/workflows/lib/link-fix-pr-to-issue.sh"
  UMBRELLA_TEMPLATE=".github/templates/weekly-review-umbrella.md"
  FIX_PR_TEMPLATE=".github/templates/weekly-review-fix-pr.md"
  LIB_DIR="scripts/workflows/lib"

  for f in "$WEEKLY_WORKFLOW" "$WEEKLY_PROMPT" "$WEEKLY_FIX_PROMPT" "$SCAN_SCRIPT" \
    "$WEEKLY_SCRIPT" "$FIX_SCRIPT" "$UMBRELLA_SCRIPT" "$UMBRELLA_LINK_SCRIPT" \
    "$RESOLVE_UMBRELLA_SCRIPT" "$WRITE_UMBRELLA_REF_SCRIPT" "$LINK_SCRIPT" \
    "$UMBRELLA_TEMPLATE" "$FIX_PR_TEMPLATE" "${WEEKLY_DIR}/resolve-run-week.sh" \
    "${WEEKLY_DIR}/collect-weekly-evidence.sh" "${WEEKLY_DIR}/build-weekly-review-batch.py" \
    "${WEEKLY_DIR}/validate-weekly-review-batch.py" "${WEEKLY_DIR}/post-weekly-review-json-comment.sh" \
    "${WEEKLY_DIR}/fetch-weekly-review-json-from-issue.sh"; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (weekly review)"
    fi
  done

  if grep -q 'schedule:' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q '0 7 \* \* 0' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow scheduled Sunday 07:00 UTC"
  else
    fail "weekly workflow missing Sunday 07:00 UTC schedule"
  fi

  if grep -q 'workflow_dispatch' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow supports manual workflow_dispatch"
  else
    fail "weekly workflow must support workflow_dispatch"
  fi

  if ! grep -q 'pull_request:' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow has no pull_request trigger"
  else
    fail "weekly workflow must not use pull_request trigger"
  fi

  if grep -q 'run-weekly-review-weekly.sh' "$WEEKLY_WORKFLOW" 2>/dev/null \
    && grep -q 'run-weekly-review-fix.sh' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "workflow invokes weekly scan + fix scripts"
  else
    fail "workflow must invoke weekly scan and fix scripts"
  fi

  if grep -q 'group: weekly-review' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow uses dedicated concurrency group"
  else
    fail "weekly workflow missing weekly-review concurrency group"
  fi

  if grep -q 'WEEKLY_REVIEW_CONTEXT_PROFILE' "$WEEKLY_WORKFLOW" 2>/dev/null; then
    pass "weekly workflow exposes WEEKLY_REVIEW_CONTEXT_PROFILE (default full)"
  else
    fail "agent-weekly-review.yml missing WEEKLY_REVIEW_CONTEXT_PROFILE env"
  fi

  if grep -q 'select-context' "$LIB_DIR/prompt_helpers.py" 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' "$SCAN_SCRIPT" 2>/dev/null; then
    pass "weekly scan uses catalog-driven context selection"
  else
    fail "run-weekly-review-scan.sh must use prompt_helpers select-context"
  fi

  if grep -q 'weekly-review-fix-pr.md' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'link-fix-pr-to-issue.sh' "$FIX_SCRIPT" 2>/dev/null \
    && grep -q 'Fixes #' "$FIX_PR_TEMPLATE" 2>/dev/null \
    && grep -q 'WEEKLY_REVIEW_FIX_REEXEC' "$FIX_SCRIPT" 2>/dev/null; then
    pass "weekly fix uses template + native issue link + re-exec guard"
  else
    fail "run-weekly-review-fix.sh must render fix PR, link issue, and re-exec from temp copy"
  fi

  if grep -q 'write-umbrella-issue-ref.sh' "$UMBRELLA_SCRIPT" 2>/dev/null \
    && grep -q 'umbrella_issue' "$WRITE_UMBRELLA_REF_SCRIPT" 2>/dev/null \
    && grep -q 'post-weekly-review-json-comment.sh' "$UMBRELLA_SCRIPT" 2>/dev/null; then
    pass "weekly umbrella records umbrella_issue ref + JSON snapshot comment"
  else
    fail "weekly review missing umbrella_issue ref / JSON snapshot wiring"
  fi

  if grep -q 'follow_up_issues' "$WEEKLY_PROMPT" 2>/dev/null \
    && grep -q 'dedupe_key' "$WEEKLY_PROMPT" 2>/dev/null; then
    pass "weekly prompt defines JSON output shape"
  else
    fail "weekly prompt missing required JSON contract"
  fi

  if bash -n "$SCAN_SCRIPT" 2>/dev/null \
    && bash -n "$WEEKLY_SCRIPT" 2>/dev/null \
    && bash -n "$FIX_SCRIPT" 2>/dev/null \
    && bash -n "$UMBRELLA_SCRIPT" 2>/dev/null \
    && bash -n "$RESOLVE_UMBRELLA_SCRIPT" 2>/dev/null \
    && bash -n "$WRITE_UMBRELLA_REF_SCRIPT" 2>/dev/null \
    && bash -n "$UMBRELLA_LINK_SCRIPT" 2>/dev/null \
    && bash -n "$LINK_SCRIPT" 2>/dev/null \
    && bash -n "${WEEKLY_DIR}/resolve-run-week.sh" 2>/dev/null \
    && bash -n "${WEEKLY_DIR}/collect-weekly-evidence.sh" 2>/dev/null \
    && bash -n "${WEEKLY_DIR}/post-weekly-review-json-comment.sh" 2>/dev/null \
    && bash -n "${WEEKLY_DIR}/fetch-weekly-review-json-from-issue.sh" 2>/dev/null; then
    pass "weekly-review shell scripts have valid bash syntax"
  else
    fail "weekly-review shell script bash -n failed"
  fi

  fixture_dir="scripts/tests/fixtures/weekly-review"
  review_fixture="${fixture_dir}/sample-review.json"
  if [[ -f "$review_fixture" ]]; then
    tmp="$(mktemp -d)"
    if python3 "${WEEKLY_DIR}/validate-weekly-review.py" "$review_fixture" \
      && python3 "${WEEKLY_DIR}/build-weekly-review-batch.py" 2026-W24 2026-06-14 "$review_fixture" \
        >"$tmp/weekly.json" \
      && python3 "${WEEKLY_DIR}/validate-weekly-review-batch.py" "$tmp/weekly.json"; then
      pass "weekly JSON fixture validation + batch build"
    else
      fail "weekly JSON fixture validation/batch build failed"
    fi
    rm -rf "$tmp"
  else
    warn "weekly-review fixtures missing under $fixture_dir"
  fi

  echo ""
  return 0
fi

echo "053-weekly-review-invariants.sh is sourced by test.sh only" >&2
exit 1
