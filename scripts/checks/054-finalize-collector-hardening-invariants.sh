#!/usr/bin/env bash
# scripts/checks/054-finalize-collector-hardening-invariants.sh — issue #428 wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking finalize/collector hardening invariants (#428)..."

  PROMPT_HELPERS="scripts/workflows/lib/prompt_helpers.py"
  FINALIZE_WORKFLOW=".github/workflows/agent-review-finalize.yml"

  for f in "$PROMPT_HELPERS" \
    scripts/workflows/pr-feedback/collect-pr-feedback.sh \
    scripts/workflows/pr-feedback/run-feedback-consolidation.sh \
    scripts/workflows/advisory-review/upsert-pr-comment.sh; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (#428 finalize hardening)"
    fi
  done

  if grep -q 'select-context' "$PROMPT_HELPERS" 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' scripts/workflows/pr-feedback/run-feedback-consolidation.sh 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' scripts/workflows/advisory-review/run-advisory-review.sh 2>/dev/null; then
    pass "finalize and advisory use catalog-driven context selection"
  else
    fail "finalize/advisory must use prompt_helpers select-context"
  fi

  if grep -q 'opened' "$FINALIZE_WORKFLOW" 2>/dev/null \
    && grep -q 'synchronize' "$FINALIZE_WORKFLOW" 2>/dev/null \
    && grep -q '\-\-repo "\$REPO"' "$FINALIZE_WORKFLOW" 2>/dev/null; then
    pass "finalize workflow has expanded triggers and gh pr view --repo"
  else
    fail "finalize workflow missing #428 trigger/repo fixes"
  fi

  if grep -q '^\.env$' .gitignore 2>/dev/null; then
    pass ".gitignore restores standalone .env entry"
  else
    fail ".gitignore missing standalone .env entry"
  fi

  if python3 -m py_compile "$PROMPT_HELPERS" 2>/dev/null \
    && python3 "$PROMPT_HELPERS" cap-json --input scripts/tests/fixtures/pr-feedback/reviews-sample.json \
      --jq-filter 'map({id, user: (.user.login // null), body})' --max-bytes 500 >/dev/null 2>&1; then
    pass "prompt_helpers cap-json runs on fixture"
  else
    fail "prompt_helpers cap-json failed"
  fi

  run_bats_check scripts/tests/paginate-comments.bats "paginate-comments.bats"
  run_bats_check scripts/tests/prompt-helpers.bats "prompt-helpers.bats"

  if [[ -f scripts/workflows/lib/cursor-sdk-version.sh ]] \
    && grep -q 'CURSOR_SDK_VERSION=' scripts/workflows/lib/cursor-sdk-version.sh 2>/dev/null \
    && ! grep -rE 'npm install --no-save @cursor/sdk[^@"$]' scripts/workflows --include='*.sh' 2>/dev/null | grep -q .; then
    pass "@cursor/sdk workflow installs are version-pinned"
  else
    fail "unpinned @cursor/sdk npm install; use cursor-sdk-version.sh"
  fi

  echo ""
  return 0
fi

echo "054-finalize-collector-hardening-invariants.sh is sourced by test.sh only" >&2
exit 1
