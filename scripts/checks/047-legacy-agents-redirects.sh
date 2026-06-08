#!/usr/bin/env bash
# scripts/checks/047-legacy-agents-redirects.sh — ADR-021 redirect surface hygiene.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking AGENTS.md redirect compatibility..."

  LEGACY_RULE=".context/rules/legacy_agents_anchor_redirects.md"
  REDIRECT_GUIDE="docs/guides/agents-md-section-redirects.md"

  external_hash_refs=$(
    git grep -n 'AGENTS\.md#' -- \
      ':!.github/prompts/agent-pr-prompts-combined-v2.md' \
      ':!docs/guides/agents-md-section-redirects.md' \
      ':!scripts/checks/047-legacy-agents-redirects.sh' 2>/dev/null || true
  )

  if [[ -f "$LEGACY_RULE" ]]; then
    fail "$LEGACY_RULE must not exist; use $REDIRECT_GUIDE (PR 1B retirement)"
  else
    pass "legacy_agents_anchor_redirects.md retired from .context/rules"
  fi

  if [[ ! -f "$REDIRECT_GUIDE" ]]; then
    fail "$REDIRECT_GUIDE missing (ADR-021 section redirect table)"
  else
    pass "$REDIRECT_GUIDE exists"
  fi

  if grep -q 'legacy_agents_anchor_redirects' AGENTS.md .context/rules/README.md 2>/dev/null; then
    fail "startup surfaces still reference legacy_agents_anchor_redirects.md"
  else
    pass "startup surfaces point at docs redirect guide, not legacy rule file"
  fi

  if [[ -n "$external_hash_refs" ]]; then
    fail "AGENTS.md hash-anchor references remain outside the redirect guide"
    printf '%s\n' "$external_hash_refs"
  else
    pass "no live AGENTS.md hash-anchor references outside redirect guide"
  fi

  echo ""
fi
