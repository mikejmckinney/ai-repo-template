# ADR-025: GitHub Issues and PRs as the primary agent state machine

## Status

Accepted

## Date

2026-05-12

## Context

The repo previously asked agents to preserve continuity by manually maintaining several repo-local markdown files under `.context/state/`:

- `_active.md` — multi-task working board (ADR-018).
- `coordination.md` — claim board / lock release.
- `task_<slug>.md` — per-task progress files (copied from `task_template.md`).
- `handoff_<slug>.md` — cross-session/cross-role baton (copied from `handoff_template.md`).

In practice this approach has produced four observed problems:

1. **Duplicate state.** Agents already work from a GitHub issue and (once code lands) a GitHub PR. The repo-local files mirror state that already exists in GitHub.
2. **Mandatory second close-out PR.** ADR-018 / ADR-016-era discipline requires a `chore(closeout): PR #NNN merged` follow-up branch to release the lock and prune the `## Task:` section after a PR merges, because that information is only knowable post-merge and the branch-first rule forbids editing `main` directly. See `.context/rules/process_session_state.md` § "Close-out PR discipline (interim, until #263)".
3. **State drift.** `_active.md` sections and `coordination.md` locks routinely remain active after the related PRs have merged or closed because the authoritative lifecycle event happens in GitHub while the markdown mirror requires a separate human/agent action. ADR-018 Amendment #1 and postmortem-001 both record drift cases.
4. **Bypass risk.** The more live-state surfaces an agent must remember to update, the more likely one will silently go stale — and stale state is worse than no state because the next session trusts it.

`make closeout` from #262 raised the floor on enforcement, and #263 proposed automating the write-back. But both approaches still treat repo-local markdown as the source-of-truth for live coordination — they just lower the cost of keeping the mirror current.

The mechanical root cause of the second close-out PR is that PR numbers, final close/merge state, lock release, and coordination history are only known *after* PR open/close, and the branch-first rule means writing them back into tracked markdown requires another branch and another PR. GitHub already records all of those facts as first-class events.

A separate concern: not all in-tree state is bad. `.context/sessions/latest_summary.md`, archived session summaries, ADRs, postmortems, rules, and prompts carry **durable repo knowledge** that grep-able / fork-portable / API-free agents need. That knowledge should stay in-tree.

## Decision

Adopt a **GitHub-first live coordination model** with a clean split between mutable live state (in GitHub) and durable repo knowledge (in-tree).

### Source-of-truth hierarchy

```text
1. GitHub issue body
   Durable feature/task contract used by Analyst, Judge, and Critic gates.

2. GitHub PR body
   Implementation review contract: linked issue, plan links, verification summary.

3. Latest `agent-state:v1` issue/PR comment
   Mutable live coordination state: since-last-update delta, blockers/awaiting,
   next 1–3 actions, handoff baton.

4. GitHub labels
   Coarse workflow filtering only: agent:claimed, agent:blocked,
   agent:awaiting-review.

5. Durable in-tree knowledge
   .context/rules/**, .context/00_INDEX.md, docs/decisions/**,
   docs/postmortems/**, .context/sessions/latest_summary.md, and
   .context/sessions/* archives.

6. .github/prompts/**
   Reusable procedures, not active task state.

7. Removed/superseded live-state surfaces
   .context/state/task_template.md (deleted), .context/state/handoff_template.md
   (deleted), required manual _active.md / coordination.md live-state updates.
```

### What changes

