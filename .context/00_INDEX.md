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
|-- benchmarks/          # Durable benchmark protocols, schemas, and grading templates
|   `-- model-roi/       # Issue #374 model ROI benchmark apparatus
|       |-- results/     # Scored agent ROI benchmark records and cost source register
|       `-- tasks/       # Candidate-safe task injections + sealed reference metadata
|-- roadmap.md           # Template-development phases and current hardening track
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
        `-- state-surfaces.md  # Mermaid view of ADR-025 live-state hierarchy
```

## Quick Start for Agents (Lazy Load Pattern)

1. Read `AGENTS.md`, then this file.
2. Read the assigned GitHub issue body and linked PR when a durable task exists.
3. Use one monolithic implementing agent; use local consensus only when justified.
4. Treat `state/` as the GitHub-first live-state reference surface.
5. Read `sessions/latest_summary.md`, `roadmap.md`, benchmarks, or vision files only when their domain intersects the task.

**Execution model**: one implementing agent, blocking CI, optional parallel
advisory review, recurring retro, and opt-in local consensus. See ADR-031.

## Project Summary

**Project Name**: `ai-repo-template`

**Description**: A Codespaces-first repository template for monolithic AI-assisted software delivery with optional advisory review and recurring retro automation.

**Current Phase**: Phase 7 - template dogfooding, overlay extension, and process hardening.

**Primary Stack**: Markdown docs and prompts, shell automation, GitHub Actions workflow scaffolding, Python validation helpers, and VS Code/Codespaces bootstrap configuration.

**What ships from this repo**:

- Shared advisory/daily/weekly review lenses and workflow scaffolding.
- The always-loaded operating contract in `AGENTS.md` and reference diagrams under `.context/vision/architecture/`.
- Durable benchmark protocols and grading templates under `.context/benchmarks/`.
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
| [ADR-008](../docs/decisions/adr-008-phase4-default-and-copilot-fallback.md) | Phase 4 default plus Copilot fallback | Historical review-resolution fallback; superseded by ADR-031. |
| [ADR-009](../docs/decisions/adr-009-parallel-multi-agent-execution.md) | Parallel multi-agent execution | Historical role-specialized pipeline; superseded by ADR-031. |
| [ADR-010](../docs/decisions/adr-010-auto-rebase-on-merge.md) | Auto-rebase on merge | Historical mechanism; superseded by ADR-032. |
| [ADR-011](../docs/decisions/adr-011-plan-as-comment-requirement.md) | Plan-as-comment requirement | Made issue comments the required plan artifact before implementation. |
| [ADR-012](../docs/decisions/adr-012-explicit-workflow-preconditions.md) | Explicit workflow preconditions | Codified branch-first, commit cadence, and other non-implicit rules. |
| [ADR-013](../docs/decisions/adr-013-pre-commit-on-main-default.md) | Derived-repo pre-commit stance | Kept heavy pre-commit optional for downstream repos by default. |
| [ADR-014](../docs/decisions/adr-014-extend-preflight-to-adhoc-deliverables.md) | Wider Analyst gate | Historical pre-flight policy; superseded by ADR-031. |
| [ADR-015](../docs/decisions/adr-015-postmortem-feedback-loop.md) | Postmortem feedback loop | Added the downstream-project capture -> mirror -> promote path. |
| [ADR-016](../docs/decisions/adr-016-pre-merge-verification-gate.md) | Pre-merge verification gate | Bound plans and PRs to explicit change-class and sandbox evidence. |
| [ADR-017](../docs/decisions/adr-017-template-repo-pre-commit-default.md) | Template repo pre-commit default | Turned on shellcheck and actionlint for this repo itself. |
| [ADR-018](../docs/decisions/adr-018-multi-task-active-md-schema.md) | Multi-task active-state schema | Added owner-keyed repo-local state before ADR-025 moved live state to GitHub. |
| [ADR-019](../docs/decisions/adr-019-per-role-model-tiering.md) | Per-role model tiering | Historical model-tier policy; superseded by ADR-031. |
| [ADR-020](../docs/decisions/adr-020-orchestration-patterns-reference.md) | Orchestration patterns reference | Gave Critic and Judge shared pattern/anti-pattern vocabulary. |
| [ADR-021](../docs/decisions/adr-021-agents-md-decomposition.md) | AGENTS decomposition | Split the monolithic contract into focused `process_*.md` rules. |
| [ADR-022](../docs/decisions/adr-022-top-level-md-scope-split.md) | Top-level markdown scope split | Separated README, AI_REPO_GUIDE, and AGENTS responsibilities. |
| [ADR-023](../docs/decisions/adr-023-shared-subagent-canonical.md) | Canonical role bodies plus thin overlays | Historical role registry; superseded by ADR-031. |
| [ADR-024](../docs/decisions/adr-024-multi-model-consensus-planning.md) | Multi-model consensus planning | Historical planning workflow; superseded by ADR-031. |
| [ADR-025](../docs/decisions/adr-025-github-issues-pr-comments-as-live-state.md) | GitHub as live state | Moved normal coordination to issue/PR bodies, comments, and labels. |
| [ADR-026](../docs/decisions/adr-026-compliance-contracts.md) | Compliance contracts | Structured evidence schemas retired by the 2026-07-13 amendment. |
| [ADR-027](../docs/decisions/adr-027-opportunity-feedback-channel.md) | Opportunity feedback channel | Added an out-of-scope observation path without widening task scope. |
| [ADR-029](../docs/decisions/adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md) | Sandbox dogfood evidence | Requires sandbox proof for behavior/process claims on every PR. |
| [ADR-031](../docs/decisions/adr-031-agent-model-roi-benchmark-policy.md) | Agent/model ROI and execution lifecycle policy | Makes monolithic implementation the default, retires role registries, and retains optional advisory plus recurring retro. |
| [ADR-032](../docs/decisions/adr-032-automation-surface-retirement.md) | Automation surface retirement | Removes unused automation and moves benchmark apparatus off `main`. |

## Next Steps

- [ ] Complete issue #474 so active surfaces consistently use the monolithic implementation and review lifecycle.
- [ ] Remove or archive any lingering repo-local `_active.md` compatibility references now that ADR-025 and issue #368 moved live state to GitHub.
- [ ] Continue issue #279 to extract more machine-readable manifests and shrink workflow/business-logic drift.
- [ ] Ship issue #322 so downstream repos get a clearer new-project and parent/phase issue playbook.
