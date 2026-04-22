# Task State Directory

> **Purpose**: Track active tasks and their progress. Supports both single-task and parallel-task workflows.

## Cadence (read this first)

These files are the agent working-memory layer; stale or unbounded files defeat the point. Follow the cadence below; the same rules are summarized in `AGENTS.md` §"Ongoing maintenance".

- **`_active.md`** — rewrite (don't append) at every task boundary. Max ~20 lines.
  - Required schema: `Active Task` (one line), `File` (path to `task_*.md` or N/A), `Role` (current owner), `Blockers` (or "None"), `Next 1–3 actions`.
  - Anything beyond that schema belongs in `task_<slug>.md`, not here.
  - Example:
    ```markdown
    **Active Task**: Add login form
    **File**: task_login-frontend.md
    **Role**: frontend
    **Blockers**: waiting on backend API contract (login-backend)
    **Next 1–3 actions**:
    1. Stub LoginForm component with form fields
    2. Wire up form validation
    3. Pause until login-backend lands
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
3. Simple and straightforward

### Multiple Agents / Parallel Work

If multiple agents work simultaneously:
1. Create separate task files: `task_auth.md`, `task_api.md`
2. Each agent claims a task by updating its status to "In Progress"
3. Use `_active.md` to indicate the highest priority task

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
3. If using `_active.md`, update it to point to this task

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
