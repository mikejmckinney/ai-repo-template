# ADR-018: Multi-task schema for `.context/state/_active.md`

## Status

Accepted

## Date

2026-05-06

## Context

`.context/state/_active.md` was originally specified as a single-writer,
single-task file: agents rewrite (don't append) at every task boundary,
capped at ~20 lines, schema = `Active Task | File | Role | Blockers | Next
1–3 actions`. That shape was correct for the single-agent workflow but
breaks under the parallel multi-agent model ratified in
[ADR-009](./adr-009-parallel-multi-agent-execution.md).

When two parallel agents on different feature branches each commit edits
to `_active.md` (e.g., PR #234 and PR #235 both updating their respective
task state), two failure modes appear:

1. **Hard merge conflict** on the second branch to rebase, because both
   branches rewrote the same lines. Manual resolution becomes the agent's
   default action even though both edits were valid.
2. **Silent state loss** when the merge "winner" clobbers the other agent's
   in-flight task description. The next session that picks up the surviving
   task reads stale state — the very failure the re-read cadence was designed
   to prevent.

This is not hypothetical: it is the failure that surfaced during PR #235's
bot-review loop and is captured in
[postmortem-003-active-md-merge-conflict.md](../postmortems/postmortem-003-active-md-merge-conflict.md).

The companion claim board `.context/state/coordination.md` already supports
multi-claim semantics — `_active.md` is the lagging piece.

## Decision

We will amend `_active.md` to support **multiple named task sections**, one
per concurrently-active task/branch. Each agent edits only its own section;
the file as a whole is still re-read in full at every task boundary so
agents see all in-flight work before claiming new tasks.

**Scope of the merge-safety improvement** (important — the schema does not
eliminate all conflicts):

- **Updates to distinct existing sections commute cleanly** under three-way
  merge. This is the realistic ongoing case: each branch claims its own
  `## Task:` section before parallel work fans out, then only edits its
  own section. The smoke test (`scripts/test-active-md-multitask.sh`
  scenario 1) covers this case and asserts no conflict.
- **Brand-new section additions from an empty body still produce a
  conflict.** Two branches both appending net-new sections target the
  same end-of-file line; no schema with freeform section lists can avoid
  this without a fixed sentinel structure that itself becomes a conflict
  point. The improvement vs. the old single-task schema is the
  *resolution semantic*: the manual fix is lossless concatenation
  ("keep both blocks"), not pick-one-winner with silent state loss. The
  smoke test scenario 2 covers this case and asserts the lossless-concat
  resolution produces a valid two-section file.

In practice, agents that follow the workflow (claim a section as the
first step of starting a branch, before parallel fan-out) will hit
scenario 1, not scenario 2.

New schema:

```markdown
# Active Tasks

<!-- Each section below is owned by one branch/PR. Agents edit only their
     own `## Task:` section. Add a section when claiming a task; remove
     it as part of the close-out flow when the PR merges or closes. -->

## Task: <branch-name>
**Issue/PR**: #NNN
**Role**: <role>
**Blockers**: ...
**Next 1–3 actions**:
1. ...
```

Section ownership key: **branch name**. It exists pre-PR, mirrors
`coordination.md`'s lock template, and survives close-and-reopen of the PR.

Per-section cap: **~20 lines**. The file as a whole has no fixed cap; bounded
growth comes from disciplined section removal at close-out. PM's
`coordination.md` reconciliation pass catches missed cleanups.

Re-read requirement (AGENTS.md §"Session-state cadence" item 3) is
unchanged in spirit: agents read the **whole file** at task boundaries. The
write surface is the only thing that narrows.

## Options Considered

1. **Pure append-only log** — Rejected. Leads to unbounded growth and
   stale sections accumulating with no clean-up trigger; defeats the
   "current snapshot" purpose of `_active.md`.
2. **Per-branch state files** (`_active_<branch>.md`) — Rejected. Splits
   the single read-point that AGENTS.md re-read cadence depends on; adds
   N file reads per session and creates a discovery problem (agents have
   to know which files exist before reading them).
3. **Lock-based single-writer with backoff** — Rejected. Adds coordination
   overhead to every state write and doesn't compose with
   `coordination.md`'s existing claim board.
4. **Don't commit `_active.md` from feature branches at all** — Rejected
   as a permanent solution. Trades documented cross-session state for
   nothing; the file becomes effectively useless for in-flight handoffs
   between sessions on the same branch.
5. **Multi-section format keyed by branch name** (chosen) — Preserves the
   single-read-point property; makes writes commutative under three-way
   merge; minimal change to existing prompts and rules. Section removal
   at close-out is the explicit cleanup trigger.

## Consequences

### Positive

- Two parallel branches that have each pre-claimed their own `## Task:`
  section can commit `_active.md` updates without producing a merge
  conflict; three-way merge auto-resolves at the section level
  (smoke test scenario 1).
- For the brand-new-section-add case where the schema cannot eliminate
  the conflict (smoke test scenario 2), the manual resolution is
  *lossless*: concatenate both `## Task:` blocks. Under the old schema
  the resolver had to pick a winner and silently lose the loser branch's
  state.
- After both PRs merge (whether via auto-resolve or manual lossless
  concat), `_active.md` accurately reflects all remaining in-flight work
  — no silent state loss in either case.
- The cadence re-read still works: an agent picking up work sees every
  active task at once and can spot conflicts before claiming new files.
- Section ownership matches `coordination.md` lock ownership, so the two
  files stay aligned by construction.

### Negative

- Cleanup discipline becomes load-bearing: forgotten `## Task:` sections
  accumulate until PM's reconciliation pass catches them. Mitigation:
  the close-out flow gains an explicit "remove section" step in
  `latest_summary.md` close-out; if discipline slips repeatedly, an
  automated section-cleanup workflow is a follow-up issue (out of scope
  for v1).
- Agents reading `_active.md` see more text than under the single-task
  schema. With realistic concurrency (2–4 active sections), this is a
  small constant increase, not unbounded growth.

### Neutral

- `task_<slug>.md`, `handoff_<slug>.md`, and `coordination.md` schemas
  are unchanged. Only the close-out checklist gains a one-line "remove
  `## Task:` section from `_active.md`" step.
- Re-read cadence text in AGENTS.md item 3 is reworded but the
  requirement (read the whole file) is preserved.

## Migration

In the same PR that lands this ADR, `_active.md` is rewritten to the new
schema with the *current* in-flight task wrapped in a single
`## Task: <current-branch>` header. The file is therefore valid under the
new schema from the moment the PR merges.

In-flight branches at the time this lands resolve at rebase: when their
existing single-task body conflicts with the new multi-section body, they
adopt the new format for their own task and keep any pre-existing
sections from `main`.

## Relationship to ADR-009

This ADR **refines** ADR-009 — it does not supersede it. ADR-009's
parallel-execution model (claim board, role ownership, branch-per-role,
diff-gate review) is unchanged. ADR-018 only amends the on-disk shape of
`_active.md` so the model works in practice without manual conflict
resolution.

ADR-009's status remains `Accepted`; no `Superseded by` line is added.

## References

- [ADR-009](./adr-009-parallel-multi-agent-execution.md) — parallel
  multi-agent execution (the model this ADR refines)
- [postmortem-003](../postmortems/postmortem-003-active-md-merge-conflict.md)
  — the PR #234 / PR #235 incident that motivated this change
- `AGENTS.md` §"Session-state cadence" — re-read requirement and
  `_active.md` write rules (updated in the same PR)
- `.context/state/README.md` §"Cadence" — claim/edit/cleanup rules for
  the multi-section format (updated in the same PR)
- Issue #237 — feature request and acceptance criteria
