# ADR-025: GitHub-first agent live coordination state

## Status

Accepted

## Date

2026-05-12

## Context

Agent live coordination in this repo currently lives in repo-local
markdown mirrors under `.context/state/`: `_active.md` (per-branch task
sections), `coordination.md` (lock board + Recent History), and the
copied templates `task_template.md` / `handoff_template.md`. The
`.context/sessions/latest_summary.md` working log was also expected to
be touched at every wait-for-input pause as part of the same cadence
(see ADR-021's extraction of those rules into
`.context/rules/process_session_state.md`).

That model has demonstrated three structural problems in real sessions:

1. **State drift.** GitHub owns the authoritative lifecycle events
   (issue assignment, PR open, PR close, PR merge, label changes) but
   `_active.md` sections and `coordination.md` locks must be cleaned up
   by a separate human or agent action. They drift stale routinely;
   #298 enumerated several examples in the issue body.
2. **Mechanical second-PR requirement.** PR numbers, final close/merge
   state, and lock-release timing are knowable only *after* the PR is
   created or merged. Under the branch-first rule in
   `.context/rules/process_work_style.md`, writing those facts back into
   tracked markdown forces a second branch and PR. The interim
   `chore(closeout): PR #NNN` discipline in
   `process_session_state.md` exists precisely because of this. ADR-021
   acknowledged it as interim "until #263".
3. **Surface multiplication.** Each additional file an agent must
   remember to update raises the probability that one will go stale.
   The session-cadence file currently lists five things to re-read at
   every task boundary.

#263 proposed automating the old model by writing GitHub-derived
closeout facts back into the repo-local files. That preserves the
write-back path rather than removing the need for it.

The split this ADR ratifies separates **mutable live coordination**
(short-lived; lifecycle-bound; needs to live where GitHub already owns
the truth) from **durable in-tree knowledge** (long-lived; portable to
forks; useful without GitHub API access). The existing
`feature_request.md` issue-body template already carries the durable
gate input that Analyst, Judge, and Critic rely on; ADR-025 preserves it
unchanged. `.context/sessions/latest_summary.md` and date-stamped
archives carry retrospective lessons that have no good GitHub-only
equivalent (search across forks, grep without API access, downstream
template consumers); ADR-025 preserves them as canonical durable
knowledge and only changes their cadence trigger.

## Decision

Adopt a **GitHub-first live coordination model** for normal agent work,
with durable in-tree knowledge preserved as a separate layer:

```text
Issue body                          = durable feature/task contract and gate input
PR body                             = implementation/review/verification contract
Latest agent-state:v1 comment       = mutable live coordination + handoff baton
GitHub labels                       = coarse workflow filtering only
.context/sessions/latest_summary.md = durable retrospective lessons
.context/sessions/<date>_*.md       = durable retrospective archives
.context/rules/**                   = enforceable operating policy
docs/decisions/**                   = durable design decisions
docs/postmortems/**                 = formal incident/failure analysis
.github/prompts/**                  = reusable procedural prompts
```

Source-of-truth hierarchy (highest first):

1. GitHub issue body — durable task/feature contract; Analyst/Judge/Critic gate input.
2. GitHub PR body — implementation review contract, linked issue, plan links, verification summary.
3. Latest `agent-state:v1` issue/PR comment — mutable live state: since-last-update, blocker/awaiting state, next 1–3 actions, handoff baton.
4. GitHub labels — coarse workflow filtering only: `agent:claimed`, `agent:blocked`, `agent:awaiting-review`.
5. Durable in-tree knowledge — `.context/rules/**`, `.context/00_INDEX.md`, ADRs, postmortems, session summaries and archives.
6. `.github/prompts/**` — reusable procedures, not active task state.
7. Removed/superseded — `task_template.md`, `handoff_template.md`, normal required `_active.md` / `coordination.md` live-state updates.

**The slim `agent-state:v1` comment template** (canonical body lives in
`.context/state/agent_state_comment_template.md`):

```markdown
<!-- agent-state:v1 issue:NNN pr:MMM branch:feature/example role:devops -->

**Status:** in_progress | awaiting_user_input | blocked | awaiting_review | handoff_needed | done
**Updated:** YYYY-MM-DDTHH:MM:SSZ

## Since last update
- ...

## Blockers / awaiting
- None

## Next 1–3 actions
1. ...

## Handoff
**To:** self / next session / analyst / architect / judge / critic / pm / frontend / backend / qa / devops / docs

<Only fill when pausing, transferring ownership, or leaving work. One or two sentences max.>
```

The template intentionally has **no separate `Pause reason` field** —
`Status` already carries that signal and a second field invites
contradiction. Long decision history, full file lists, verification
matrices, and retrospective lessons stay out of the comment; those
belong in plan comments, PR bodies, ADRs, CI, and session summaries
respectively.

**v1 label set:**

- `agent:claimed`
- `agent:blocked`
- `agent:awaiting-review`

