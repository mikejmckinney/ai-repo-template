#!/usr/bin/env bash
# scripts/checks/169-adr031-removed-rule-surfaces.sh — ADR-031 live-surface hygiene.

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

echo "Checking ADR-031 removed rule paths are not cited on live surfaces..."

SELF_CHECK='scripts/checks/169-adr031-removed-rule-surfaces.sh'
REMOVED=(
  'agent_ownership.md'
  'process_gates.md'
  'process_model_tier.md'
  'process_pr_completion.md'
  'process_role_selection.md'
  'process_subagent_bootstrap.md'
  'process_template_detection.md'
)

# Live agent-facing surfaces (exclude ADRs, archives, benchmark harness, fixtures).
PATH_SPECS=(
  '.agents'
  '.github/copilot-instructions.md'
  '.context/00_INDEX.md'
  '.github/pull_request_template.md'
  'docs/guides'
  '.github/prompts'
)

EXCLUDES=(
  ":!docs/decisions/**"
  ":!.context/sessions/**"
  ":!docs/postmortems/**"
  ":!docs/research/**"
  ":!scripts/tests/fixtures/**"
  ":!scripts/**"
  ":!.github/workflows/**"
  ":!.context/benchmarks/model-roi/results/**"
  ":!.github/prompts/agent-pr-prompts-combined-v2.md"
  ":!.github/prompts/model-roi-*.md"
  ":!.github/prompts/*benchmark*.md"
  ":!.github/prompts/01-implement-*.md"
  ":!.github/prompts/06-implement-*.md"
  ":!${SELF_CHECK}"
)

violations=0
for removed in "${REMOVED[@]}"; do
  pattern=".context/rules/${removed}"
  set +e
  hits=$(
    git grep -n -F "$pattern" -- "${PATH_SPECS[@]}" "${EXCLUDES[@]}" 2>/dev/null
  )
  status=$?
  set -e
  if [[ $status -gt 1 ]]; then
    fail "git grep failed for ${removed} (exit ${status})"
    continue
  fi
  if [[ -n "$hits" ]]; then
    fail "live surface still cites removed rule path: ${pattern}"
    printf '%s\n' "$hits"
    violations=$((violations + 1))
  else
    pass "no live citations of ${removed}"
  fi
done

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
