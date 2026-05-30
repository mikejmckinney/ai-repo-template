# Session-state cadence

> Extracted from AGENTS.md §"Session-state cadence" + §"Postmortem feedback loop" in PR for #253 (ADR-021), then superseded in part by ADR-025.
> Read at every task boundary.

Keep agent working memory current so the next session (or next role) can resume cleanly. For normal GitHub-connected work, **live coordination state lives in GitHub**, not in manually maintained repo-local markdown. The LLM tool's in-conversation todo list and `/memories/session/` are agent-private scratch surfaces; they are never the sole continuity record.

## Re-read requirement

At every task boundary you MUST re-read or re-check the following before writing state or code:

1. `AGENTS.md` — catches mid-session rule edits to the thin contract.
2. `.context/00_INDEX.md` — catches roadmap or constraint changes.
3. The assigned GitHub issue body — durable feature/task contract and gate input.
4. The linked PR body, if one exists — implementation, plan, and verification contract.
5. The latest `agent-state:v1` issue/PR comment and current labels — live coordination state (`agent:claimed`, `agent:blocked`, `agent:awaiting-review`).
6. Any `.context/rules/*.md` or `.context/vision/**/*.md` whose domain covers the files you are about to edit — e.g., read `.context/rules/process_doc_maintenance.md` before changes that may trigger doc-sync requirements; read `.context/rules/domain_code_quality.md` before non-trivial code refactors; read the relevant architecture or mockup in `.context/vision/` before implementing UI or structural changes.

Reading all of `.context/rules/` and `.context/vision/` at every boundary is overkill: unlike `AGENTS.md`, both rule files and vision artifacts change only through deliberate, reviewed PRs. Point 6 covers the important case: read a rule or vision file when its domain intersects what you are about to change.

## Live coordination surface

- **Issue body** — stable task contract. Do not rewrite it for live progress updates.
- **PR body** — implementation/review contract. Link the issue, plan comment(s), verification results, and latest live-state comment when relevant.
- **Latest `agent-state:v1` comment** — mutable baton for current status, blockers, next actions, and handoff. Use [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md) as the copy/paste template.
- **Labels** — coarse workflow filters only: `agent:claimed`, `agent:blocked`, `agent:awaiting-review`.
- **Local scratch copies** — if GitHub access is temporarily unavailable, keep any local baton copy uncommitted and ephemeral. Do not create repo-local claim boards, task files, or handoff files as a parallel normal-work path.

If GitHub API access is unavailable, temporarily record the same `agent-state:v1` content locally. Copy it into the issue/PR comment once access returns, then discard the local scratch copy. Do not commit local live-state scratch files as the normal path or reconcile a second persistent state surface.

## `agent-state:v1` update cadence

Update or post the latest `agent-state:v1` issue/PR comment at each of these boundaries:

1. **Task start.** Record branch/role, current status, blockers, and next actions.
2. **Every wait-for-input pause, no exceptions.** This includes clarification questions mid-task, plan approval pauses, review-feedback pauses, and "task done, what's next?" pauses. Write now; do not defer until closeout or merge.
3. **Durability-risk boundaries.** If a single conversation exceeds ~30 turns, the runtime auto-summarizes mid-flight, or the session ends while the task is not merged/closed, refresh the `Handoff` section before responding to the next message. Use runtime-provided turn counters or auto-summary notices when available; otherwise self-count approximately and treat any injected conversation summary as an auto-summary boundary.
4. **Role/agent handoff.** Set `Handoff` → `To:` to the receiving role/session and summarize the next action in one or two sentences.
5. **Closeout.** Set `Status: done` when the agent has fully left the work.

The comment is intentionally slim. Keep long decision history in plan comments, PR bodies, ADRs, or session lessons. Keep file lists in the diff/PR body. Keep verification matrices in the PR body and CI. Keep retrospective lessons in `.context/sessions/latest_summary.md` and archives.

## Durable session lessons

`.context/sessions/latest_summary.md` and date-stamped archives are the durable retrospective layer, not the live coordination baton. Use them for `What Shipped`, `Harder Than Expected`, and `Generalizable Lessons`.

For normal PR-backed work, rotate/archive `latest_summary.md` at PR merge or closeout, using the landed PR as the provenance boundary. For abandoned or no-PR work, archive only when there are durable lessons worth preserving. Retention and pruning are out of scope here and tracked in #299.

`docs/postmortems/**` remain the durable surface for formal incident/failure analysis. ADRs remain durable design decisions. `.context/rules/**` remain enforceable operating policy.

## Postmortem feedback loop

When a downstream project (a repo built *from* this template) hits an incident worth a postmortem, run `.github/prompts/capture-postmortem.md` in that project repo. If the resulting postmortem's `generalizes:` is `Yes` or `Unclear`, run `.github/prompts/mirror-postmortem.md` against this template to mirror it back with a same-PR follow-up. The three-tier promotion policy (universal → AGENTS.md / `.context/rules/` / new ADR; stack-specific → mirrored postmortem only, never AGENTS.md; project-only → stays in source repo) is defined in `docs/postmortems/README.md` and ratified in [ADR-015](../../docs/decisions/adr-015-postmortem-feedback-loop.md). Do NOT add per-stack guidance (Terraform, Python, Rust, etc.) to this file — that is the failure mode the policy exists to prevent.
