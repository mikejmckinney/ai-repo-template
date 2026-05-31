# Context Pack Index

> **Purpose**: This is the entry point for AI agents to understand the template repo's direction, constraints, and current state.

## How to Use This Directory

The `.context/` directory is the template's canonical process and planning layer.
In `ai-repo-template`, it serves two jobs at once:

1. It is the live source of truth for the template repo itself.
2. It shows downstream repos what a populated context pack should look like before
   Mode B onboarding restores the generic stubs.

### priority order (when conflicts arise)

See `AGENTS.md` §"Truth hierarchy" for the canonical definition. Summary:
`.context/**` > `docs/**` > codebase.

## Directory Structure

```text
.context/
|-- 00_INDEX.md          # This file - start here (The Map)
|-- backlog.yaml         # Machine-readable task list dispatched into issues
|-- backlog.schema.json  # JSON Schema for backlog.yaml
|-- roadmap.md           # Template-development phases and current hardening track
|-- rules/               # Immutable constraints and process rules
|   |-- agent_ownership.md            # Canonical role -> owned paths map (read before editing)
|   |-- domain_code_quality.md        # Built-in language-neutral SOLID/TDD/clean-code floor
|   |-- process_doc_maintenance.md    # Doc-sync trigger table
|   |-- process_subagent_bootstrap.md # ADR-026 dispatch packet + subagent return contract
|   `-- process_*.md                  # Additional process rules by concern
|-- sessions/            # Durable retrospectives and feedback records
|   |-- feedback_template.md # Stakeholder feedback capture template
|   `-- latest_summary.md   # Durable retrospective lessons
|-- state/               # GitHub-first live-state guidance and comment template
|   |-- README.md        # ADR-025 state-surface guide
|   `-- agent_state_comment_template.md # GitHub live-state comment template
`-- vision/              # Design artifacts and architecture diagrams
    |-- README.md
    |-- mockups/         # Reserved for downstream product/UI work
    `-- architecture/
        |-- multi-agent-flow.md # Mermaid view of the current workflow
        `-- state-surfaces.md  # Mermaid view of ADR-025 live-state hierarchy
```

## Quick Start for Agents (Lazy Load Pattern)

1. Read `AGENTS.md`, then this file.
2. Read your role file (for example, `.agents/<your-role>.md`).
3. Read the assigned GitHub issue body, linked PR, latest `agent-state:v1` comment, and labels.
4. Read `rules/agent_ownership.md` before touching files.
5. Treat `state/` as the GitHub-first live-state reference surface; use `state/agent_state_comment_template.md` when updating the latest `agent-state:v1` baton.
6. Read `sessions/latest_summary.md` for durable lessons from recent work.
7. Read `roadmap.md` for the current template phase and open hardening track.
8. Pull additional `rules/` and `vision/` files only when their domain intersects your change.

**Multi-agent workflow**: See [docs/guides/multi-agent-coordination.md](../docs/guides/multi-agent-coordination.md) for the end-to-end Analyst -> Architect -> plan-gate (Critic notes + Judge approval) -> PM -> implementers -> QA -> Critic -> Judge flow.

**Compliance contracts**: See `docs/compliance_schemas.md` and `docs/decisions/adr-026-compliance-contracts.md` for the ADR-026 evidence blocks (`plan_compliance`, `parent_compliance`, `subagent_compliance`) and role-contract versioning model.

## Project Summary

**Project Name**: `ai-repo-template`

**Description**: A Codespaces-first repository template for AI-assisted software delivery. It ships the process rules, role contracts, prompts, workflow scaffolding, and validation helpers needed to run a multi-agent issue -> merge pipeline in this repo and in downstream repos created from it.

**Current Phase**: Phase 7 - template dogfooding, overlay extension, and process hardening.

**Primary Stack**: Markdown docs and prompts, shell automation, GitHub Actions workflow scaffolding, Python validation helpers, and VS Code/Codespaces bootstrap configuration.

**What ships from this repo**:

- Canonical role definitions under `.agents/` plus Copilot and Claude overlays.
- Process rules under `.context/rules/` and reference diagrams under `.context/vision/architecture/`.
- GitHub prompts, issue/PR templates, and workflow scaffolding under `.github/`.
- Bootstrap and verification helpers under `install.sh`, `test.sh`, and `scripts/**`.

## Key Decisions Log

For the full ADR index, see [docs/decisions/README.md](../docs/decisions/README.md). The rows below call out the decisions that shape the current template behavior.