No additional `agent:planning` / `agent:implementing` / `agent:handoff-needed`
/ `agent:ready` / `agent:done` labels in v1. The `Status:` field in the
structured comment carries finer-grained state. Promote labels only
when a workflow or filter actually needs them.

**Cadence preservation.** The mid-task durability discipline from
`process_session_state.md` is preserved; only the write target changes:

- At task start: post or update the latest `agent-state:v1` comment.
- At every wait-for-input pause, no exceptions (clarification questions,
  plan-mode approval, review-feedback waits, "what next?" pauses):
  refresh the comment before waiting.
- At durability-risk boundaries: refresh the `Handoff` section before
  proceeding when the conversation exceeds ~30 turns, the runtime
  auto-summarizes mid-flight, the session ends mid-task, or work moves
  to a different role/agent.
- At closeout: set `Status: done`. Durable retrospective lessons land in
  `.context/sessions/latest_summary.md` at PR merge/closeout (see Phase
  6 rotation guidance in `.context/sessions/README.md`).

**Migration policy (forward-looking).** This v1 PR does **not**
reconcile every stale `_active.md` section or `coordination.md` lock.
Existing entries may drain naturally under the old rules or be cleaned
in a separate legacy cleanup PR. After ADR-025 lands, normal work stops
creating new `_active.md` sections, new `coordination.md` locks, and
new `task_*.md` / `handoff_*.md` files. Old branches in flight at the
time of merge may continue using the legacy fallback through their
existing close-out PR. New branches use the GitHub-first path.

**Relationship to ADR-018, ADR-021, ADR-007, and #263.** ADR-018's
multi-section `_active.md` schema is preserved as a legacy/compatibility
view; the file remains in the tree with a header note marking it
non-primary. ADR-021's per-concern decomposition of session-state rules
stands; only the cadence body inside `process_session_state.md`
changes. ADR-007 (auto-resolve bot-authored review threads) is
unaffected — it operates on review threads, not live-state files.
**#263 is superseded by ADR-025.** ADR-025 dissolves the mechanical
need that #263 was designed to automate (write-back of post-merge facts
to repo-local files). #263 should be closed as superseded; any narrow
compatibility helper that surfaces from this work would land in a
follow-up issue with a fresh ADR if needed.

**`make closeout` / `scripts/closeout.sh`.** Retained as a transitional
fallback validator for old branches and offline work that still uses
repo-local live-state files. It is no longer the normal path for
GitHub-connected work after ADR-025.

**`feature_request.md` issue-body template.** Preserved unchanged. It
remains the durable gate input for Analyst, Judge, and Critic. Live
agent state belongs in the latest `agent-state:v1` comment, not in the
issue body.

**Offline / GitHub-API-unavailable fallback.** If GitHub API access is
unavailable, agents may temporarily record the same `agent-state:v1`
content in a local scratch note and copy it into the issue/PR comment
once access returns. This is explicitly a fallback, not the normal
path.

## Options Considered

### Option 1: GitHub-first split, preserve durable in-tree knowledge (chosen)

- **Pros**: Removes the mechanical need for second closeout PRs.
  Eliminates the drift class where GitHub lifecycle events outpace
  manual markdown cleanup. Preserves the existing feature-request gate
  contract and the durable retrospective layer that ships with the
  template to forks. Cheapest possible v1: docs + templates +
  role/overlay sweep + label setup.
- **Cons**: Requires every active role file to be re-checked for
  state-surface references. Requires three additions to the label
  setup. Requires CI invariants (010, 015) to be adjusted for the
  template add/removes. Bias risk: agents accustomed to scanning
  `_active.md` first may briefly miss live state until onboarding
  prompts and AI_REPO_GUIDE catch up — mitigated by Phase 4 onboarding
  rewrites.

### Option 2: Continue the repo-local model and ship #263 as designed

- **Pros**: Smaller diff. Preserves continuity for any tooling that
  assumes the file-based view.
- **Cons**: Doesn't solve drift. Adds a write-back automation surface
  that itself needs maintenance. Still requires a closeout PR's worth
  of tracked-file edits per merge. The `_active.md` and
  `coordination.md` mirrors stay as the agent-visible truth alongside
  GitHub, doubling the surfaces an agent must consult.

### Option 3: Delete `.context/state/**` entirely and put everything in GitHub

- **Pros**: Zero file surface to drift.
- **Cons**: Loses the legacy compatibility view and the offline
  fallback. Breaks the downstream-template-consumer experience for
  forks that don't yet use the GitHub-first path. Aggressive cleanup
  not justified by any acceptance criterion in #298.

### Option 4: Move durable lessons into PR descriptions or GitHub Discussions

- **Pros**: Pushes more state into GitHub.
- **Cons**: Loses grep-without-API-access. Loses portability to forks.
  Fragments durable knowledge across PR descriptions (which close) and
  Discussions (which not all forks enable). The retrospective layer is
  precisely the layer that benefits most from in-tree storage.

### Option 5: Workflow validation enforcing `agent-state:v1` comment presence on every in-flight issue/PR

