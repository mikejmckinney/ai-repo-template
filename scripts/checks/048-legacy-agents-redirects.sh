#!/usr/bin/env bash
# scripts/checks/048-legacy-agents-redirects.sh — ADR-021 redirect surface hygiene.

standalone=0
if ! declare -F pass >/dev/null 2>&1 || ! declare -F fail >/dev/null 2>&1; then
  standalone=1
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  cd "$REPO_ROOT" || exit 1

  # shellcheck source=scripts/lib/logging.sh
  source "$REPO_ROOT/scripts/lib/logging.sh"
  # shellcheck source=scripts/lib/assertions.sh
  source "$REPO_ROOT/scripts/lib/assertions.sh"

  PASS=0
  FAIL=0
  WARN=0
fi

echo "Checking AGENTS.md redirect compatibility..."

rule_part1="legacy_agents_anchor"
rule_part2="_redirects"
legacy_rule_name="${rule_part1}${rule_part2}"
LEGACY_RULE=".context/rules/${legacy_rule_name}.md"
REDIRECT_GUIDE="docs/guides/agents-md-section-redirects.md"
SELF_CHECK='scripts/checks/048-legacy-agents-redirects.sh'

set +e
external_hash_refs=$(
  git grep -n 'AGENTS\.md#' -- \
    ':!.github/prompts/agent-pr-prompts-combined-v2.md' \
    ":!${REDIRECT_GUIDE}" \
    ":!${SELF_CHECK}" 2>/dev/null
)
grep_status=$?
set -e

if [[ $grep_status -gt 1 ]]; then
  fail "git grep failed with exit code $grep_status"
fi

if [[ -f "$LEGACY_RULE" ]]; then
  fail "$LEGACY_RULE must not exist; use $REDIRECT_GUIDE (PR 1B retirement)"
else
  pass "${legacy_rule_name}.md retired from .context/rules"
fi

if [[ ! -f "$REDIRECT_GUIDE" ]]; then
  fail "$REDIRECT_GUIDE missing (ADR-021 section redirect table)"
else
  pass "$REDIRECT_GUIDE exists"
fi

if grep -q "$legacy_rule_name" AGENTS.md .context/rules/README.md 2>/dev/null; then
  fail "startup surfaces still reference ${legacy_rule_name}.md"
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

if [[ "$standalone" == "1" ]]; then
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "${GREEN}Passed:${NC} $PASS"
  echo -e "${YELLOW}Warnings:${NC} $WARN"
  echo -e "${RED}Failed:${NC} $FAIL"
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi
fi
