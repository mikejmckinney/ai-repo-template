# ADR-025: GitHub Issues, PRs, comments, and labels as live agent state

## Status

Accepted

## Date

2026-05-12

## Amendment 2026-07-22 — Retire rolling session summaries

The rolling `.context/sessions/latest_summary.md` mirror is retired. Issue and
PR history now preserve task outcomes in the same system that owns live state.
Agents promote only genuinely reusable decisions or incidents into ADRs and
postmortems. Existing date-stamped session archives remain historical evidence
but are not updated, required during onboarding, or used as current-state input.

## Amendment 2026-07-19 — Delimited issue-body plans

New issue bodies permit one mutable `implementation-plan:v2` block.
Requester-owned content remains stable. Implementation-ready work publishes an
empty bootstrap commit and linked draft PR before meaningful edits, then commits
and pushes every changed turn before updating the latest `agent-state:v1`
comment. Live progress remains exclusively in that comment.

## Amendment 2026-07-18 - Role-free problem framing

The issue body remains the durable feature/task contract and the input for
problem framing, planning, and critical review. References below to Analyst,
Judge, or Critic gates are superseded by ADR-031's monolithic execution and
review lifecycle. Framing evolves in the canonical issue/plan artifacts; live
progress remains in the latest `agent-state:v1` comment.

## Amendment 2026-07-15 — Clickable agent-managed artifacts

Agent-managed GitHub artifacts link addressable issues, PRs, comments, commits,
branches, Actions runs, ADRs, and repository files on first mention in every
section. The rule applies to plans, agent-authored issue/PR updates, PR bodies,
automated comments, and `agent-state:v1` comments, but not arbitrary human
comments. Local-only paths, commands, and identifiers remain inline code.

## Amendment 2026-07-14 — Continuation state without a handoff field

The latest `agent-state:v1` comment exists so any later agent or session can
continue the work from current evidence. A separate `handoff_needed` status and
`Handoff` field duplicate that purpose and force the author to predict who will
resume the task.

Effective with this amendment:

- Remove `handoff_needed` from the status enum and remove the separate handoff
  field.
- Require `status`, `updated`, and `actions` as the minimum continuation state.
- Permit concise blockers, outcomes, lessons learned, next steps, and reference
  pointers when they materially reduce recovery work.
- Keep long decision history, exhaustive file lists, verification matrices, and
  retrospective narratives in plans, PR bodies, ADRs, CI, or session archives.

This amendment supersedes the handoff-specific requirements in the original
decision below. It does not change GitHub's role as the primary live-state
surface or the requirement to keep one canonical comment updated in place.

## Context

Issue #298 identifies a recurring state-management failure in the
repo-local live-state model: agents work from GitHub issues and PRs, but
then must remember to mirror lifecycle facts back into checked-in markdown
files under `.context/state/`. The lifecycle facts that drift most often
are also the facts GitHub already owns natively:

- the durable feature/task contract lives in the issue body;
- the implementation and verification contract lives in the PR body;
- the PR number exists only after PR creation;
- close/merge state exists only after PR close/merge;
- labels and comments are already the shared coordination layer all agents
  can inspect between sessions.

Under the old model, a PR could merge cleanly and still require a second
state-only close-out PR just to remove a `_active.md` section or move a
`coordination.md` lock. That second PR was not adding product value; it was
writing GitHub-derived facts back into a manual mirror. The mirror then
became stale whenever the follow-up was skipped or delayed.

This has happened in practice. Current `_active.md` sections and
`coordination.md` locks can remain active after the associated PRs have
merged or closed. That drift is evidence that checked-in markdown should not
be the primary live state machine for GitHub-connected work.

This ADR supersedes in part:

- ADR-009's assumption that `coordination.md` is the primary live lock board;
- ADR-018's assumption that `_active.md` is the active multi-task snapshot;
- ADR-021's interim close-out PR discipline and session-state cadence where
  they require repo-local live-state writes for normal GitHub-connected work.

The decision deliberately does **not** delete `.context/**`. Rules,
decisions, postmortems, session retrospectives, and reusable prompts remain
durable in-tree knowledge.

## Decision

Use GitHub as the primary **live coordination** state machine for normal
agent work, and keep in-tree files for durable knowledge.

The source-of-truth split is:

1. **GitHub issue body** — durable feature/task contract and problem-framing,
   planning, and critical-review input. The existing feature-request issue template
   remains canonical for problem statement, proposed solution, user outcome,
   acceptance criteria, and technical considerations.
2. **GitHub PR body** — implementation review contract: linked issue, plan
   links, implementation summary, verification results, and doc-sync notes.
