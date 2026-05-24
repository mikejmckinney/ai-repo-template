# Architecture Decision Records (ADRs)

> **Purpose**: Durable record of "why we chose X over Y." Every nontrivial
> architectural or process decision lives here. Code is the *what*; ADRs
> are the *why*.
>
> ADRs are *prospective* ("we will do X because we expect Y").
> *Retrospective* lessons ("we did X, and Z happened") live in
> [`docs/postmortems/`](../postmortems/README.md). A postmortem may
> trigger a new ADR (or supersede one), but the two artifacts are kept
> separate so the audit trail stays honest.

## Index

| ADR | Title | Status |
|---|---|---|
| [ADR-001](./adr-001-context-pack-structure.md) | Context pack structure | Accepted (superseded in part by ADR-025) |
| [ADR-002](./adr-002-agents-md-ownership.md) | AGENTS.md ownership | Accepted |
| [ADR-003](./adr-003-claude-code-subagent-registration.md) | Claude Code subagent registration (two-registry design) | Accepted (superseded in part by ADR-023) |
| [ADR-004](./adr-004-analyst-role-and-feedback-loop.md) | Analyst role + feedback loop | Accepted (superseded in part by ADR-025) |
| [ADR-005](./adr-005-analyst-preflight-gate.md) | Analyst Pre-Flight gate | Superseded in part by ADR-014 |
| [ADR-006](./adr-006-auto-merge-opt-in-model.md) | Auto-merge opt-in model | Accepted |
| [ADR-007](./adr-007-auto-resolve-review-threads.md) | Auto-resolve bot-authored review threads (opt-in label; Copilot-path gap tracked in #100) | Superseded by ADR-008 |
| [ADR-008](./adr-008-phase4-default-and-copilot-fallback.md) | Phase 4 runs by default; Copilot-path relay-side fallback | Accepted |
| [ADR-009](./adr-009-parallel-multi-agent-execution.md) | Parallel multi-agent execution (patterns, dispatch reality, conflict enforcement) | Accepted (superseded in part by ADR-025) |
| [ADR-010](./adr-010-auto-rebase-on-merge.md) | Auto-rebase on merge for parallel agent PRs | Accepted |
| [ADR-011](./adr-011-plan-as-comment-requirement.md) | Plan-as-comment requirement + PR-must-link-issue (v1) | Accepted (superseded in part by ADR-026) |
| [ADR-012](./adr-012-explicit-workflow-preconditions.md) | Explicit workflow preconditions in AGENTS.md (branch-and-commit, cadence sharpenings) | Accepted |
| [ADR-013](./adr-013-pre-commit-on-main-default.md) | Pre-commit hook for `main` protection — not installed by default | Accepted |
| [ADR-014](./adr-014-extend-preflight-to-adhoc-deliverables.md) | Extend Analyst Pre-Flight gate to ad-hoc deliverable issues | Accepted |
| [ADR-015](./adr-015-postmortem-feedback-loop.md) | Postmortem feedback loop from downstream projects (capture + mirror prompts; three-tier promotion policy; v1 = manual) | Accepted |
| [ADR-016](./adr-016-pre-merge-verification-gate.md) | Pre-merge verification gate (Plan-template Change-class field + `verify-pr.sh` classifier + sandbox sibling repo) | Accepted |
| [ADR-017](./adr-017-template-repo-pre-commit-default.md) | Template repo installs pre-commit shellcheck + actionlint by default (template-only; ADR-013 unchanged for derived repos) | Accepted |
| [ADR-018](./adr-018-multi-task-active-md-schema.md) | Multi-task schema for `.context/state/_active.md` (refines ADR-009) | Accepted (superseded in part by ADR-025) |
| [ADR-019](./adr-019-per-role-model-tiering.md) | Per-role model tiering across Claude Code and Copilot (Phase 2 of #220; supersedes ADR-003's `model: inherit` choice) | Accepted |
| [ADR-020](./adr-020-orchestration-patterns-reference.md) | Orchestration patterns and anti-patterns reference file (`.context/rules/repo_orchestration_patterns.md`) | Accepted |
| [ADR-021](./adr-021-agents-md-decomposition.md) | Decompose AGENTS.md into thin contract + per-concern `process_*.md` files (extends ADR-002) | Accepted (superseded in part by ADR-025) |
| [ADR-022](./adr-022-top-level-md-scope-split.md) | Top-level markdown scope split (README / AI_REPO_GUIDE / AGENTS) — also extends ADR-002 | Accepted |
| [ADR-023](./adr-023-shared-subagent-canonical.md) | Canonical role bodies in `.agents/<role>.md`; vendor folders carry thin overlays (supersedes ADR-003 in part) | Accepted (superseded in part by ADR-026) |
| [ADR-024](./adr-024-multi-model-consensus-planning.md) | Multi-model consensus planning — optional opt-in workflow shipped as prompt + guide; no new `synthesizer` role in v1 | Accepted |
| [ADR-025](./adr-025-github-issues-pr-comments-as-live-state.md) | GitHub Issues, PRs, comments, and labels as live agent state | Accepted |
| [ADR-026](./adr-026-compliance-contracts.md) | Agent compliance contracts and role receipt evidence | Accepted |
| [ADR-027](./adr-027-opportunity-feedback-channel.md) | Opportunity feedback channel for in-scope agent observations | Accepted |
| [ADR-029](./adr-029-sandbox-dogfood-evidence-and-canary-placeholder.md) | Sandbox dogfood evidence requirement on every PR + canary placeholder convention; narrows ADR-021 §"Per-file cadence bump" scope | Accepted |

When you add a new ADR, add a row above and update its status if it later
changes.

## When to write a new ADR

See `adr-template.md` → "When to write a new ADR" for the canonical trigger
list. Short version: any change to a previously documented decision needs a
new ADR (and the old one updated) — not an in-place rewrite.

## Supersession discipline

When ADR-NNN replaces ADR-XXX, both files must be updated in the **same PR**:

1. **New ADR (`adr-NNN-...md`)**:
   - `Status: Accepted` (or `Proposed` if not yet ratified).
   - Body includes `Supersedes ADR-XXX` (or `Supersedes ADR-XXX in part`
     for partial supersession) in Context or References.
2. **Old ADR (`adr-XXX-...md`)**:
   - `Status: Superseded by ADR-NNN` (full supersession) **or**
     `Status: Accepted (superseded in part by ADR-NNN)` (partial
     supersession — use when only some sections/triggers/scope are
     replaced and the rest of the original decision still stands).
     Replaces the previous status line.
   - Body is left otherwise intact — preserve the original rationale; the
     new ADR explains what changed.
3. **This README** — flip the old ADR's status column to `Superseded by
   ADR-NNN` (or `Superseded in part by ADR-NNN`) and add a row for the
   new one.
4. **Deprecation without replacement**: set the old ADR's `Status:
   Deprecated` and explain in the body. No new ADR required.

Judge enforces this at diff-gate per
`.context/rules/process_doc_maintenance.md` — a PR that changes a
documented decision without updating the old ADR's status line is a BLOCK.

## What a well-documented ADR looks like

Use **ADR-007** ([adr-007-auto-resolve-review-threads.md](./adr-007-auto-resolve-review-threads.md))
as the model:

- **Status + Date** at the top (sortable, searchable).
- **Context** that describes the problem in the team's own words, not abstract
  framing. Cite the issue number tracking the gap.
- **Decision** stated plainly and actionably. No marketing language.
- **Options Considered** — at least 2–3, each with honest pros/cons.
  Include the "do nothing" option when it's plausible.
- **Consequences** split into Positive / Negative / Neutral. Negative
  consequences are the most valuable section; if it's empty, you didn't
  think hard enough.
- **Known limitations** documented inline when the decision ships with a
  gap, with a cross-reference to the tracking issue (ADR-007 cites #100
  for its Copilot-path FORBIDDEN limitation).
- **Verification block** with named verification phases (V1, V2, …) and
  evidence links to the PRs/comments where each was validated.
- **Implementation checklist** with PR references — the audit trail for
  what shipped together.
- **References** to related ADRs, issues, and external docs.

If your ADR is missing one of these sections, ask whether the section is
genuinely N/A or whether you skipped the work. The Negative Consequences
and Verification blocks in particular tend to get skipped under pressure
and tend to be exactly where the actual lessons live.

## Numbering

Sequential, zero-padded: `adr-001`, `adr-002`, … `adr-099`, `adr-100`.
Don't renumber when superseding — keep the original number; supersession
is a status, not a renumber.

**Sandbox-prefixed numbering.** ADRs that are scoped to the sandbox
sibling repo (`mikejmckinney/ai-repo-template-sandbox`) and not yet
intended for upstream use the parallel sequence `adr-sandbox-NNN`
(`adr-sandbox-001`, `adr-sandbox-002`, …). They share this directory
and this README's table for discoverability but are sorted at the
bottom of the table under their own subsection so the sequential
upstream `adr-NNN` numbering remains visually contiguous. On
forward-port to upstream, a sandbox-prefixed ADR is **renumbered** to
the next available upstream `adr-NNN` slot (the supersession-keeps-its-
number rule above does not apply because the sandbox prefix is a scope
marker, not a sequence marker). Any references to the old sandbox
number (status footnotes on related ADRs, prose mentions in guides) are
rewritten in the same forward-port PR — there should be no `adr-sandbox-NNN`
strings left in the upstream repo after the port.