- **Delete `.context/state/task_template.md`.** The GitHub issue body — particularly the existing `.github/ISSUE_TEMPLATE/feature_request.md` fields (Problem Statement, Proposed Solution, User Outcome, Acceptance Criteria) — already carries the durable task contract. Per-task `task_<slug>.md` files are no longer required.
- **Delete `.context/state/handoff_template.md`.** Handoffs become a `## Handoff` section in the latest `agent-state:v1` issue/PR comment.
- **Add `.context/state/agent_state_comment_template.md`** as the canonical copy/paste template for the live coordination comment. The template intentionally has only `Status`, `Updated`, `Since last update`, `Blockers / awaiting`, `Next 1–3 actions`, and `Handoff`. There is no `Pause reason` field — `Status` carries that information and the two would contradict.
- **Update `.context/rules/process_session_state.md`** so the cadence — every wait-for-input pause, ~30-turn handoff, runtime auto-summary, session-end-before-merge — writes to the latest `agent-state:v1` comment, not to `task_*.md` / `handoff_*.md`.
- **Reframe `_active.md` and `coordination.md`** as deprecated/legacy surfaces. They are not the source-of-truth for live coordination going forward. Existing entries may drain naturally or be cleaned up in a separate legacy-cleanup PR.
- **Preserve the feature-request issue-body template** at `.github/ISSUE_TEMPLATE/feature_request.md` exactly as-is. Analyst / Judge / Critic gates continue to consume those fields; this ADR does **not** move gate inputs into mutable comments.
- **Preserve `.context/sessions/latest_summary.md` and archives** as the canonical durable retrospective surface for `What Shipped`, `Harder Than Expected`, and `Generalizable Lessons`. Live coordination moves to GitHub comments; durable lessons stay in-tree.
- **Shift session-summary rotation** from "new agent starts a fresh task" to PR merge / closeout for normal PR-backed work. The landed PR is the stable provenance boundary for retrospective lessons. Abandoned/no-PR work archives only when there are durable lessons worth preserving.
- **Limit v1 labels** to `agent:claimed`, `agent:blocked`, `agent:awaiting-review`. The `Status` field inside the structured comment carries finer-grained state.
- **Preserve `make closeout` from #262** as a transitional/fallback validator for legacy repo-local state during migration.

### Why #263 is superseded

#263 proposed automating the old repo-local close-out write-back path under an opt-in `auto-coordinate` label. The mechanical justification for that automation was that PR numbers, merge state, and lock release are only knowable post-merge, and the branch-first rule requires a follow-up PR to record them in tracked markdown.

GitHub-first removes that justification entirely: PR numbers, labels, comments, and close events already live in GitHub and update on the authoritative lifecycle event. Nothing needs to be written back into the repo purely to record live close-out state.

**#263 is therefore superseded by this ADR** and should be closed as `superseded`. If a narrow temporary compatibility task is needed (e.g., generated views that read GitHub state and emit a read-only `_active.md` mirror), it should be tracked as a smaller follow-up issue, not as the forward-looking design.

### Why current state-drift is a motivator, not a blocker

The current `_active.md` sections and `coordination.md` locks already contain stale entries — locks for PRs that merged or closed without the corresponding markdown cleanup. Reconciling all of that drift in this v1 PR would expand scope and create merge conflicts with in-flight branches. Instead:

- v1 is forward-looking: stop creating new `_active.md` sections / `coordination.md` locks for normal work after this lands.
- Existing entries may drain naturally under old rules or be handled by a separate legacy-cleanup PR.
- The drift itself is evidence the GitHub-first migration is the right call.

## Cadence preservation

The mid-task durability discipline from `.context/rules/process_session_state.md` is preserved. Only the **write target** changes: the latest `agent-state:v1` issue/PR comment instead of `task_*.md` / `handoff_*.md`.

