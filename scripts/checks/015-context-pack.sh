#!/usr/bin/env bash
# scripts/checks/015-context-pack.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Context Pack Check ---
echo "Checking context pack structure..."

CONTEXT_FILES=(
  ".context/00_INDEX.md"
  ".context/backlog.yaml"
  ".context/backlog.schema.json"
  ".context/roadmap.md"
  ".context/rules/README.md"
  ".context/rules/agent_ownership.md"
  ".context/rules/domain_code_quality.md"
  ".context/rules/repo_orchestration_patterns.md"
  ".context/rules/process_doc_maintenance.md"
  ".context/rules/process_template_detection.md"
  ".context/rules/process_critical_thinking.md"
  ".context/rules/process_work_style.md"
  ".context/rules/process_clarification.md"
  ".context/rules/process_role_selection.md"
  ".context/rules/process_gates.md"
  ".context/rules/process_session_state.md"
  ".context/rules/process_pr_completion.md"
  ".context/rules/process_model_tier.md"
  ".context/rules/process_subagent_bootstrap.md"
  ".context/sessions/README.md"
  ".context/sessions/latest_summary.md"
  ".context/sessions/feedback_template.md"
  ".context/state/README.md"
  ".context/state/agent_state_comment_template.md"
  ".context/vision/README.md"
)

for file in "${CONTEXT_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

# Check context directories exist
CONTEXT_DIRS=(
  ".context/rules"
  ".context/sessions"
  ".context/state"
  ".context/vision/mockups"
  ".context/vision/architecture"
)

for dir in "${CONTEXT_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    pass "$dir directory exists"
  else
    fail "$dir directory is missing"
  fi
done
