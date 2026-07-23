#!/usr/bin/env bash
# scripts/checks/054-finalize-collector-hardening-invariants.sh — retained evidence collector wiring.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking retained evidence collector invariants..."

  PROMPT_HELPERS="scripts/workflows/lib/prompt_helpers.py"

  for f in "$PROMPT_HELPERS" \
    scripts/workflows/lib/collect-pr-evidence.sh \
    scripts/workflows/advisory-review/upsert-pr-comment.sh; do
    if [[ -f "$f" ]]; then
      pass "$f exists"
    else
      fail "$f missing (retained review evidence)"
    fi
  done

  if grep -q 'select-context' "$PROMPT_HELPERS" 2>/dev/null \
    && grep -qE 'prompt_helpers\.py.*select-context' scripts/workflows/advisory-review/run-advisory-review.sh 2>/dev/null; then
    pass "advisory uses catalog-driven context selection"
  else
    fail "advisory must use prompt_helpers select-context"
  fi

  if grep -q '^\.env$' .gitignore 2>/dev/null; then
    pass ".gitignore restores standalone .env entry"
  else
    fail ".gitignore missing standalone .env entry"
  fi

  if python3 -m py_compile "$PROMPT_HELPERS" 2>/dev/null; then
    pass "prompt_helpers compiles"
  else
    fail "prompt_helpers failed to compile"
  fi

  if grep -qF 'user: (.user?.login // null)' scripts/workflows/postmerge-retro/assemble-retro-prompt.sh \
    && grep -qF 'user: (.user?.login // null)' scripts/workflows/postmerge-retro/run-postmerge-retro-monolithic.sh; then
    pass "retro prompt assembly preserves nullable review authors"
  else
    fail "retro prompt assembly must use optional user access"
  fi

  if jq -e '.dependencies["@cursor/sdk"] == "1.0.24"' .github/agent-runtime/package.json >/dev/null 2>&1 \
    && grep -q 'CURSOR_SDK_MODULE=.*@cursor/sdk/dist/esm/index.js' .github/workflows/agent-postmerge-retro.yml \
    && ! grep -rE 'npm install( --no-save)? .*@cursor/sdk' scripts/workflows --include='*.sh' 2>/dev/null | grep -q .; then
    pass "@cursor/sdk uses the canonical locked agent runtime"
  else
    fail "@cursor/sdk must use the canonical locked agent runtime"
  fi

  echo ""
  return 0
fi

echo "054-finalize-collector-hardening-invariants.sh is sourced by test.sh only" >&2
exit 1
