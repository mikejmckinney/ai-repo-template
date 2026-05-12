# Session-state cadence

> Extracted from AGENTS.md §"Session-state cadence" + §"Postmortem feedback loop" in PR for #253 (ADR-021).
> Updated by ADR-025 (issue #298): live coordination moved from repo-local `task_*.md` / `handoff_*.md` to the latest `agent-state:v1` issue/PR comment. The mid-task durability cadence is preserved — only the write target changes.
> Read at every task boundary.

Keep agent working memory current so the next session (or next role) can resume cleanly. **Per ADR-025, live coordination state lives in the latest `agent-state:v1` GitHub issue/PR comment, not in repo-local task/handoff markdown.** Durable repo knowledge (rules, ADRs, postmortems, session retrospectives) still lives in-tree. The LLM tool's in-conversation todo list and `/memories/session/` remain agent-private scratch surfaces invisible to any other session, and are never substitutes for the structured comment. If your only record of in-progress work is in scratch surfaces, that work is lost the moment the session ends.

## Re-read requirement

At every task boundary you MUST re-read the following before writing any state or code:

1. `AGENTS.md` — catches mid-session rule edits to the thin contract.
2. `.context/00_INDEX.md` — catches roadmap or constraint changes.
3. **The assigned GitHub issue body** (and the linked PR body if one exists) — the durable feature/task contract per ADR-025.
4. **The latest `agent-state:v1` comment on the issue or PR** — the live coordination baton (since-last-update, blockers, next actions, handoff). Catches what changed between sessions.
5. **GitHub labels on the issue/PR** — coarse workflow filtering (`agent:claimed`, `agent:blocked`, `agent:awaiting-review`).
6. `.context/sessions/latest_summary.md` — durable retrospective lessons from the previous PR's close-out.
7. Any `.context/rules/*.md` or `.context/vision/**/*.md` whose domain covers the files you are about to edit — e.g., read `.context/rules/process_doc_maintenance.md` before changes that may trigger doc-sync requirements; read `.context/rules/domain_code_quality.md` before non-trivial code refactors; read the relevant architecture or mockup in `.context/vision/` before implementing UI or structural changes.

Reading all of `.context/rules/` and `.context/vision/` at every boundary is overkill: unlike `AGENTS.md` (the primary contract file, most likely to be edited mid-session), both rule files and vision artifacts change only through deliberate, reviewed PRs — ad-hoc mid-session edits to them are rare. Item 7 already covers the important case: you read a rule or vision file when its domain intersects what you are about to change. The list above is the minimum set that closes the loop between knowing a rule and following it.

> **Legacy / transitional re-reads.** While drift remains, you may also skim `.context/state/_active.md` and `.context/state/coordination.md` for in-flight work claimed under the pre-ADR-025 model. Treat anything you find there as legacy/advisory, not authoritative — the GitHub issue/PR is the source-of-truth.

## Working-state surfaces (post-ADR-025)

The live coordination surface is the **latest `agent-state:v1` issue/PR comment**. Use the canonical template at [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md). One comment per issue/PR — edit it in place at every cadence trigger; do not append a fresh one per pause.

The structured comment carries:

- `Status` — agent state (`in_progress` / `awaiting_user_input` / `blocked` / `awaiting_review` / `handoff_needed` / `done`); decoupled from PR lifecycle (which lives in GitHub itself).
- `Updated` — ISO-8601 UTC timestamp.
- `Since last update` — what changed since the prior version.
- `Blockers / awaiting` — what's preventing forward motion (or `None`).
- `Next 1–3 actions` — bounded next steps.
- `Handoff` — only filled when pausing, transferring, or leaving work.

The marker line (`<!-- agent-state:v1 issue:NNN pr:MMM branch:... role:... -->`) is parser-friendly; keep it on a single line.

**Cadence triggers** (the comment is updated at each):

- **Task start** — post or refresh the comment.
- **Every wait-for-input pause, no exceptions** — clarification questions mid-task, plan-mode approval pauses, review-feedback pauses, "what next?" pauses. Update `Since last update`, `Status`, and `Next 1–3 actions`. Write now; do not defer until close-out or merge.
- **Handoff trigger** — **required** — update the comment's `Handoff` section before proceeding when ANY of the following fires:
  - A single agent conversation exceeds ~30 turns.
  - You're about to hand off to a different role/agent.
  - **The LLM runtime auto-summarizes your conversation mid-flight.** This is the loudest possible signal that you've blown past the ~30-turn threshold; treat it as an explicit trigger and update the comment *before* responding to the next user message, not after.
  - **The session ends and the task is not yet merged/closed.** Any work that will outlive the current session needs a fresh `Handoff` block — not optional. If the only record of in-progress work is in the LLM's in-conversation todo or `/memories/session/`, that work is lost the moment the session ends.
- **What counts as a "task boundary"** for prompt-driven work: each `.github/prompts/NN-*.md` file is its own boundary. If you process prompts 02 → 03 → 04 in one session, that is *three* boundaries — refresh the `agent-state:v1` comment between each, even if the same agent continues. Treating multiple prompts as one continuous task is a known failure mode (see ADR-012 + `docs/postmortems/postmortem-001-workflow-bypass.md`).

The structured comment is the baton; the next session reads it (plus the issue body, PR body, and labels) instead of replaying the full chat or trusting stale repo-local mirrors.

**Plan-mode routing.** If your runtime locks comment-write access while plan mode is active, capture the comment content in the plan file the agent is already updating. On `ExitPlanMode` approval, your first execution action is to post/refresh the `agent-state:v1` comment. Same discipline, routed through whichever surface is writable.

**Multi-role intra-session handoffs do NOT trigger refresh.** If a single agent transitions roles internally (architect → backend → qa within one conversation), context lives in agent memory; refresh fires on the agent-session boundary (waiting for user input or one of the handoff triggers above), not on intra-session role transitions.

**Failure mode: GitHub API unavailable.** Record the `agent-state:v1` content in a local note (e.g., `/memories/session/agent-state.md`) and copy it into the issue/PR comment as soon as GitHub is reachable. Do not commit live-state files to the repo as a workaround.

## Legacy working-state surfaces (deprecated by ADR-025)

The following surfaces are **deprecated** for new work but kept readable for in-flight legacy branches. Stop creating new entries after ADR-025 lands; existing entries may drain naturally or be cleaned in a separate legacy-cleanup PR.

- **`.context/state/_active.md`** (legacy, ADR-018 schema) — was the multi-task working board. New work uses the latest `agent-state:v1` comment instead. Do not add new `## Task:` sections for normal work.
- **`.context/state/coordination.md`** (legacy) — was the live claim board. New work uses GitHub `agent:claimed` / `agent:blocked` / `agent:awaiting-review` labels plus the structured comment. Do not add new locks for normal work.
- **`.context/state/task_template.md`** (deleted by ADR-025) — superseded by the GitHub issue body (particularly `.github/ISSUE_TEMPLATE/feature_request.md`).
- **`.context/state/handoff_template.md`** (deleted by ADR-025) — superseded by the `## Handoff` section in [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md).

## Close-out (post-ADR-025)

Under the GitHub-first model in ADR-025, normal PR-backed work no longer requires a second close-out PR purely to update repo-local live-state files. Close-out is now two actions on two surfaces, both of which fire automatically or in-session:

- **(1) Live coordination comment — set `Status: done`.** When the agent has fully *left the work* (session-end, role-handoff, or PR fully closed/merged), update the latest `agent-state:v1` issue/PR comment so `Status: done`, fill the `Handoff` section if a successor is expected to pick up, and stop. No follow-up PR is required for this step — it's a comment edit on GitHub.
- **(2) Durable retrospective lessons — append to `latest_summary.md` at PR merge / close-out.** The role that led the work appends one entry to `.context/sessions/latest_summary.md` (canonical template in [`.context/sessions/README.md`](../sessions/README.md)) with `What Shipped`, `Harder Than Expected`, and `Generalizable Lessons`. Rotation now keys to PR merge / close-out (the landed PR is the stable provenance boundary), not to "new agent starts a fresh task." Abandoned/no-PR work archives only when there are durable lessons worth preserving.

The agent's `Status` in the `agent-state:v1` comment is decoupled from the PR's lifecycle. The PR being open / merged / closed lives in GitHub itself; you don't have to mirror it anywhere.

> **Legacy carve-out (in-flight branches that started under the old model).** Branches with existing `## Task:` sections in `.context/state/_active.md` and locks in `.context/state/coordination.md` may still complete the trigger-2 / trigger-3 close-out from the pre-ADR-025 rule (`Status: merged` lock release, `## Task:` removal). Do this in a `chore(closeout): PR #NNN merged — legacy state cleanup` follow-up PR, labeled `chore:no-plan`. Do NOT direct-commit to `main`. New work started after ADR-025 lands does not create new entries in those files and therefore does not need this follow-up PR.

## Close-out PR discipline (legacy carve-out only)

> **Status:** Legacy. Applies only to branches that started under the pre-ADR-025 model and still carry `_active.md` `## Task:` sections or `coordination.md` locks. New work after ADR-025 (#298) does not require a `chore(closeout)` follow-up PR for normal coordination — see "Close-out (post-ADR-025)" above.

For in-flight legacy branches, the old trigger-2 (`_active.md` task removal) and trigger-3 (`coordination.md` lock release) still fire **after** the PR they reference has merged. There are three options at that moment, and only one is acceptable:

1. **Direct commit to `main` ❌** — Violates the branch-first rule in [`process_work_style.md`](process_work_style.md). Not allowed, even for "it's just one line." This produced the postmortem incident on commit `f63f728` after PR #261 merged.
2. **Skip the close-out ❌** — Leaves stale `Active Locks` and `## Task:` entries that mislead the next session about what's in flight. Not allowed for legacy locks already in those files.
3. **Open a dedicated close-out PR ✅** — A small `chore(closeout): PR #NNN merged — legacy state cleanup` follow-up PR carrying only the legacy trigger-2 + trigger-3 edits.

**Rule (legacy only).** Legacy lock release (and any orphaned `## Task:` cleanup that survived past PR merge) goes through a `chore(closeout): PR #NNN — legacy state cleanup` follow-up PR. Branch from current `main`, make the minimal edits, push, open PR, merge. Do not bundle with unrelated work.

**Title and labels.** Title format: `chore(closeout): PR #NNN merged — legacy state cleanup`. Labels: `chore:no-plan` (exempts from the plan-as-comment requirement in [`process_gates.md`](process_gates.md)). Note: `chore:*` PRs are already exempt from the Analyst pre-flight gate per `process_gates.md` Exemptions, so no separate `outcome-validated` label is needed for that gate. PR body links to the just-merged PR.

**`make closeout` (transitional).** `make closeout` from #262 continues to validate the legacy trigger-1/2/3 invariants for branches that still carry `_active.md` / `coordination.md` entries. Treat it as a fallback for the migration period, not as the normal future path for new work.

**#263 superseded.** Issue #263 (opt-in `auto-coordinate` workflow that wrote close-out facts back into repo-local files) is **superseded by ADR-025**. The mechanical justification for #263 — that PR numbers and merge state are only knowable post-merge and the branch-first rule blocks direct edits — is dissolved by the GitHub-first model: those facts already live in GitHub and don't need a second PR to mirror them in tracked markdown.

## Postmortem feedback loop

When a downstream project (a repo built *from* this template) hits an incident worth a postmortem, run `.github/prompts/capture-postmortem.md` in that project repo. If the resulting postmortem's `generalizes:` is `Yes` or `Unclear`, run `.github/prompts/mirror-postmortem.md` against this template to mirror it back with a same-PR follow-up. The three-tier promotion policy (universal → AGENTS.md / `.context/rules/` / new ADR; stack-specific → mirrored postmortem only, never AGENTS.md; project-only → stays in source repo) is defined in `docs/postmortems/README.md` and ratified in [ADR-015](../../docs/decisions/adr-015-postmortem-feedback-loop.md). Do NOT add per-stack guidance (Terraform, Python, Rust, etc.) to this file — that is the failure mode the policy exists to prevent.
