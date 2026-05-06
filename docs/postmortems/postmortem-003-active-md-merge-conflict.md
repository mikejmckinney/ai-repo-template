---
postmortem_number: 003
date: 2026-05-04
source_repo: mikejmckinney/ai-repo-template
source_commit: bb09cef
stacks: []
generalizes: Yes
follow_up_artifact: ADR-018
mirror_status: original
---

# Postmortem-003: `_active.md` merge conflict between parallel agent PRs

## Status

Final

## Date

2026-05-04

## Author(s)

GitHub Copilot (interactive session, on behalf of the architect role)

## Trigger

PR #234 and PR #235 — two concurrently-open feature branches under the
ADR-009 parallel-execution model — both rewrote `.context/state/_active.md`
to point at their respective in-flight tasks. PR #234 merged first;
PR #235's rebase produced a hard merge conflict on `_active.md` and,
absent the ADR-018 schema change, would have silently clobbered PR #234's
state if "ours" had been taken.

## Context

`.context/state/_active.md` is part of the agent working-memory layer
defined in `AGENTS.md` §"Session-state cadence". The original schema was
single-writer: agents rewrite (don't append) at every task boundary, max
~20 lines, fields = Active Task / File / Role / Blockers / Next 1–3
actions. That shape predates the parallel-execution model ratified in
[ADR-009](../decisions/adr-009-parallel-multi-agent-execution.md).

The parallel-execution model assumes role-specialized branches can run
concurrently without coordination overhead beyond the
`coordination.md` claim board. `coordination.md` already supports
multi-claim semantics. `_active.md` did not — until ADR-018.

## What happened

1. **t0** — Branch `feature/devops-229-phase4` (PR #234 work) opens. Agent
   rewrites `_active.md` to describe the Phase 4 task.
2. **t1** — Branch `feature/architect-229-phase3` (PR #235 work) opens in
   parallel. Agent rewrites `_active.md` to describe the Phase 3 task.
   Branches each touch the same lines under the single-task schema.
3. **t2** — PR #234 merges. `main`'s `_active.md` now describes the
   Phase 4 task.
4. **t3** — PR #235 rebases onto `main`. Three-way merge fails on
   `_active.md` because both branches rewrote the same single-task
   block. Conflict markers appear in the working tree.
5. **t4** — Agent (or maintainer) must hand-resolve. The "right" answer
   under the old schema is unclear: keep PR #234's state (correct for
   the merged task, but PR #235's task is what's in flight on this
   branch) or keep PR #235's state (correct locally, but loses the
   merged task's context for any other agent). Either choice loses
   information.

## Root cause

The single-writer schema was a correct fit for the single-agent
workflow but is structurally incompatible with the parallel-execution
model. Two agents on two branches editing the same single-task block
cannot produce a commutative diff; merge conflict (and the silent-clobber
risk on naive resolution) is the inevitable outcome.

This was not an agent error. The agents followed the schema as written.
The schema itself was the gap.

## What generalizes

**Yes** — broadly. Any working-memory file shared by parallel agents
needs either:

1. A **multi-section schema** keyed by an owner identifier (branch, role,
   PR number), so writes are section-local and commute under three-way
   merge; or
2. **Single-writer enforcement** via a lock or claim board, with the
   schema explicitly documenting that only the lock holder may write.

`coordination.md` chose (2) implicitly (PM-owned, others self-claim only).
`_active.md` had neither, which is why this surfaced.

The general lesson: when adding a new shared file to the agent
working-memory layer, decide up-front whether it is multi-writer
(needs option 1) or single-writer (needs option 2). "Shared file with
ad-hoc writes from any role" is a third option, but it is the option
that produces this postmortem.

## Action items

- [x] **ADR-018** — multi-task schema for `_active.md` (this postmortem's
  follow-up artifact). Lands in the same PR as this postmortem.
- [x] **`_active.md` migration** — wrap current body in
  `## Task: <branch>` header so the file is valid under the new schema
  the moment the PR merges. Same PR.
- [x] **`.context/state/README.md`** — Cadence section updated with
  multi-section semantics: claim-section-on-start, edit-only-own-section,
  remove-section-on-close-out. Same PR.
- [x] **`AGENTS.md` §"Session-state cadence"** — `_active.md` bullet
  rewritten to match the new schema; `AGENTS_MD_VERSION` and handshake
  token bumped in lockstep. Same PR.
- [x] **`test.sh`** — assertion that `_active.md` non-empty body contains
  at least one `## Task:` section header. Same PR.
- [x] **Smoke test** — `scripts/test-active-md-multitask.sh` covers two
  scenarios: (1) two parallel branches each updating their own
  pre-claimed `## Task:` section assert clean three-way merge (the
  realistic ongoing case ADR-018 fixes); (2) two branches each adding a
  brand-new section to an empty body produce an expected conflict, and
  the documented manual resolution (lossless concatenation) yields a
  valid two-section file. Same PR.

## Related

- [ADR-009](../decisions/adr-009-parallel-multi-agent-execution.md) —
  the model this postmortem reconciles state-tracking with.
- [ADR-018](../decisions/adr-018-multi-task-active-md-schema.md) —
  the schema change that resolves the failure mode.
- [ADR-015](../decisions/adr-015-postmortem-feedback-loop.md) — the
  postmortem feedback loop that this postmortem follows. `generalizes:
  Yes`, follow-up artifact = ADR-018, both shipped in the same PR.
- Issue #237 — the feature request that drove this work.
