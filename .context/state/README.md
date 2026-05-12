# Task State Directory (post-ADR-025)

> **Status:** `_active.md`, `coordination.md`, and the (now-deleted) `task_template.md` / `handoff_template.md` are **legacy** under ADR-025 (issue #298). Live coordination state for new work lives in the latest `agent-state:v1` GitHub issue/PR comment, not in this directory. See [`agent_state_comment_template.md`](agent_state_comment_template.md) and [`../rules/process_session_state.md`](../rules/process_session_state.md).

## What lives here now

| File | Status | Purpose |
|---|---|---|
| `agent_state_comment_template.md` | Canonical | Copy/paste template for the live `agent-state:v1` issue/PR comment (ADR-025). |
| `feedback_template.md` | Canonical | Stakeholder feedback capture. |
| `_active.md` | **Legacy / deprecated** | Multi-task working board (ADR-018 schema). Existing in-flight `## Task:` sections may complete under the old rules; do not create new sections for new work after ADR-025 (#298). |
| `coordination.md` | **Legacy / deprecated** | Live claim board (PM-owned). Existing locks may drain under the old rules; do not create new locks for new work after ADR-025 (#298). New work uses GitHub `agent:claimed` / `agent:blocked` / `agent:awaiting-review` labels plus the structured comment. |
| `task_<slug>.md` | **Legacy** | Per-task progress files copied from the (now-deleted) `task_template.md`. The GitHub issue body — particularly the fields in `.github/ISSUE_TEMPLATE/feature_request.md` — supersedes this surface for new work. |

The old `task_template.md` and `handoff_template.md` were deleted by ADR-025. Their replacements are:

- **`task_template.md` → GitHub issue body.** Open an issue using `.github/ISSUE_TEMPLATE/feature_request.md`. The issue's Problem Statement, Proposed Solution, User Outcome, and Acceptance Criteria fields are the durable task contract Analyst / Judge / Critic gates already consume.
- **`handoff_template.md` → `agent_state_comment_template.md`.** Handoffs are a `## Handoff` section in the latest `agent-state:v1` issue/PR comment, not a separate file.

## Where live state actually lives now

```text
GitHub issue body         → durable task contract (gate input)
GitHub PR body            → implementation review contract
Latest `agent-state:v1`   → live coordination + handoff baton
GitHub labels             → coarse workflow filtering only
.context/sessions/**      → durable retrospective lessons (preserved in-tree)
```

The full source-of-truth hierarchy and cadence rules are in [ADR-025](../../docs/decisions/adr-025-github-first-agent-state.md) and [`../rules/process_session_state.md`](../rules/process_session_state.md).

## Cadence (post-ADR-025)

The mid-task durability discipline is preserved; only the write target changes. Update the latest `agent-state:v1` comment at:

- **Task start** — post or refresh.
- **Every wait-for-input pause, no exceptions** — clarification questions, plan-mode approval pauses, review-feedback pauses, "what next?" pauses.
- **Handoff trigger** — ANY of: ~30-turn conversation, runtime auto-summary, session ends before merge, work moves to a different role/agent.
- **Close-out** — `Status: done`. Retrospective lessons land in `../sessions/latest_summary.md` at PR merge / close-out.

See [`../rules/process_session_state.md`](../rules/process_session_state.md) for the canonical rule.

## Legacy: ADR-018 multi-task `_active.md` schema

> Retained verbatim for in-flight branches that started before ADR-025. New work does not add `## Task:` sections.

The historical schema (ADR-018, including Amendment #1) was:

- **`_active.md`** — multi-task file. One `## Task: <branch-name>` section per in-flight branch under the `# Active Tasks` header. Cap: ~20 lines per section.
- **Per-section schema**: `Issue/PR` (`#NNN` or `N/A`), `Role` (current owner), `PR` (`#MMM` once the landing PR exists, `pending` while only the branch exists, or `N/A` for branches with no planned PR — see ADR-018 Amendment #1), `Blockers` (or "None"), `Next 1–3 actions`.
- **Cleanup** — remove your `## Task:` section when the agent is genuinely *leaving the work*. Forgotten removals are caught by PM's reconciliation pass.
- **`coordination.md`** — PM-owned live claim board. Other roles only self-claim; PM does everything else.

If you're closing out a branch that started under this schema, see "Close-out PR discipline (legacy carve-out only)" in [`../rules/process_session_state.md`](../rules/process_session_state.md).

## Migration policy

ADR-025 v1 is forward-looking:

- Existing `_active.md` sections and `coordination.md` locks may be stale; do not block on reconciling them in this transition.
- Stop creating new normal-work entries after ADR-025 lands.
- Existing entries drain naturally under old rules or via a separate `chore(closeout): … legacy state cleanup` PR.

## See also

- [ADR-025](../../docs/decisions/adr-025-github-first-agent-state.md) — the GitHub-first model.
- [`agent_state_comment_template.md`](agent_state_comment_template.md) — the canonical live-coordination comment template.
- [`../rules/process_session_state.md`](../rules/process_session_state.md) — cadence rules.
- [`../sessions/README.md`](../sessions/README.md) — durable retrospective lessons surface.
- [`.github/ISSUE_TEMPLATE/feature_request.md`](../../.github/ISSUE_TEMPLATE/feature_request.md) — the durable issue-body contract.
# Task State Directory

> **Purpose**: Track active tasks and their progress. Supports both single-task and parallel-task workflows.

## Cadence (read this first)

These files are the agent working-memory layer; stale or unbounded files defeat the point. Follow the cadence below; the same rules are summarized in `AGENTS.md` §"Ongoing maintenance".

- **`_active.md`** — multi-task file (ADR-018). One `## Task: <branch-name>` section per in-flight branch under the `# Active Tasks` header. Cap: **~20 lines per section** (no fixed file-level cap; bounded growth comes from disciplined cleanup at close-out).
  - **Claim** — when you start work on a new branch, add a `## Task: <branch-name>` section. Use the branch name (matches `coordination.md` lock template).
  - **Edit** — rewrite **only your own section** at every task boundary. Never edit another branch's section.
  - **Read** — re-read the **whole file** at every task boundary (per AGENTS.md §"Session-state cadence" item 3) so you see all in-flight tasks and can spot conflicts before claiming new work.
  - **Cleanup** — remove your `## Task:` section when the agent is genuinely *leaving the work*: session-end, handoff to a different role, or the PR has fully closed/merged. Mid-loop pauses (waiting for review feedback, awaiting user clarification on a follow-up) do **not** trigger removal — the agent is still active and may need to resume. The `coordination.md` lock release is a separate trigger gated on **PR close/merge** (not agent-done): see `AGENTS.md` §"Session-state cadence" → "Close-out (three actions, three triggers)" for the full split. Forgotten removals are caught by PM's reconciliation pass.
  - **Per-section schema**: `Issue/PR` (`#NNN` or `N/A`), `Role` (current owner), `PR` (`#MMM` once the landing PR exists, `pending` while only the branch exists, or `N/A` for branches with no planned PR — see ADR-018 Amendment #1), `Blockers` (or "None"), `Next 1–3 actions`. Anything beyond that belongs in `task_<slug>.md`, not here.
  - **`PR` field cadence (ADR-018 Amendment #1)**: write `pending` when you first add the section (branch exists, PR not yet opened); update to `#MMM` at your next push *after* PR-open (PR numbers are only assigned by GitHub after creation, so the `pending` → `#MMM` update is necessarily a separate commit from the one that triggered PR creation — typically the first review-feedback fix commit, or an explicit "claim-update" commit if no review is forthcoming); use `N/A` for branches that will not produce a PR (rare — local exploration, abandoned spikes). This mirrors the `**PR**:` field on the matching `coordination.md` lock — the two should agree.
  - **Example** (two parallel branches):
    ```markdown
    # Active Tasks

    ## Task: feature/frontend-101-login-form
    **Issue/PR**: #101
    **Role**: frontend
    **PR**: #145
    **Blockers**: waiting on backend API contract (login-backend)
    **Next 1–3 actions**:
    1. Stub LoginForm component with form fields
    2. Wire up form validation
    3. Pause until login-backend lands

    ## Task: feature/backend-102-login-api
    **Issue/PR**: #102
    **Role**: backend
    **PR**: pending
    **Blockers**: None
    **Next 1–3 actions**:
    1. Define POST /login request/response schema
    2. Implement handler with bcrypt verify
    3. Open PR linking #102
    ```
- **`task_<slug>.md`** — create from `task_template.md` at task start. Update Progress / Files / Blockers as work proceeds. Delete (or move to `../sessions/`) at task end.
- **`handoff_<slug>.md`** — write one before any of:
  - Single conversation has exceeded ~30 turns;
  - Handoff to a different role or agent;
  - End-of-session pause where you expect another agent to pick up.
  Use `handoff_template.md`. Delete after the receiving role has read it and updated `_active.md`.
- **`coordination.md`** — PM-owned. Live claim board. Other roles only self-claim; PM does everything else.

Keep this directory small. If you need a permanent record of "what we decided", that belongs in `docs/decisions/<adr>.md`, not here.

## File Naming Convention

```
state/
├── README.md              # This file
├── task_<id>.md           # Individual task files
│   ├── task_auth.md       # Example: Authentication task
│   ├── task_api.md        # Example: API refactor task
│   └── task_bugfix_123.md # Example: Bug fix for issue #123
└── _active.md             # (Optional) Points to current priority task
```

## Single Task vs Parallel Tasks

### Single Agent / Sequential Work

If only one agent works at a time, you can:
1. Have one task file at a time (e.g., `task_current.md`)
2. Archive completed tasks to `sessions/`
3. `_active.md` still uses the multi-task schema (ADR-018) — your single in-flight branch owns one `## Task:` section under `# Active Tasks`. The schema is the same in both modes; sequential work just means the file usually has one section instead of several.

### Multiple Agents / Parallel Work

If multiple agents work simultaneously:
1. Create separate task files: `task_auth.md`, `task_api.md`
2. Each agent claims a task by adding its `## Task: <branch-name>` section to `_active.md` and updating `coordination.md` per the claim board.
3. `_active.md` shows **all** in-flight tasks (one section per branch) — there is no "highest priority" pointer. Priority sequencing lives in `coordination.md` and `roadmap.md`.

## Task File Template

Create new tasks using this structure:

```markdown
# Task: [Short Title]

**ID**: [Unique identifier, e.g., feature_auth, bugfix_123]  
**Created**: [Date]  
**Status**: [ ] Not Started / [x] In Progress / [ ] Blocked / [ ] Complete  
**Assigned**: [Agent/Developer name, optional]

## Objective

[One sentence: what are we trying to accomplish?]

## Progress

### Completed
- [x] Step that's done
- [x] Another completed step

### In Progress
- [ ] Currently working on this

### Remaining
- [ ] Still need to do this
- [ ] And this

## Files Being Modified

| File | Changes |
|------|---------|
| `src/auth.ts` | Adding login function |

## Blockers

[Any blockers or open questions]

## Verification

\`\`\`bash
# Commands to verify task completion
npm test
\`\`\`

## Context

- Related rules: `.context/rules/domain_auth.md`
- Design reference: `.context/vision/mockups/login.png`
```

## Workflow

### Starting a Task

1. Create `task_<id>.md` using the template above
2. Set status to "In Progress"
3. Add a `## Task: <branch-name>` section to `_active.md` (per ADR-018 multi-task schema)

### During Work

1. Move items from Remaining → In Progress → Completed
2. Update Files Being Modified
3. Note any blockers

### Completing a Task

1. Verify all checklist items complete
2. Run verification commands
3. Set status to "Complete"
4. Optionally archive to `sessions/task_<id>_completed.md`
5. Update `sessions/latest_summary.md` with lessons learned

### Parallel Work Coordination

To prevent conflicts:
1. Check existing task files before creating new ones
2. Don't modify another agent's task file
3. Use clear, unique task IDs
4. Communicate via PR comments if needed

## Archived Tasks

When a task is complete, you can either:
1. Delete the file (history is in git)
2. Move to `sessions/` as `task_<id>_completed.md`
3. Keep in `state/` with "Complete" status (simple but clutters directory)

Recommendation: Delete after capturing lessons in `sessions/latest_summary.md`.