- **Task start.** Post or update the latest `agent-state:v1` comment.
- **Every wait-for-input pause, no exceptions.** Update the comment before waiting for user input. This includes mid-task clarification questions, plan-mode approval pauses, review-feedback pauses, and "what next?" pauses. Write now; do not defer until close-out or merge.
- **Durability-risk boundaries.** Update the comment's `Handoff` section before proceeding when ANY of the following fires:
  - A single conversation exceeds ~30 turns.
  - The runtime auto-summarizes mid-flight (treat as the loudest possible signal that you've blown past the ~30-turn threshold; write the handoff *before* responding to the next message).
  - The session ends and the task is not yet merged/closed.
  - Work moves to a different role/agent.
- **Close-out.** Set `Status: done` in the `agent-state:v1` comment. Retrospective lessons (`What Shipped`, `Harder Than Expected`, `Generalizable Lessons`) land in `.context/sessions/latest_summary.md` at PR merge or close-out.

Ephemeral chat-only state (the LLM tool's in-conversation todo list, `/memories/session/`) remains an agent-private scratch surface — invisible to any other session — and is never an acceptable substitute for the structured comment.

## Failure mode: GitHub API unavailable

If GitHub API access is temporarily unavailable, agents may record the `agent-state:v1` content in a local note (e.g., `/memories/session/agent-state.md`), then copy it into the issue/PR comment as soon as GitHub is reachable. Local notes are a fallback, not the normal path. Do not commit live-state files as a workaround.

## Options Considered

1. **Status quo (manual repo-local files).** Continues to produce drift, mandatory second close-out PRs, and bypass risk. Rejected.
2. **#263-style write-back automation.** Automates the old model but keeps the mirror as source-of-truth. Doesn't address drift root cause; adds opt-in label complexity. Rejected as forward path.
3. **Workflow validator that requires `agent-state:v1` on every in-flight issue/PR.** Premature in v1; would create churn around fork PRs, draft PRs, bot PRs, and pre-convention PRs. Deferred to v2 after real usage clarifies edge cases.
4. **Move gate inputs into mutable comments.** Would invalidate the existing Analyst / Judge / Critic preflight contract built on the feature-request issue body. Rejected.
5. **Demote `latest_summary.md` to legacy.** Would eliminate the canonical durable retrospective surface that ships to downstream template consumers, survives forks, and is grep-able without GitHub API access. Rejected.
6. **Adopt GitHub-first live coordination, preserve in-tree durable knowledge.** Selected.

## Consequences

### Positive

- Removes the mandatory second close-out PR for normal PR-backed work.
- Eliminates the repo-local state-drift class of bug at its mechanical root cause.
- Reduces the number of live-state surfaces an agent must remember to update from four (`_active.md`, `coordination.md`, `task_*.md`, `handoff_*.md`) to one (the latest `agent-state:v1` comment).
- Preserves the existing Analyst / Judge / Critic gate contract on the feature-request issue body.
- Preserves durable retrospective lessons in-tree, fork-portable, grep-able.
- Establishes a slim, schema-stable comment format that future automation can parse without a workflow blocker in v1.

### Negative

- One-time migration cost across docs, role files, prompts, and onboarding.
- Existing branches with in-flight `task_*.md` / `handoff_*.md` files remain valid until they merge; reviewers see a transitional period where both styles exist.
- Agents in environments without GitHub API access need the documented fallback path.
- Stale legacy `_active.md` / `coordination.md` entries persist until a separate cleanup PR drains them.

### Neutral

- The `agent-state:v1` HTML-comment marker is recognizably structured for future parsers (e.g., a "list in-flight roles" workflow) without requiring a workflow gate in v1.
- `make closeout` continues to work as a transitional validator; no breaking change to the script.

## Supersedes / superseded by

- **Supersedes** #263 (opt-in repo-local closeout write-back automation) as the forward-looking design.
- **Does not supersede** ADR-018 (multi-task `_active.md` schema) outright — ADR-018's schema stays valid for the legacy/transitional period; v1 just stops requiring new entries.
- **Does not supersede** the close-out PR discipline rule in `.context/rules/process_session_state.md` for in-flight branches that already started under the old model.

## References

- Issue #298 — this design.
- Issue #263 — superseded.
- Issue #299 — bounded session archive retention/promotion (out of scope for this ADR; preserves session summaries as durable lessons).
- ADR-018 — multi-task `_active.md` schema (legacy/transitional).
- ADR-018 Amendment #1 — required `PR` field on `_active.md` sections (legacy/transitional).
- ADR-021 — AGENTS.md decomposition into `.context/rules/process_*.md`.
- ADR-023 — shared subagent canonical files at `.agents/<role>.md`.
- `.context/rules/process_session_state.md` — close-out discipline (cadence preserved; write target changes).
- `.context/state/agent_state_comment_template.md` — the canonical live-coordination comment template introduced by this ADR.
- `.github/ISSUE_TEMPLATE/feature_request.md` — preserved as the durable gate-input contract.
- `.context/sessions/README.md` — retrospective-lessons rotation, now keyed to PR merge/close-out.
- `docs/postmortems/postmortem-001-workflow-bypass.md` — drift evidence.
