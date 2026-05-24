#!/usr/bin/env bash
# scripts/checks/030-docs-structure.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Docs Structure Check ---
echo "Checking docs structure..."

DOCS_FILES=(
  "docs/README.md"
  "docs/FAQ.md"
  "docs/smoke-a.md"
  "docs/smoke-e.md"
  "docs/compliance_schemas.md"
  "docs/guides/agent-best-practices.md"
  "docs/guides/agent-pipeline.md"
  "docs/guides/context-files-explained.md"
  "docs/guides/design-patterns.md"
  "docs/guides/design-patterns-concurrency.md"
  "docs/guides/design-patterns-data.md"
  "docs/guides/design-patterns-gof.md"
  "docs/guides/design-patterns-integration.md"
  "docs/guides/design-patterns-post-gof.md"
  "docs/guides/multi-agent-coordination.md"
  "docs/guides/multi-model-consensus.md"
  "docs/guides/optional-skills.md"
  "docs/guides/sandbox-verification.md"
  "docs/decisions/adr-001-context-pack-structure.md"
  "docs/decisions/adr-002-agents-md-ownership.md"
  "docs/decisions/adr-003-claude-code-subagent-registration.md"
  "docs/decisions/adr-004-analyst-role-and-feedback-loop.md"
  "docs/decisions/adr-005-analyst-preflight-gate.md"
  "docs/decisions/adr-006-auto-merge-opt-in-model.md"
  "docs/decisions/adr-007-auto-resolve-review-threads.md"
  "docs/decisions/adr-008-phase4-default-and-copilot-fallback.md"
  "docs/decisions/adr-009-parallel-multi-agent-execution.md"
  "docs/decisions/adr-010-auto-rebase-on-merge.md"
  "docs/decisions/adr-011-plan-as-comment-requirement.md"
  "docs/decisions/adr-012-explicit-workflow-preconditions.md"
  "docs/decisions/adr-013-pre-commit-on-main-default.md"
  "docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md"
  "docs/decisions/adr-015-postmortem-feedback-loop.md"
  "docs/decisions/adr-016-pre-merge-verification-gate.md"
  "docs/decisions/adr-017-template-repo-pre-commit-default.md"
  "docs/decisions/adr-018-multi-task-active-md-schema.md"
  "docs/decisions/adr-019-per-role-model-tiering.md"
  "docs/decisions/adr-020-orchestration-patterns-reference.md"
  "docs/decisions/adr-021-agents-md-decomposition.md"
  "docs/decisions/adr-022-top-level-md-scope-split.md"
  "docs/decisions/adr-023-shared-subagent-canonical.md"
  "docs/decisions/adr-024-multi-model-consensus-planning.md"
  "docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md"
  "docs/decisions/adr-026-compliance-contracts.md"
  "docs/decisions/adr-027-opportunity-feedback-channel.md"
  "docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md"
  "docs/decisions/adr-template.md"
  "docs/decisions/README.md"
  "docs/postmortems/README.md"
  "docs/postmortems/postmortem-template.md"
  "docs/postmortems/postmortem-001-workflow-bypass.md"
  "docs/postmortems/postmortem-002-poc-outcome-mismatch.md"
  "docs/postmortems/postmortem-004-opportunity-feedback-channel.md"
)

for file in "${DOCS_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

DOCS_DIRS=(
  "docs/reference"
  "docs/research"
  "docs/guides"
  "docs/decisions"
  "docs/postmortems"
)

for dir in "${DOCS_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    pass "$dir directory exists"
  else
    fail "$dir directory is missing"
  fi
done

echo ""