3. **Latest `agent-state:v1` issue/PR comment** — mutable live
   coordination: status, since-last-update delta, blockers/awaiting state,
   next 1–3 actions, and handoff baton.
4. **GitHub labels** — coarse workflow filtering only in v1:
   `agent:claimed`, `agent:blocked`, and `agent:awaiting-review`.
5. **Durable in-tree knowledge** — `.context/00_INDEX.md`,
   `docs/decisions/**`, `docs/postmortems/**`, and repository operating policy.
6. **Reusable procedures** — `.github/prompts/**` remain procedural prompts,
   not active task-state stores.
7. **Legacy/manual live-state surfaces** — `_active.md`, `coordination.md`,
   `task_*.md`, and `handoff_*.md` are no longer required as the normal
   primary live-state path for GitHub-connected work. They may remain as
   transitional compatibility views while old branches drain.

### `agent-state:v1` cadence

Agents update or post the latest `agent-state:v1` comment:

- at task start;
- before every wait-for-input pause, including clarification questions,
  plan approval pauses, review-feedback pauses, and "what next?" pauses;
- before continuing after a runtime auto-summary;
- before a role/agent handoff;
- before a session ends while the task is not merged/closed;
- at close-out, with `Status: done`.

The comment is intentionally slim. It must not become a second PR body,
verification matrix, file list, or retrospective essay.

The template intentionally has **no separate `Pause reason` field** —
`Status` already carries that signal (`awaiting_user_input`, `blocked`,
`handoff_needed`) and a second free-text field invites contradiction
between the two surfaces. Long decision history, full file lists,
verification matrices, and durable decisions stay out of the comment; they
belong in plan comments, PR bodies, ADRs, postmortems, and CI respectively.

### Completed outcomes stay in GitHub

Issue and PR history preserve what shipped, implementation evidence, review
discussion, and closeout status. This avoids maintaining a repo-local mirror of
the same task lifecycle. Existing date-stamped session archives remain
historical records only.

`docs/postmortems/**` remain the durable surface for formal incident/failure
analysis. ADRs remain durable design decisions. `AGENTS.md` remains enforceable
operating policy.

### Relationship to #262, #263, and #299

- #262 `make closeout` remains a transitional/fallback validator for legacy
  repo-local state during migration. It is not the normal future path for
  GitHub-connected work.
- #298 supersedes #263 as the forward design. #263's repo-local write-back
  automation should be closed as superseded or reduced to narrow temporary
  compatibility only.
- #299 owns retention policy for the historical session archives that predate
  the 2026-07-22 amendment.

### Failure mode when GitHub is unavailable

If GitHub API access is unavailable, the agent may temporarily keep local
notes using the `agent-state:v1` template. Those notes are scratch until
copied into the issue or PR comment. Do not commit local live-state notes as
the normal coordination path.

## Options Considered

### Option 1: Keep repo-local live state and enforce cleanup harder

- **Pros**: Works without GitHub API access; preserves existing scripts and
  checks.
- **Cons**: Does not solve the mechanical root cause. PR numbers, labels,
  comments, merge state, and close events still originate in GitHub, so every
  cleanup requires a mirror write. Drift remains likely.

### Option 2: Automate repo-local write-back (#263)

- **Pros**: Reduces manual cleanup under the old design; could generate
  compatibility views.
- **Cons**: Automates the mirror instead of removing it. Adds permission,
  fork, draft-PR, bot-PR, and direct-write edge cases for state that already
  exists in GitHub.

### Option 3: GitHub-first live state with durable in-tree knowledge (chosen)

- **Pros**: Aligns live state with the system that owns issue/PR lifecycle
  events; removes the normal second state-only PR; keeps rules, ADRs,
  postmortems, prompts, and operating policy portable in the repo.
- **Cons**: Requires agents to read GitHub comments/labels in addition to
  repo files. Offline operation needs a temporary local scratch fallback.

### Option 4: Move all state, including lessons and decisions, to GitHub

- **Pros**: Single platform for every record.
- **Cons**: Loses template portability, grep-able repo history, fork-friendly
  durable lessons, ADR discipline, and downstream project reuse. Rejected.

### Option 5: Workflow validator enforcing `agent-state:v1` comment presence in v1

- **Pros**: Prevents the cadence from being silently skipped; surfaces
  drift via CI rather than via human review.
- **Cons**: Premature for v1. Edge cases around draft PRs, bot PRs, old
  PRs, fork PRs, permission-constrained events, and pre-convention
  branches all need careful handling that real usage hasn't yet
  clarified. Deferred to v2 once the failure modes are understood.

## Consequences

### Positive

- Normal GitHub-connected work no longer needs a second PR purely for live
  state cleanup.
