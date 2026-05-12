# Session-state cadence

> Originally extracted from AGENTS.md §"Session-state cadence" + §"Postmortem feedback loop" in PR for #253 (ADR-021).
> Cadence rewritten in PR for #298 to route normal live coordination to GitHub issues, PRs, labels, and `agent-state:v1` comments per [ADR-025](../../docs/decisions/adr-025-github-first-agent-state.md).
> Read at every task boundary.

Keep agent working memory current so the next session (or next role) can resume cleanly. For normal GitHub-connected work, **live coordination state lives in GitHub** — the assigned issue, the linked PR, the latest `agent-state:v1` comment, and a small set of coarse labels. The LLM tool's in-conversation todo list and `/memories/session/` are agent-private scratch surfaces invisible to any other session, and they are never the sole continuity record. If your only record of in-progress work is in scratch surfaces, that work is lost the moment the session ends.

The repo-local files `.context/state/_active.md` and `.context/state/coordination.md` (and the legacy `task_*.md` / `handoff_*.md` files they referenced) are preserved as compatibility views per ADR-025. They are no longer the primary live-state source for new normal-work branches; they remain the documented fallback for old branches still using the file-based model and for offline work.

## Re-read requirement

At every task boundary you MUST re-read or re-check the following before writing any state or code:

1. `AGENTS.md` — catches mid-session rule edits to the thin contract.
2. `.context/00_INDEX.md` — catches roadmap or constraint changes.
3. **The assigned GitHub issue body** — durable feature/task contract and Analyst/Judge/Critic gate input. The issue body is stable; live progress does not belong in it.
4. **The linked PR body, if a PR exists** — implementation/review/verification contract.
5. **The latest `agent-state:v1` issue/PR comment and current labels** — live coordination state. Use [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md) when posting or updating.
6. Any `.context/rules/*.md` or `.context/vision/**/*.md` whose domain covers the files you are about to edit — e.g., read `.context/rules/process_doc_maintenance.md` before changes that may trigger doc-sync requirements; read `.context/rules/domain_code_quality.md` before non-trivial code refactors; read the relevant architecture or mockup in `.context/vision/` before implementing UI or structural changes.

If you are picking up a legacy branch that pre-dates ADR-025, also read `.context/state/_active.md` and `.context/state/coordination.md` to recover the compatibility-view state.

Reading all of `.context/rules/` and `.context/vision/` at every boundary is overkill: unlike `AGENTS.md` (the primary contract file, most likely to be edited mid-session), both rule files and vision artifacts change only through deliberate, reviewed PRs — ad-hoc mid-session edits to them are rare. Point 6 already covers the important case: read a rule or vision file when its domain intersects what you are about to change. The six items above are the minimum set that closes the loop between knowing a rule and following it.

## Live-state surfaces

- **GitHub issue body** — durable task contract. Do not rewrite it for live progress updates.
- **GitHub PR body** — implementation, review, plan links, and verification contract. Link the issue, every plan comment, the verification block, and (when relevant) the latest `agent-state:v1` comment.
- **Latest `agent-state:v1` issue/PR comment** — the mutable baton for current status, blockers, next 1–3 actions, and handoff. Template lives at [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md). Keep it slim: long decision history, full file lists, verification matrices, and durable retrospective lessons stay out of the comment.
- **Coarse labels (v1)** — `agent:claimed`, `agent:blocked`, `agent:awaiting-review`. The `Status:` field in the structured comment carries finer-grained state; promote new labels only when a workflow or filter actually needs them.
- **Repo-local legacy compatibility files** — `.context/state/_active.md`, `.context/state/coordination.md`, plus any pre-ADR-025 `task_*.md` or `handoff_*.md` files. Existing entries may be stale because GitHub owns the authoritative lifecycle events. Do not create new normal-work `## Task:` sections, lock blocks, `task_*.md` files, or `handoff_*.md` files after ADR-025; old branches in flight may continue using the old close-out PR discipline below until they merge.

If GitHub API access is unavailable, temporarily record the same `agent-state:v1` content in a local scratch note. Copy it into the issue/PR comment once access returns. Do not commit local live-state scratch files as the normal path.

## `agent-state:v1` update cadence (every wait-for-input pause, no exceptions)