- **Pros**: Prevents the cadence from being silently skipped.
- **Cons**: Premature for v1. Edge cases around draft PRs, bot PRs, old
  PRs, fork PRs, permission-constrained events, and pre-convention
  branches all need careful handling. Deferred to v2 once real usage
  clarifies the failure modes.

## Consequences

### Positive

- Normal work no longer requires a second state-only PR for closeout
  bookkeeping.
- The drift class (`_active.md` / `coordination.md` entries outliving
  their PRs) goes away for new work.
- Onboarding starts from the assigned issue and proceeds outward — the
  natural reading order — instead of starting in repo-local mirrors.
- Agents have one canonical live-state surface per work item (the
  latest `agent-state:v1` comment), versioned for future schema
  changes.
- Durable retrospective lessons remain searchable in-tree via
  `.context/sessions/`.
- ADR-023's canonical/overlay parity is preserved: PM `description:`
  changes propagate to both platform overlays via the existing mirror
  check.

### Negative

- One more file kind in `.context/state/` (the new comment template),
  alongside two deletions.
- Some legacy branches may continue using the old close-out PR
  discipline through their natural termination; readers may temporarily
  see both styles in the recent git history.
- Anyone scripting against `_active.md` / `coordination.md` schema
  needs to know they are now compatibility/legacy views, not
  authoritative live state.

### Migration steps

The v1 PR ships:

1. ADR-025 (this file).
2. Status updates on superseded ADRs: ADR-018 marked partially
   superseded by ADR-025 (its multi-section schema is preserved as
   legacy compatibility, not as the primary surface).
3. Cadence rewrite in `.context/rules/process_session_state.md`.
4. State-directory README rewrite + compatibility-note headers in
   `_active.md` and `coordination.md`.
5. Sessions README rewrite (durable-lesson framing + PR-merge rotation
   trigger).
6. Deletion of `task_template.md` and `handoff_template.md`.
7. Addition of `.context/state/agent_state_comment_template.md`.
8. Role-file sweep across all 10 canonical `.agents/*.md` files.
9. PM `description:` parity update to `.github/agents/pm.agent.md` and
   `.claude/agents/pm.md`.
10. Onboarding prompt rewrite + PR template pointer + AI_REPO_GUIDE
    refresh.
11. Three new labels in `scripts/setup/40-ensure-labels.sh` and the
    `docs/guides/agent-pipeline.md` label table.
12. CI-invariant updates: `010-required-files.sh`, `015-context-pack.sh`,
    `125-adr018-invariants.sh`. `install.sh` `MULTIAGENT_FILES` list.
13. Doc-sync trigger row in `process_doc_maintenance.md` updated to
    reflect ADR-025.

Subsequent issues will track:

- Workflow validator for `agent-state:v1` comment presence (deferred
  v2).
- Auto-upsert/synthesis automation (deferred v2).
- Archive retention/pruning policy (#299).
- Bulk reconciliation of pre-existing stale `_active.md` /
  `coordination.md` entries (separate legacy cleanup PR).

### Out of scope for this ADR

- Replacing or bypassing the existing feature-request issue-body
  contract.
- Demoting `.context/sessions/latest_summary.md` and archives.
- Removing `.github/prompts/**` procedural prompts.
- Introducing a dashboard UI for agent state.
- Larger `agent:*` label taxonomy.
- Continuing #263-style automation as a primary design direction.

## References

- Issue #298 — feature request defining the GitHub-first model and
  scope.
- Issue #263 — superseded by this ADR.
- Issue #262 — `make closeout` enforcement; retained as transitional
  fallback.
- Issue #299 — bounded session archive retention/promotion policy
  (deferred from #298).
- Issue #220 — parent epic on cost mitigation; ADR-019 (per-role model
  tiering) is downstream of the same epic.
- ADR-005 / ADR-014 — Analyst pre-flight gate; preserves
  `feature_request.md` as the durable gate input contract.
- ADR-007 — auto-resolve bot-authored review threads; unaffected
  (operates on threads, not live-state files).
- ADR-009 — parallel multi-agent execution + dispatch reality matrix;
  PM mediates from a single live-state surface per work item.
- ADR-011 — plan-as-comment requirement; preserved.
- ADR-012 — explicit workflow preconditions (branch-first rule);
  preserved.
- ADR-015 — postmortem feedback loop; postmortems remain durable
  in-tree knowledge.
- ADR-018 — multi-task `_active.md` schema; preserved as legacy
  compatibility view (status flips to "Accepted (superseded in part by
  ADR-025)").
- ADR-019 — per-role model tiering; preserved.
- ADR-020 — orchestration patterns reference; P3 (Mediator) and P7
  (Owner-Keyed Concurrent State) examples updated to cite
  `agent-state:v1` as the current canonical example.
- ADR-021 — AGENTS.md decomposition; preserved (per-concern files
  remain authoritative; only the cadence body inside
  `process_session_state.md` changes).
- ADR-023 — canonical/overlay role decomposition; preserved (PM
  `description:` change is byte-mirrored across overlays via
  `scripts/checks/050-agent-mirror.sh`).
