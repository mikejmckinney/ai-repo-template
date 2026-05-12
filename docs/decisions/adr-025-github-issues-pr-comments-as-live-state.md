# ADR-025: GitHub Issues, PRs, comments, and labels as live agent state

## Status

Accepted

## Date

2026-05-12

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

1. **GitHub issue body** — durable feature/task contract and Analyst /
   Judge / Critic gate input. The existing feature-request issue template
   remains canonical for problem statement, proposed solution, user outcome,
   acceptance criteria, and technical considerations.
2. **GitHub PR body** — implementation review contract: linked issue, plan
   links, implementation summary, verification results, and doc-sync notes.
3. **Latest `agent-state:v1` issue/PR comment** — mutable live
   coordination: status, since-last-update delta, blockers/awaiting state,
   next 1–3 actions, and handoff baton.
4. **GitHub labels** — coarse workflow filtering only in v1:
   `agent:claimed`, `agent:blocked`, and `agent:awaiting-review`.
5. **Durable in-tree knowledge** — `.context/rules/**`, `.context/00_INDEX.md`,
   `docs/decisions/**`, `docs/postmortems/**`, `.context/sessions/latest_summary.md`,
   and `.context/sessions/*` archives.
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
verification matrices, and durable retrospective lessons stay out of the
comment; they belong in plan comments, PR bodies, ADRs, CI, and session
summaries respectively.

### Durable retrospectives stay in-tree

`.context/sessions/latest_summary.md` and session archives remain canonical
for durable retrospective lessons: `What Shipped`, `Harder Than Expected`,
and `Generalizable Lessons`. They are not the live coordination baton.

For normal PR-backed work, the session-summary rotation boundary moves to PR
merge/closeout because the landed PR is the stable provenance boundary. For
abandoned or no-PR work, archive only when there are durable lessons worth
preserving.

`docs/postmortems/**` remain the durable surface for formal incident/failure
analysis. ADRs remain durable design decisions. `.context/rules/**` remain
enforceable operating policy.

### Relationship to #262, #263, and #299

- #262 `make closeout` remains a transitional/fallback validator for legacy
  repo-local state during migration. It is not the normal future path for
  GitHub-connected work.
- #298 supersedes #263 as the forward design. #263's repo-local write-back
  automation should be closed as superseded or reduced to narrow temporary
  compatibility only.
- #299 owns bounded session archive retention and promotion policy. This ADR
  preserves session summaries but does not define pruning or retention limits.

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
  postmortems, prompts, and retrospective lessons portable in the repo.
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
- Existing Analyst/Judge/Critic gate inputs in feature-request issues remain
  stable and are not moved into mutable comments.
- Durable lessons remain in-tree for template consumers and forks.

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
  contract (preserved unchanged as the durable Analyst/Judge/Critic gate
  input).
- Demoting `.context/sessions/latest_summary.md` and date-stamped
  archives (preserved as canonical durable retrospective surface).
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
- ADR-005 / ADR-014 — Analyst pre-flight gate; preserves
  `feature_request.md` as the durable gate input contract.
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