- A fresh agent can resume from the issue body, linked PR, latest
  `agent-state:v1` comment, labels, and relevant repo rules without relying
  on drift-prone manual mirrors.
- Existing problem-framing, user-outcome, and review inputs in feature-request
  issues remain stable and are not moved into mutable comments.
- Durable decisions and incident analysis remain in-tree for template consumers
  and forks without duplicating routine task history.

### Negative

- Agents without GitHub access need a documented scratch fallback and must
  remember to copy that state into GitHub when access returns.
- Existing scripts and tests that assumed `_active.md` / `coordination.md`
  are primary live state need compatibility wording or updated invariants.
- Querying comments is less visually compact than reading one local markdown
  file, so the comment schema must stay lean and versioned.

### Neutral

- Existing `_active.md` sections and `coordination.md` locks may be stale.
  They are migration evidence, not v1 blockers. They may drain naturally or
  be cleaned in a separate legacy cleanup PR.
- `agent-coordination-sync.yml` can remain a transitional compatibility
  helper, but v1 does not add mandatory `agent-state:v1` validation or
  automatic upsert workflows.

## Implementation

- [x] Add `.context/state/agent_state_comment_template.md`.
- [x] Delete `.context/state/task_template.md` and
  `.context/state/handoff_template.md`.
- [x] Update session-state, role-selection, ownership, and doc-maintenance
  rules for GitHub-first live state.
- [x] Update onboarding prompts, PR template, AI_REPO_GUIDE, and the
  multi-agent coordination guide.
- [x] Add only the three v1 labels: `agent:claimed`, `agent:blocked`, and
  `agent:awaiting-review`.
- [x] Update tests and install/setup file lists for the new template set.

### Out of scope for this ADR

- Replacing or bypassing the existing `feature_request.md` issue-body
  contract (preserved as the durable problem-framing and review input).
- Rewriting date-stamped session archives that predate the 2026-07-22 amendment.
- Removing `.github/prompts/**` reusable procedural prompts.
- Workflow validation enforcing `agent-state:v1` comment presence on
  every in-flight issue/PR (deferred to v2 — see Option 5).
- Auto-upsert / synthesis automation for `agent-state:v1` comments
  (deferred to v2).
- Larger `agent:*` label taxonomy beyond the three v1 labels.
- Continuing #263-style repo-local write-back automation as a primary
  design direction.
- Bulk reconciliation of pre-existing stale `_active.md` /
  `coordination.md` entries (left to a separate legacy cleanup PR; old
  branches in flight may continue using the legacy fallback through
  their existing close-out PR).
- Archive retention / pruning policy (owned by #299).
- Dashboard UI for agent state.

## Verification

- `./scripts/verify-env.sh`
- `bash test.sh`
- `bash scripts/checks/050-agent-mirror.sh`
- Grep audit for old live-state terms; any remaining references must be
  legacy/compatibility/migration wording rather than primary-state
  instructions.

## References

- Issue #298 — GitHub Issues and PRs as the primary agent state machine.
- Issue #262 — `make closeout` enforcement for the old repo-local model;
  retained as transitional fallback.
- Issue #263 — repo-local closeout automation superseded by this ADR.
- Issue #299 — session archive retention and promotion policy (deferred
  from #298).
- Issue #220 — parent epic on cost mitigation (ADR-019 is downstream of
  the same epic).
- ADR-005 / ADR-014 - historical Analyst pre-flight gates superseded by
  ADR-031; `feature_request.md` remains the durable task contract.
- ADR-007 — auto-resolve bot-authored review threads; unaffected
  (operates on review threads, not live-state files).
- ADR-009 — parallel multi-agent execution + dispatch reality matrix; PM
  mediates from a single live-state surface per work item.
- ADR-011 — plan-as-comment requirement; preserved.
- ADR-012 — explicit workflow preconditions (branch-first rule);
  preserved.
- ADR-015 — postmortem feedback loop; postmortems remain durable in-tree
  knowledge.
- ADR-018 — multi-task `_active.md` schema; preserved as legacy
  compatibility view (status: "Accepted (superseded in part by ADR-025)").
- ADR-019 — per-role model tiering; preserved.
- ADR-020 — orchestration patterns reference; P3 (Mediator) and P7
  (Owner-Keyed Concurrent State) examples updated to cite
  `agent-state:v1` as the current canonical example where applicable.
- ADR-021 — AGENTS.md decomposition; preserved (per-concern files remain
  authoritative; only the cadence body inside `process_session_state.md`
  changes; status: "Accepted (superseded in part by ADR-025)").
- ADR-023 — canonical/overlay role decomposition; preserved (any PM
  `description:` change must remain byte-mirrored across overlays via
  `scripts/checks/050-agent-mirror.sh`).
