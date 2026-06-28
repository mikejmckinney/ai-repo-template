#!/usr/bin/env bash
# scripts/checks/044-bootstrap-rule-pointers.sh — ADR-031 bootstrap pointer hygiene.
# Fails when mandatory bootstrap surfaces cite removed .context/rules/ paths.

echo "Checking bootstrap rule pointer hygiene (ADR-031)..."

# Removed by ADR-031 Amendment 2026-06-15 (agent_ownership.md restored for ADR-009 tooling only).
REMOVED_RULES=(
  process_gates.md
  process_model_tier.md
  process_pr_completion.md
  process_role_selection.md
  process_subagent_bootstrap.md
  process_template_detection.md
)

BOOTSTRAP_SURFACES=(
  .agents
  .github/copilot-instructions.md
  .context/00_INDEX.md
)

violations=0
for rule in "${REMOVED_RULES[@]}"; do
  needle=".context/rules/${rule}"
  for surface in "${BOOTSTRAP_SURFACES[@]}"; do
    if [[ -d "$surface" ]]; then
      matches=$(grep -R -n -F "$needle" "$surface" 2>/dev/null || true)
    elif [[ -f "$surface" ]]; then
      matches=$(grep -n -F "$needle" "$surface" 2>/dev/null || true)
    else
      continue
    fi
    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        fail "stale bootstrap pointer to removed rule: ${line}"
        violations=$((violations + 1))
      done <<<"$matches"
    fi
  done
done

if [[ "$violations" -eq 0 ]]; then
  pass "bootstrap surfaces do not cite ADR-031 removed rule paths"
fi

if [[ -f .context/rules/agent_ownership.md ]]; then
  pass "agent_ownership.md present for ADR-009 parallelism tooling"
else
  warn "agent_ownership.md missing — parallelism soft-overlap classification disabled"
fi
