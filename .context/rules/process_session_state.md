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

- **`.context/state/_active.md`** — multi-task file (ADR-018, including Amendment #1). When you claim a task, add a `## Task: <branch-name>` section under the `# Active Tasks` header. Edit (don't append) **only your own section** at every task boundary; per-section cap is ~20 lines with schema Issue/PR, Role, PR, Blockers, Next 1–3 actions. The `PR` field is required on new sections (write `pending` at section creation, update to `#MMM` at your next push after PR-open, or `N/A` for branches with no planned PR — see ADR-018 Amendment #1); legacy pre-amendment sections may omit it under the backward-compat carve-out and need only adopt at the next task-boundary edit on their own section. Remove your section as part of close-out (see `.context/state/README.md` §"Cadence"). Read the whole file at every task boundary so you see all in-flight work; the write surface is your section only.
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
