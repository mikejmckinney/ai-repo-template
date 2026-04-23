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
| [ADR-001](./adr-001-context-pack-structure.md) | Context pack structure | Accepted |
| [ADR-002](./adr-002-agents-md-ownership.md) | AGENTS.md ownership | Accepted |
| [ADR-003](./adr-003-claude-code-subagent-registration.md) | Claude Code subagent registration (two-registry design) | Accepted |
| [ADR-004](./adr-004-analyst-role-and-feedback-loop.md) | Analyst role + feedback loop | Accepted |
| [ADR-005](./adr-005-analyst-preflight-gate.md) | Analyst Pre-Flight gate | Accepted |
| [ADR-006](./adr-006-auto-merge-opt-in-model.md) | Auto-merge opt-in model | Accepted |
| [ADR-007](./adr-007-auto-resolve-review-threads.md) | Auto-resolve bot-authored review threads (opt-in label; Copilot-path gap tracked in #100) | Superseded by ADR-008 |
| [ADR-008](./adr-008-phase4-default-and-copilot-fallback.md) | Phase 4 runs by default; Copilot-path relay-side fallback | Accepted |
| [ADR-009](./adr-009-parallel-multi-agent-execution.md) | Parallel multi-agent execution (patterns, dispatch reality, conflict enforcement) | Accepted |
| [ADR-010](./adr-010-auto-rebase-on-merge.md) | Auto-rebase on merge for parallel agent PRs | Accepted |

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
   - Body includes `Supersedes ADR-XXX` (in Context or References).
2. **Old ADR (`adr-XXX-...md`)**:
   - `Status: Superseded by ADR-NNN` (replaces the previous status line).
   - Body is left otherwise intact — preserve the original rationale; the
     new ADR explains what changed.
3. **This README** — flip the old ADR's status column to `Superseded by
   ADR-NNN` and add a row for the new one.
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
