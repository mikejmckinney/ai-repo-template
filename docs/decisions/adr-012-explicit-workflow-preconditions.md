# ADR-012: Explicit workflow preconditions in AGENTS.md

## Status

Accepted

## Date

2026-04-25

## Context

A real downstream incident (`docs/postmortems/postmortem-001-workflow-bypass.md`) had an agent perform six full roadmap phases on `main` with zero commits across roughly four hours of work. A Codespace restart or `git clean -fdx` would have destroyed every artifact. The agent's own postmortem traces the failure to two root causes:

1. **Implicit preconditions read as suggestions.** AGENTS.md's existing §"Work style" listed "small, reversible changes" and "no drive-by refactors" but did not say "branch and commit before you finish a unit of work." The agent rationalized that branching could happen at the end. Likewise, the §"Session-state cadence" close-out wording said "post-merge" — the agent inferred that pre-merge close-outs were optional.

2. **Scratch surfaces treated as session memory.** The agent kept its only record of in-progress work in the LLM tool's in-conversation todo list and `/memories/session/` files — both invisible to any other session. When the next session started, it discovered hours of uncommitted work with no checked-in trace.

The downstream postmortem also noted that LLM runtime auto-summarization is the loudest possible signal of a long-running session, but the existing §"Session-state cadence" handoff trigger only mentioned "~30 turns" and "before any role/agent handoff" — auto-summarization was not called out, so it was not treated as a trigger.

Every repo bootstrapped from this template inherits these gaps. Fixing only the downstream repo does not help the next one. This ADR documents the template-level rule edits made in response.

## Decision

Add explicit preconditions to AGENTS.md in two places:

1. **§"Work style" gains a leading bullet**: "Branch first, then commit per task boundary." The bullet states branching is a precondition for the work (not a wrap-up step) using imperative phrasing ("you MUST be on a non-default branch *before* making any non-trivial edit"). It also requires at least one commit per task boundary, not only at the end of a multi-task session. Branch-naming citations point at the canonical sources: `feature/<role>-<task-id>` is defined in `docs/guides/multi-agent-coordination.md` §"Branch-Per-Role Model"; `fix/<issue>-<slug>` is shown by example in `.context/state/coordination.md` (no formal definition — pattern-by-example).

2. **§"Session-state cadence" is sharpened on four points** the postmortem flagged:
   - A preamble naming `.context/state/` as the only non-scratch surface for working state, and explicitly calling LLM in-conversation todo lists and `/memories/session/` "agent-private scratch surfaces invisible to any other session."
   - The `_active.md` bullet gains a sub-bullet defining `.github/prompts/NN-*.md` as a task boundary (so a multi-prompt session is multiple boundaries, not one).
   - The handoff-trigger bullet adds LLM auto-summarization as an explicit trigger alongside the ~30-turn and role-handoff triggers.
   - The close-out bullet replaces "post-merge" with "session end OR task close-out, whichever comes first" and explains the spirit of the rule (leave the next session a baton).

The rule lives in AGENTS.md (auto-loaded by every agent runtime via `.github/copilot-instructions.md` and `CLAUDE.md`) rather than under `.context/rules/` (lazy-loaded via `.context/00_INDEX.md`). For a precondition that must fire on the first edit of a session, the auto-loaded surface is the right home, and a single bullet does not earn a separate file. If this rule grows past ~5 bullets or accumulates tabulated exceptions, promote to `.context/rules/process_workflow_preconditions.md` (or merge into `process_doc_maintenance.md`).

## Consequences

**Positive:**

- The next agent reading AGENTS.md on a fresh template-derived repo cannot reasonably conclude that working directly on `main` is acceptable.
- "Task boundary" has a concrete definition for prompt-driven work (one boundary per `NN-*.md` prompt) — eliminates the "multi-prompt session = one task" misreading.
- LLM auto-summarization is now a named handoff trigger; agents that hit it will write the handoff before responding to the next user message.
- The close-out wording no longer implies that pre-merge sessions skip the `latest_summary.md` update.
- The branch-naming citations point at the actual canonical sources, so an agent following them lands on real definitions.

**Negative:**

- AGENTS.md §"Work style" gains one long bullet. The trade-off is one paragraph of read time vs. four hours of recoverable work, which is acceptable.
- The §"Session-state cadence" section grows. It was already the longest section in AGENTS.md; this ADR adds ~10 lines.
- If this rule grows past a few bullets, AGENTS.md will not be the right home anymore. The "promote to `.context/rules/`" escape hatch above is the planned response.

**Neutral:**

- A pre-commit hook that blocks direct commits to `main` is a complementary mechanical guardrail. It is sequenced as PR-B in #180 with its own decision (ADR-013 if we decide not to install by default), separately from this rule-text fix.

## References

- Source incident: `docs/postmortems/postmortem-001-workflow-bypass.md` (mirrored from `mikejmckinney/cmmc-level2-aws-enclave-reference2`)
- Tracking issue: #180
- Reverted prior attempt: PR #181 (reverted in PR #186); revised plan in the second comment on #180
- Related: ADR-005 (Analyst pre-flight gate — different gate, different trigger), ADR-011 (plan-as-comment requirement — also a process precondition, lives in AGENTS.md for the same load-semantics reason)
