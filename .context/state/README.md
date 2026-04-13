# Task State Directory

> **Purpose**: Track active tasks and their progress. Supports both single-task and parallel-task workflows.

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

### Multi-Agent Orchestration Patterns

For structured multi-agent work, see the full guides:
- **Rules**: `.context/rules/domain_multi_agent.md` (file ownership, coordination rules)
- **Orchestration**: `.context/rules/domain_orchestration.md` (routing, quality gates)
- **Role definitions**: `.context/vision/architecture/agent-roles.md`
- **Setup runbook**: `.github/prompts/parallel-agents.md`
- **Orchestration runbook**: `.github/prompts/multi-agent-orchestration.md`

#### Quick Reference: Orchestration Patterns

| Pattern | When to Use | Agents |
|---------|------------|--------|
| **Solo** | Trivial tasks (bug fix, config, docs) | 1 |
| **Pair** | Moderate tasks with quality needs | 2 (implementer + reviewer) |
| **Hub-and-Spoke** | Complex multi-component work | 3-5 (coordinator + specialists + reviewer) |
| **Pipeline** | Sequential work (design → build → test) | 3-4 (one per phase) |
| **Adversarial** | Critical/security changes | 2+ (implementer + adversary) |

#### Key Principles

1. **File ownership**: Each task file declares `Owned Files/Dirs` — only that agent may modify those files
2. **Interface-first**: Define shared contracts before parallel implementation begins
3. **Adversarial review**: For 3+ agents, at least one should be a dedicated reviewer
4. **State-based coordination**: Agents communicate through task files, not assumptions

## Archived Tasks

When a task is complete, you can either:
1. Delete the file (history is in git)
2. Move to `sessions/` as `task_<id>_completed.md`
3. Keep in `state/` with "Complete" status (simple but clutters directory)

Recommendation: Delete after capturing lessons in `sessions/latest_summary.md`.