| ADR | Decision | Current effect |
|---|---|---|
| [ADR-001](../docs/decisions/adr-001-context-pack-structure.md) | Context pack structure | Established `.context/**` as the canonical planning and rules layer. |
| [ADR-002](../docs/decisions/adr-002-agents-md-ownership.md) | `AGENTS.md` ownership | Kept the top-level agent contract under architect-owned governance. |
| [ADR-003](../docs/decisions/adr-003-claude-code-subagent-registration.md) | Dual subagent registry | Introduced the platform-overlay model later thinned by ADR-023. |
| [ADR-004](../docs/decisions/adr-004-analyst-role-and-feedback-loop.md) | Analyst role and feedback loop | Made problem validation a first-class stage before planning or code. |
| [ADR-005](../docs/decisions/adr-005-analyst-preflight-gate.md) | Analyst pre-flight gate | Established the original pre-implementation research gate. |
| [ADR-006](../docs/decisions/adr-006-auto-merge-opt-in-model.md) | Auto-merge opt-in | Kept merge automation explicitly label-gated instead of default-on. |
| [ADR-007](../docs/decisions/adr-007-auto-resolve-review-threads.md) | Bot-thread auto-resolution v1 | Started the review-thread automation path later replaced by ADR-008. |
| [ADR-008](../docs/decisions/adr-008-phase4-default-and-copilot-fallback.md) | Phase 4 default plus Copilot fallback | Locked in the current relay-side fallback for review-resolution work. |
| [ADR-009](../docs/decisions/adr-009-parallel-multi-agent-execution.md) | Parallel multi-agent execution | Defined role-specialized parallel work plus overlap safeguards. |
| [ADR-010](../docs/decisions/adr-010-auto-rebase-on-merge.md) | Auto-rebase on merge | Added the soft-overlap rebase path for open parallel PRs. |
| [ADR-011](../docs/decisions/adr-011-plan-as-comment-requirement.md) | Plan-as-comment requirement | Made issue comments the required plan artifact before implementation. |
| [ADR-012](../docs/decisions/adr-012-explicit-workflow-preconditions.md) | Explicit workflow preconditions | Codified branch-first, commit cadence, and other non-implicit rules. |
| [ADR-013](../docs/decisions/adr-013-pre-commit-on-main-default.md) | Derived-repo pre-commit stance | Kept heavy pre-commit optional for downstream repos by default. |
| [ADR-014](../docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md) | Wider Analyst gate | Extended pre-flight coverage beyond only feature-style issues. |
| [ADR-015](../docs/decisions/adr-015-postmortem-feedback-loop.md) | Postmortem feedback loop | Added the downstream-project capture -> mirror -> promote path. |
| [ADR-016](../docs/decisions/adr-016-pre-merge-verification-gate.md) | Pre-merge verification gate | Bound plans and PRs to explicit change-class and sandbox evidence. |
| [ADR-017](../docs/decisions/adr-017-template-repo-pre-commit-default.md) | Template repo pre-commit default | Turned on shellcheck and actionlint for this repo itself. |
| [ADR-018](../docs/decisions/adr-018-multi-task-active-md-schema.md) | Multi-task active-state schema | Added owner-keyed repo-local state before ADR-025 moved live state to GitHub. |
| [ADR-019](../docs/decisions/adr-019-per-role-model-tiering.md) | Per-role model tiering | Bound each role overlay to an allowed model tier by platform. |
| [ADR-020](../docs/decisions/adr-020-orchestration-patterns-reference.md) | Orchestration patterns reference | Gave Critic and Judge shared pattern/anti-pattern vocabulary. |
| [ADR-021](../docs/decisions/adr-021-agents-md-decomposition.md) | AGENTS decomposition | Split the monolithic contract into focused `process_*.md` rules. |
| [ADR-022](../docs/decisions/adr-022-top-level-md-scope-split.md) | Top-level markdown scope split | Separated README, AI_REPO_GUIDE, and AGENTS responsibilities. |
| [ADR-023](../docs/decisions/adr-023-shared-subagent-canonical.md) | Canonical role bodies plus thin overlays | Made `.agents/<role>.md` the shared source for Copilot and Claude. |
| [ADR-024](../docs/decisions/adr-024-multi-model-consensus-planning.md) | Multi-model consensus planning | Added the optional three-candidate planning workflow. |
| [ADR-025](../docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md) | GitHub as live state | Moved normal coordination to issue/PR bodies, comments, and labels. |
| [ADR-026](../docs/decisions/adr-026-compliance-contracts.md) | Compliance contracts | Added receipt/evidence schemas for parent and subagent work. |
| [ADR-027](../docs/decisions/adr-027-opportunity-feedback-channel.md) | Opportunity feedback channel | Added an out-of-scope observation path without widening task scope. |
| [ADR-029](../docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md) | Sandbox dogfood evidence | Requires sandbox proof for behavior/process claims on every PR. |

## Next Steps

- [ ] Finish the active cleanup and hardening umbrella in issue #327, including the remaining overlay and coordination follow-ups.
- [ ] Land issue #321 so `pr-resolve-all` rounds are non-silent, settle-gated, and human-approved before merge.
- [ ] Remove or archive any lingering repo-local `_active.md` compatibility references now that ADR-025 and issue #368 moved live state to GitHub.
- [ ] Continue issue #279 to extract more machine-readable manifests and shrink workflow/business-logic drift.
- [ ] Ship issue #322 so downstream repos get a clearer new-project and parent/phase issue playbook.
