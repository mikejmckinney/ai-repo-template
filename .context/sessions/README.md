# Session History

> **Purpose**: Track what happened in previous coding sessions to prevent repeating mistakes and enable cognitive handoff.
>
> **Distinction from task files (`state/task_*.md`)**:
> - `state/task_*.md` = What you're working on (the objective and progress)
> - `sessions/` = What happened and what you learned (history and lessons)

## How to Use

Each agent session owns **one** entry in `latest_summary.md`. The entry is created when the session starts and updated continuously as the session progresses. See AGENTS.md §"Session-state cadence" → "Close-out (every wait-for-input pause)" for the cadence rule that governs when the file is touched.

```
sessions/
├── README.md                  # This file
├── latest_summary.md          # The current agent's working log (one entry, continuously updated)
├── 2026-05-08_pr-261.md       # Archived: previous session's working log
├── 2026-05-07_pr-220.md       # Archived: older session
└── ...
```

### Rotation rule

When a **new agent** starts a fresh task, they MUST rotate the previous session's working log before creating their own entry. Two equivalent forms:

1. **Rename (preferred — preserves history without copy-confusion):**

   ```bash
   git mv .context/sessions/latest_summary.md \
          .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then create a fresh `latest_summary.md` with the new agent's entry.

2. **Copy:**

   ```bash
   cp .context/sessions/latest_summary.md \
      .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then overwrite `latest_summary.md` with the new agent's entry. Useful if downstream tooling needs the previous content to remain at the canonical path during the transition; otherwise prefer Rename.

A **mid-session agent** may also rotate at their discretion if `latest_summary.md` approaches the size cap (see §"Token Efficiency"). Rotation mid-session is rare; the common case is rotation at new-agent start.

## Working-Log Template

Each entry uses the canonical structure below. The fields are filled in progressively across the session:

- **Required at session start**: the header + `Status` + `Started`.
- **Updated at every wait-for-input pause**: `Status`, `What Was Accomplished`, `Files Modified`, `Open Items / Next`.
- **Filled at genuine task close-out** (when the agent has fully *left the work* — session-end, role-handoff, or PR fully closed/merged): `What Shipped`, `Harder Than Expected`, `Generalizable Lessons`, and `Status` flips to `done`.

The `Status` field tracks the **agent's** state, not the PR state. `done` means the agent has nothing further queued and is leaving the work; the PR may still be open awaiting human merge. PR state lives on the matching `coordination.md` lock's `**State**:` field, which has its own trigger (PR close/merge) — see AGENTS.md §"Session-state cadence" → "Close-out (three actions, three triggers)".

```markdown
# Session: <YYYY-MM-DD> — <branch-or-task-id> — <role>

**Status**: in_progress | awaiting_user_input | done
**Issue/PR**: #NNN / #MMM (or `pending` / `N/A`)
**Started**: <ISO-8601 timestamp>

## What Was Accomplished
<running list, appended at every wait-for-input pause; one bullet per chunk of work>

## What Shipped
<one or two lines: what is now true that wasn't before — fill in at done>

## Harder Than Expected
<one or two lines, or "nothing notable" — fill in at done>

## Generalizable Lessons
<one or two lines, or "none" — fill in at done. Open a follow-up issue/PR for any rule/ADR/guide change this implies, and link it here.>

## Files Modified
<running list of file paths and one-line changes>

## Open Items / Next
<current blockers, questions awaiting user input, or "none — task complete">
```

Keep entries short and focused. The point is searchable lessons, not a changelog — the git history is already the changelog. Aim for under 30 lines per entry; rotate before the file-level size cap.

### Filling the retrospective fields

`What Shipped` is the most important close-out field. Write one declarative sentence: what is now true that wasn't true before. Bad: "Updated AGENTS.md cadence." Good: "AGENTS.md cadence trigger now fires on every wait-for-input pause; lock release stays gated to genuine done — split the working-log refresh from lock release so re-acquisition friction doesn't block follow-up turns."

`Harder Than Expected` and `Generalizable Lessons` should be empty or "nothing notable" / "none" by default. Fill them only when something *was* notable — a constraint that surprised you, a rule that doesn't quite fit a class of work, a convention worth documenting. The prompt is "should some rule, ADR, or guide change because of what I learned?" — if yes, write it down and link the follow-up.

## Why This Matters

1. **Prevents Repeated Mistakes**: New sessions can see what approaches failed
2. **Captures Decisions**: Rationale is preserved, not just outcomes
3. **Enables Handoff**: Different agents/developers can pick up where you left off
4. **Reduces Re-exploration**: No need to re-discover what was already learned

## Token Efficiency

- Keep `latest_summary.md` under **100 lines** total — rotate to a date-stamped archive when approaching the cap.
- Keep individual entries under **30 lines** — focus on decisions and blockers, not play-by-play.
- Agents should only read recent sessions (`latest_summary.md` + the most recent 2–3 archives) unless investigating a specific issue.
- Old archives are kept indefinitely as searchable history; PM may prune anything > 90 days at discretion.
