# Session History

> **Purpose**: Track what happened in previous coding sessions to prevent repeating mistakes and enable cognitive handoff.
>
> **Distinction from task files (`state/task_*.md`)**:
> - `state/task_*.md` = What you're working on (the objective and progress)
> - `sessions/` = What happened and what you learned (history and lessons)

## How to Use

After each significant coding session, create a brief summary file:

```
sessions/
├── README.md              # This file
├── latest_summary.md      # Always points to/contains the most recent session
├── 2025-01-25_auth.md     # Session: Implemented authentication
├── 2025-01-24_setup.md    # Session: Initial project setup
└── ...
```

## Session Summary Template

When ending a session, create or update a summary:

```markdown
# Session: [Date] - [Brief Title]

## What Was Accomplished
- [Completed item 1]
- [Completed item 2]

## Key Decisions Made
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

## Problems Encountered
- [Problem]: [How it was solved]

## What Didn't Work
- [Failed approach]: [Why it failed]

## Next Session Should
- [ ] [First priority]
- [ ] [Second priority]

## Files Modified
- `path/to/file` - [What changed]
```

## Why This Matters

1. **Prevents Repeated Mistakes**: New sessions can see what approaches failed
2. **Captures Decisions**: Rationale is preserved, not just outcomes
3. **Enables Handoff**: Different agents/developers can pick up where you left off
4. **Reduces Re-exploration**: No need to re-discover what was already learned

## The "Latest Summary" Pattern

Always maintain `latest_summary.md` with the most recent session info. Agents should:
1. Read `latest_summary.md` when resuming work
2. Update it when ending a session
3. Optionally archive to dated file for history

## Close-out entry (post-merge, required)

When a task merges, the role that led the work appends a **close-out entry** to `latest_summary.md`. PM verifies the entry exists before marking the task done in `coordination.md` (see `.github/agents/pm.agent.md`). Format:

```markdown
## Close-out: <task-id> (YYYY-MM-DD, <role>)

- **Shipped**: <one line: what is now true that wasn't before>
- **Harder than expected**: <one line, or "nothing notable">
- **Generalizable lesson**: <one line; "none" is a valid answer>
- **Follow-up**: <link to issue/PR for any rule/ADR/guide update this implies, or "none">
```

Keep entries short. The point is searchable lessons, not a changelog — the git history is already the changelog.

## Token Efficiency

- Keep summaries brief (< 100 lines)
- Focus on decisions and blockers, not play-by-play
- Archive old sessions to prevent context bloat
- Agents should only read recent sessions unless investigating a specific issue