The mid-task durability discipline that previously routed to `latest_summary.md` and `_active.md` now routes to the latest `agent-state:v1` comment. Update or post the comment at each of these boundaries:

1. **Task start.** Post the comment with `Status: in_progress`, the branch, your role, and the initial Next 1–3 actions. Apply `agent:claimed`.
2. **Every wait-for-input pause, no exceptions.** Includes mid-task clarification questions, plan-mode approval pauses, review-feedback waits, and "task done, what's next?" pauses. Refresh `Since last update`, `Blockers / awaiting`, and `Next 1–3 actions` *before* waiting. Write now; do not defer until closeout or merge.
   - **Plan-mode routing.** While plan mode is active, capture working-state content in the plan file the agent is already updating. On `ExitPlanMode` approval, the agent's first execution action is to post or update the `agent-state:v1` comment.
   - **Multi-role intra-session handoffs do NOT trigger an immediate refresh.** If a single agent transitions roles internally (architect → backend → qa within one conversation), context lives in agent memory; refresh fires on the agent-session boundary (waiting for user input), not on intra-session role transitions.
3. **Durability-risk boundaries.** Refresh the `Handoff` section before responding to the next message when ANY of the following fires:
   - The conversation exceeds ~30 turns.
   - The runtime auto-summarizes the conversation mid-flight (the loudest possible signal that you've blown past the threshold).
   - The session ends with the task not yet merged/closed. Any work that will outlive the current session requires a `Handoff` update — not optional.
4. **Role/agent handoff.** Same as 3, with `Handoff: To:` set to the receiving role/session and one or two sentences naming the next action.
5. **Closeout.** Set `Status: done` when the agent has fully left the work: session-end with no further intent to resume, handoff to a different role, or the PR has fully closed/merged. Mid-loop pauses (waiting for review feedback, awaiting user clarification on a follow-up question) do **NOT** flip status to `done` — the agent is still active and may need to resume.

The `Status:` field tracks the **agent's** state, not the PR state. `done` means the agent has nothing further queued and is leaving the work; the PR may still be open awaiting human merge. PR state is owned by GitHub.

## Durable session lessons

`.context/sessions/latest_summary.md` and date-stamped archives are the canonical durable retrospective layer, not a live coordination baton. Use them for `What Shipped`, `Harder Than Expected`, and `Generalizable Lessons`.

For normal PR-backed work, rotate/archive `latest_summary.md` at PR merge or closeout, using the landed PR as the provenance boundary. For abandoned or no-PR work, archive only when there are durable lessons worth preserving. The full template and rotation forms live in [`.context/sessions/README.md`](../sessions/README.md). Long-term archive retention and pruning policy is intentionally out of scope here and tracked in #299.

`docs/postmortems/**` remain the durable surface for formal incident/failure analysis. ADRs remain durable design decisions. `.context/rules/**` remain enforceable operating policy.

## Multi-task `_active.md` schema (legacy compatibility)

For branches that pre-date ADR-025 and still use the file-based model, the multi-section schema from [ADR-018](../../docs/decisions/adr-018-multi-task-active-md-schema.md) (including Amendment #1) remains valid. Each in-flight branch owns one `## Task: <branch>` section under `# Active Tasks`, capped at ~20 lines, with schema `Issue/PR | Role | PR | Blockers | Next 1–3 actions`. Read the whole file when working on a legacy branch so you see all in-flight work; only edit your own section. Do not create new `## Task:` sections for new GitHub-connected work after ADR-025 — record live state in the latest `agent-state:v1` comment instead.

## Legacy close-out PR discipline (transitional fallback)

For branches that pre-date ADR-025 and still carry `_active.md` `## Task:` sections or `coordination.md` Active Locks, the post-merge close-out problem still applies: the entries need to land on `main`, but the agent is no longer on the just-merged feature branch. Three options remain at that moment, and only one is acceptable:

1. **Direct commit to `main` ❌** — Violates the branch-first rule in [`process_work_style.md`](process_work_style.md). Not allowed, even for "it's just one line." This produced the postmortem incident on commit `f63f728` after PR #261 merged.
2. **Skip the close-out ❌** — Leaves stale `Active Locks` and `## Task:` entries that mislead the next session about what's in flight on legacy branches. Not allowed.
3. **Open a dedicated close-out PR ✅** — A small `chore(closeout): PR #NNN merged` follow-up PR carrying only the legacy live-state cleanup edits. This is the documented fallback for legacy branches.

**Title and labels.** Title format: `chore(closeout): PR #NNN merged — trigger-3 lock release`. Labels: `chore:no-plan` (exempts from the plan-as-comment requirement in [`process_gates.md`](process_gates.md)). `chore:*` PRs are already exempt from the Analyst pre-flight gate per `process_gates.md` Exemptions, so no separate `outcome-validated` label is needed for that gate. PR body links to the just-merged PR.

After ADR-025, **new normal work does not need this PR.** Live state lives in the `agent-state:v1` comment, which doesn't require a tracked-file edit at merge. The legacy close-out PR is only required when an old `_active.md` section or `coordination.md` lock has to be cleaned up after its PR merges. `make closeout` (#262) and `scripts/closeout.sh` remain transitional/fallback validators for that path.

#263's repo-local write-back automation is superseded by ADR-025 as the preferred design. Any remaining #263 work should be narrowed to temporary compatibility or generated views from GitHub state.

## Postmortem feedback loop

When a downstream project (a repo built *from* this template) hits an incident worth a postmortem, run `.github/prompts/capture-postmortem.md` in that project repo. If the resulting postmortem's `generalizes:` is `Yes` or `Unclear`, run `.github/prompts/mirror-postmortem.md` against this template to mirror it back with a same-PR follow-up. The three-tier promotion policy (universal → AGENTS.md / `.context/rules/` / new ADR; stack-specific → mirrored postmortem only, never AGENTS.md; project-only → stays in source repo) is defined in `docs/postmortems/README.md` and ratified in [ADR-015](../../docs/decisions/adr-015-postmortem-feedback-loop.md). Do NOT add per-stack guidance (Terraform, Python, Rust, etc.) to this file — that is the failure mode the policy exists to prevent.
# Session-state cadence

> Extracted from AGENTS.md §"Session-state cadence" + §"Postmortem feedback loop" in PR for #253 (ADR-021).
> Includes one new rule authored fresh: §"Close-out PR discipline (interim, until #263)" — see ADR-021 for rationale.
> Read at every task boundary.

Keep agent working memory current so the next session (or next role) can resume cleanly. **Working state must live in `.context/state/`** — the LLM tool's in-conversation todo list and `/memories/session/` are agent-private scratch surfaces invisible to any other session, and are never substitutes for the checked-in files below. If your only record of in-progress work is in scratch surfaces, that work is lost the moment the session ends.

## Re-read requirement

At every task boundary you MUST re-read the following files before writing any state or code:

1. `AGENTS.md` — catches mid-session rule edits to the thin contract.
2. `.context/00_INDEX.md` — catches roadmap or constraint changes.
3. `.context/state/_active.md` and the active `.context/state/task_<slug>.md` (if any) — catches staleness in your own working state. `_active.md` uses a multi-section schema (one `## Task: <branch>` section per in-flight branch; see ADR-018, including Amendment #1); each section is capped at ~20 lines of task metadata (Issue/PR, Role, PR, Blockers, Next 1–3 actions — `PR` is required on new sections per ADR-018 Amendment #1; pre-amendment sections may omit it under the backward-compat carve-out). Read the whole file (you need to see every active task to spot conflicts before claiming new work), but only edit your own section. Granular progress, files, and detailed blockers live in the task file each section references.
4. `.context/state/coordination.md` — catches stale locks before you add new ones.
5. Any `.context/rules/*.md` or `.context/vision/**/*.md` whose domain covers the files you are about to edit — e.g., read `.context/rules/process_doc_maintenance.md` before changes that may trigger doc-sync requirements; read `.context/rules/domain_code_quality.md` before non-trivial code refactors; read the relevant architecture or mockup in `.context/vision/` before implementing UI or structural changes.

Reading all of `.context/rules/` and `.context/vision/` at every boundary is overkill: unlike `AGENTS.md` (the primary contract file, most likely to be edited mid-session), both rule files and vision artifacts change only through deliberate, reviewed PRs — ad-hoc mid-session edits to them are rare. Point 5 already covers the important case: you read a rule or vision file when its domain intersects what you are about to change. The five items above are the minimum set that closes the loop between knowing a rule and following it.

## Working-state files

- **`.context/state/_active.md`** — multi-task file (ADR-018, including Amendment #1). When you claim a task, add a `## Task: <branch-name>` section under the `# Active Tasks` header. Edit (don't append) **only your own section** at every task boundary; per-section cap is ~20 lines with schema `Issue/PR | Role | PR | Blockers | Next 1–3 actions` (matching the canonical pipe-delimited schema in `_active.md` itself). The `PR` field is required on new sections (write `pending` at section creation, update to `#MMM` at your next push after PR-open, or `N/A` for branches with no planned PR — see ADR-018 Amendment #1); legacy pre-amendment sections may omit it under the backward-compat carve-out and need only adopt at the next task-boundary edit on their own section. Remove your section as part of close-out (see `.context/state/README.md` §"Cadence"). Read the whole file at every task boundary so you see all in-flight work; the write surface is your section only.
  - **What counts as a "task boundary"** for prompt-driven work: each `.github/prompts/NN-*.md` file is its own boundary. If you process prompts 02 → 03 → 04 in one session, that is *three* boundaries — rewrite your `## Task:` section between each, even if the same agent continues. Treating multiple prompts as one continuous task is a known failure mode (see ADR-012 + `docs/postmortems/postmortem-001-workflow-bypass.md`).
- **`.context/state/task_<slug>.md`** — create from [`.context/state/task_template.md`](../state/task_template.md) at task start. Delete (or move to `.context/sessions/`) at task end.
- **Handoff trigger** — **required** — write a structured handoff to `.context/state/handoff_<slug>.md` (template: [`.context/state/handoff_template.md`](../state/handoff_template.md)) and start a fresh session whenever ANY of the following fires:
  - A single agent conversation exceeds ~30 turns.
  - You're about to hand off to a different role/agent.
  - **The LLM runtime auto-summarizes your conversation mid-flight.** This is the loudest possible signal that you've blown past the ~30-turn threshold; treat it as an explicit trigger and write the handoff *before* responding to the next user message, not after.
  - **The session ends and the task is not yet merged/closed.** Any work that will outlive the current session requires a handoff — not optional. If the only record of in-progress work is in the LLM's in-conversation todo or `/memories/session/`, that work is lost the moment the session ends.

  The handoff is the baton; the next session reads it instead of replaying the full chat.

## Close-out (three actions, three triggers)

Earlier versions of this rule treated close-out as one event, conflating three different actions under one trigger. That conflation produced two recurring bugs: (a) lock `**State**:` set to `merged` before the PR was actually merged (postmortem-001 #4 + Codex P1 finding on PR #261), and (b) "I'll write the summary later" deferral that orphaned working state. Each action below has its own trigger and they fire independently:

- **(1) Working-log refresh — every wait-for-input pause.** The role that led the work updates `.context/sessions/latest_summary.md` per the canonical template in [`.context/sessions/README.md`](../sessions/README.md) whenever the agent is about to wait for user input: clarification questions mid-task, plan-mode approval pauses, "task done, what's next?" pauses. There are no exceptions; mid-task clarification pauses are explicitly included. One entry per agent-session: append to your in-progress entry on each pause; do NOT open a fresh entry per pause. Do NOT defer until merge — write now even if the PR isn't merged, amend later if outcomes change. The entry's `Status` field reflects the **agent's** state (decoupled from PR state): `in_progress` while actively working, `awaiting_user_input` while paused for clarification, `done` only when the agent has fully left the work (see trigger 2).
  - **Plan-mode routing.** `latest_summary.md` is not writable while plan mode is active; capture working-log content in the plan file the agent is already updating. On `ExitPlanMode` approval, the agent's first execution action copies plan-mode content into `latest_summary.md`. Same discipline, routed through whichever surface is writable.
  - **Multi-role intra-session handoffs do NOT trigger refresh.** If a single agent transitions roles internally (architect → backend → qa within one conversation), context lives in agent memory; refresh fires on the agent-session boundary (waiting for user input), not on intra-session role transitions.
- **(2) `_active.md` `## Task:` removal — when the agent leaves the work.** Remove your `## Task: <branch>` section from `.context/state/_active.md` when the agent is genuinely *leaving the work*: session-end, handoff to a different role, or the PR has fully closed/merged. Mid-loop pauses (waiting for review feedback, awaiting user clarification on a follow-up question) do **NOT** trigger removal — the agent is still active and may need to resume. PM's `coordination.md` reconciliation pass catches forgotten removals.
- **(3) `coordination.md` lock release — on PR close/merge.** Move your lock from Active Locks to Recent History (with `**Result**:` line; `**State**:` set to `merged` if the branch was merged or `closed_unmerged` if closed without merge) **when the PR actually closes or merges**, not at agent-done. While the PR is open, the lock's `State` reflects branch progress (`in_progress`, `peer_review`, `judge_review`, `approved`) — never `merged`. The `.github/workflows/agent-coordination-sync.yml` on-close webhook posts a suggestion when the PR closes; the next agent session (or PM) acts on the suggestion. Setting `State: merged` on a lock whose PR is still open is a correctness bug — coordination checks (daily reconciliation, parallelism-report parser) read `State` semantically, and the lock's location (Active vs Recent) plus its `State` together describe the branch's actual status.
- **PM gate.** PM verifies the close-out entry exists in `latest_summary.md` with `Status: done` before marking the task done in `coordination.md`. The PM gate is on the *agent's* `Status` field, not on lock `State` — the two are independent triggers.

## Close-out PR discipline (interim, until #263)

The close-out actions in trigger 2 (`_active.md` task removal) and trigger 3 (`coordination.md` lock release) typically fire **after** the PR they reference has merged. That timing creates a discipline gap: the changes need to land on `main`, but the agent is no longer on the just-merged feature branch. There are three options at that moment, and only one is acceptable:

1. **Direct commit to `main` ❌** — Violates the branch-first rule in [`process_work_style.md`](process_work_style.md). Not allowed, even for "it's just one line." This produced the postmortem incident on commit `f63f728` after PR #261 merged.
2. **Skip the close-out ❌** — Leaves stale `Active Locks` and `## Task:` entries that mislead the next session about what's in flight. Not allowed.
3. **Open a dedicated close-out PR ✅** — A small `chore(closeout): PR #NNN merged` follow-up PR carrying only the trigger-2 + trigger-3 edits. This is the documented path until #263 ships automation.

**Rule.** Trigger-3 lock release (and any orphaned trigger-2 cleanup that survived past PR merge) goes through a `chore(closeout): PR #NNN` follow-up PR. Branch from current `main`, make the minimal edits, push, open PR, merge. Do not bundle close-out edits with unrelated work; the follow-up PR exists precisely so the close-out diff is reviewable on its own and the close-out itself can be closed-out cleanly.

**Title and labels.** Title format: `chore(closeout): PR #NNN merged — trigger-3 lock release`. Labels: `chore:no-plan` (exempts from the plan-as-comment requirement in [`process_gates.md`](process_gates.md)). Note: `chore:*` PRs are already exempt from the Analyst pre-flight gate per `process_gates.md` Exemptions, so no separate `outcome-validated` label is needed for that gate. PR body links to the just-merged PR.

**Eat your own dogfood.** When you merge the PR for #253, this rule applies to *its* close-out: open a follow-up `chore(closeout)` PR for the lock release. Do not direct-to-main, even though the alternative is one commit.

**Eventual automation.** Issue #263 tracks upgrading `agent-coordination-sync.yml` from comment-only to write-mode under an opt-in `auto-coordinate` label. Once that ships, the close-out PR becomes optional (the workflow generates it automatically when the label is set). Until then, the manual follow-up PR is required.

## Postmortem feedback loop

When a downstream project (a repo built *from* this template) hits an incident worth a postmortem, run `.github/prompts/capture-postmortem.md` in that project repo. If the resulting postmortem's `generalizes:` is `Yes` or `Unclear`, run `.github/prompts/mirror-postmortem.md` against this template to mirror it back with a same-PR follow-up. The three-tier promotion policy (universal → AGENTS.md / `.context/rules/` / new ADR; stack-specific → mirrored postmortem only, never AGENTS.md; project-only → stays in source repo) is defined in `docs/postmortems/README.md` and ratified in [ADR-015](../../docs/decisions/adr-015-postmortem-feedback-loop.md). Do NOT add per-stack guidance (Terraform, Python, Rust, etc.) to this file — that is the failure mode the policy exists to prevent.
