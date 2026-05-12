# Task State Directory

> **Purpose**: Hold the templates and legacy-compatibility files that back agent live coordination.
>
> **As of [ADR-025](../../docs/decisions/adr-025-github-first-agent-state.md)**, normal live coordination state for new work lives on **GitHub** \u2014 the assigned issue, the linked PR, the latest `agent-state:v1` issue/PR comment, and a small set of coarse labels. The files in this directory are the canonical comment template plus legacy-compatibility views for branches that pre-date ADR-025 and the documented GitHub-API-unavailable fallback. They are **not** the primary live-state surface for new work.

## Files in this directory

- **`agent_state_comment_template.md`** \u2014 canonical template body for the `agent-state:v1` GitHub issue/PR comment. Copy into the assigned issue or PR; keep one latest comment current per work item. This is the primary live-state surface under ADR-025.
- **`_active.md`** \u2014 legacy multi-task file (ADR-018). Preserved as a compatibility view for branches that pre-date ADR-025; existing entries may be stale because GitHub owns the authoritative lifecycle events. Do **not** add new `## Task: <branch>` sections for new normal work after ADR-025.
- **`coordination.md`** \u2014 legacy lock board. Same status as `_active.md`: preserved for compatibility and as the documented GitHub-API-unavailable fallback. Do **not** add new locks for new work.
- **`README.md`** \u2014 this file.

The previously-shipped `task_template.md` and `handoff_template.md` were removed by ADR-025: GitHub issue bodies are the durable task contract, and the `Handoff` section of the `agent-state:v1` comment is the cognitive baton.

## Cadence (read this first)

The `agent-state:v1` comment cadence \u2014 task start, every wait-for-input pause, durability-risk boundaries (~30 turns / runtime auto-summary / session-end mid-task), role/agent handoff, and closeout \u2014 is defined in [`process_session_state.md`](../rules/process_session_state.md). Read that file at every task boundary.

For legacy branches still using `_active.md` and `coordination.md`:

- **`_active.md`** — the multi-task schema from [ADR-018](../../docs/decisions/adr-018-multi-task-active-md-schema.md) (including Amendment #1) remains valid. Each in-flight legacy branch owns one `## Task: <branch-name>` section. Per-section schema: `Issue/PR | Role | PR | Blockers | Next 1–3 actions`. Cap ~20 lines per section. Add a section when you claim work on a legacy branch; rewrite **only your own section** at every task boundary; re-read the **whole file** so you see all in-flight legacy work; remove your section at genuine close-out (session-end, role handoff, or PR fully closed/merged).
- **`coordination.md`** \u2014 self-claim by appending a lock block; PM is the only role that may edit or remove others' locks. Move your block to Recent History when the legacy task is done or handed off.

PM is the backstop for both files: it catches forgotten cleanup via the daily reconciliation pass at `.github/workflows/agent-coordination-sync.yml` and is the only role that may edit another agent's section, prune Recent History, or arbitrate cross-role conflicts.

## File Naming Convention

```
state/
\u251c\u2500\u2500 README.md                           # This file
\u251c\u2500\u2500 agent_state_comment_template.md     # ADR-025 canonical comment template
\u251c\u2500\u2500 _active.md                          # Legacy multi-task file (ADR-018)
\u2514\u2500\u2500 coordination.md                     # Legacy lock board
```

Permanent design records belong in `docs/decisions/<adr>.md`. Durable retrospective lessons belong in `.context/sessions/`. Postmortems belong in `docs/postmortems/`.

## Workflow (GitHub-first, normal work)

1. **Start**: post the `agent_state_comment_template.md` body as a comment on the assigned issue (or the linked PR if one exists). Set `Status: in_progress`, fill `Next 1\u20133 actions`, apply the `agent:claimed` label.
2. **During work**: update the same comment at every wait-for-input pause and durability-risk boundary (see `process_session_state.md`). Refresh `Since last update`, `Blockers / awaiting`, `Next 1\u20133 actions`, and \u2014 when handing off or pausing past durability boundaries \u2014 the `Handoff` section.
3. **Closeout**: set `Status: done` when the agent fully leaves the work. Rotate durable retrospective lessons into `.context/sessions/latest_summary.md` per `.context/sessions/README.md`. The PR may still be open awaiting human merge \u2014 that's a GitHub-owned state, not the agent's.

## Workflow (legacy branches)

1. Add a `## Task: <branch>` section to `_active.md` and a lock block to `coordination.md` Active Locks at task start.
2. Update only your own section / lock as work proceeds.
3. Remove your `## Task:` section at genuine close-out; move your lock to Recent History at PR close/merge. Use the legacy `chore(closeout): PR #NNN` follow-up PR pattern (see [`process_session_state.md`](../rules/process_session_state.md) \u00a7 \"Legacy close-out PR discipline\") if these edits need to land on `main` after the feature PR has merged.
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
