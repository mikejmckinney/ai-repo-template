# Session History

> **Purpose**: Durable retrospective lessons from previous coding sessions \u2014 what was learned, what generalizes, what should change next time. Distinct from live coordination state, which lives on GitHub per [ADR-025](../../docs/decisions/adr-025-github-first-agent-state.md) (the assigned issue, the linked PR, the latest `agent-state:v1` comment, and labels).
>
> **What this directory is NOT**: a live coordination baton. Mid-task `Status:`, `Blockers`, and `Next 1\u20133 actions` belong in the `agent-state:v1` issue/PR comment, not here.

## How to Use

`latest_summary.md` is the current session's durable retrospective entry. Each agent session writes one entry there; on PR merge or closeout, the entry is rotated to a date-stamped archive and a fresh `latest_summary.md` is created for the next session.

```
sessions/
\u251c\u2500\u2500 README.md                   # This file
\u251c\u2500\u2500 latest_summary.md           # Current session's durable retrospective entry
\u251c\u2500\u2500 2026-05-08_pr-261.md        # Archived: previous session's entry
\u251c\u2500\u2500 2026-05-07_pr-220.md        # Archived: older session
\u2514\u2500\u2500 ...
```

### Rotation rule

Rotate `latest_summary.md` at **PR merge or closeout** for normal PR-backed work; the landed PR is the natural provenance boundary. For abandoned or no-PR work, archive only when there are durable lessons worth preserving \u2014 no archive is required for routine sessions that produced nothing generalizable.

Two equivalent rotation forms:

1. **Copy (preferred \u2014 keeps `latest_summary.md` as a tracked modified file):**

   ```bash
   cp .context/sessions/latest_summary.md \
      .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   git add .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then overwrite `latest_summary.md` in place with the new agent's entry. Because `latest_summary.md` is never deleted or renamed, it stays a tracked modified file in the working tree \u2014 `git diff --name-only HEAD` sees it, so the legacy `make closeout` (`scripts/closeout.sh`) check 1 passes without a manual `git add` for branches still using that path.

2. **Rename (alternative \u2014 preserves history without copy-confusion):**

   ```bash
   git mv .context/sessions/latest_summary.md \
          .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then create a fresh `latest_summary.md` with the new agent's entry. Note: the new `latest_summary.md` is an **untracked** file until you `git add` it; remember to stage it before invoking the legacy `make closeout` path.

A mid-session agent may also rotate at their discretion if `latest_summary.md` approaches the size cap (see \u00a7 "Token Efficiency"). Rotation mid-session is rare; the common case is rotation at PR merge.

## Working-Log Template

Each entry uses the canonical structure below. Live mid-task fields (`Status`, `Blockers`, `Next 1\u20133 actions`) live in the `agent-state:v1` GitHub comment per ADR-025; this entry is the durable retrospective layer.

- **Required at session start**: the header + `Started`.
- **Updated as work progresses**: `What Was Accomplished`, `Files Modified` (running lists; appended at each pause, but the live coordination is in the `agent-state:v1` comment).
- **Filled at PR merge / closeout** (the agent has fully left the work): `What Shipped`, `Harder Than Expected`, `Generalizable Lessons`.

```markdown
# Session: <YYYY-MM-DD> \u2014 <branch-or-task-id> \u2014 <role>

**Issue/PR**: #NNN / #MMM (or `pending` / `N/A`)
**Started**: <ISO-8601 timestamp>

## What Was Accomplished
<running list, appended as work proceeds; one bullet per chunk of work>

## What Shipped
<one or two lines: what is now true that wasn't before \u2014 fill in at merge/closeout>

## Harder Than Expected
<one or two lines, or "nothing notable" \u2014 fill in at merge/closeout>

## Generalizable Lessons
<one or two lines, or "none" \u2014 fill in at merge/closeout. Open a follow-up issue/PR for any rule/ADR/guide change this implies, and link it here.>

## Files Modified
<running list of file paths and one-line changes>
```

Keep entries short and focused. The point is searchable lessons, not a changelog \u2014 the git history is already the changelog. Aim for under 30 lines per entry; rotate before the file-level size cap.

### Filling the retrospective fields

`What Shipped` is the most important close-out field. Write one declarative sentence: what is now true that wasn't true before. Bad: "Updated AGENTS.md cadence." Good: "AGENTS.md cadence trigger now fires on every wait-for-input pause; lock release stays gated to genuine done \u2014 split the working-log refresh from lock release so re-acquisition friction doesn't block follow-up turns."

`Harder Than Expected` and `Generalizable Lessons` should be empty or "nothing notable" / "none" by default. Fill them only when something *was* notable \u2014 a constraint that surprised you, a rule that doesn't quite fit a class of work, a convention worth documenting. The prompt is "should some rule, ADR, or guide change because of what I learned?" \u2014 if yes, write it down and link the follow-up.

## Why This Matters

1. **Prevents Repeated Mistakes**: New sessions can see what approaches failed
2. **Captures Decisions**: Rationale is preserved, not just outcomes
3. **Enables Handoff**: Different agents/developers can pick up where you left off
4. **Reduces Re-exploration**: No need to re-discover what was already learned

## Token Efficiency

- Keep `latest_summary.md` under **100 lines** total \u2014 rotate to a date-stamped archive when approaching the cap.
- Keep individual entries under **30 lines** \u2014 focus on decisions and blockers, not play-by-play.
- Agents should only read recent sessions (`latest_summary.md` + the most recent 2\u20133 archives) unless investigating a specific issue.
- Archive retention and pruning policy beyond this guidance is tracked in #299.
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

1. **Copy (preferred — keeps `latest_summary.md` as a tracked modified file):**

   ```bash
   cp .context/sessions/latest_summary.md \
      .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   git add .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then overwrite `latest_summary.md` in place with the new agent's entry. Because `latest_summary.md` is never deleted or renamed, it stays a tracked modified file in the working tree — `git diff --name-only HEAD` sees it, so `make closeout` (`scripts/closeout.sh`) check 1 passes without a manual `git add`. This is why Copy is preferred over Rename.

2. **Rename (alternative — preserves history without copy-confusion):**

   ```bash
   git mv .context/sessions/latest_summary.md \
          .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then create a fresh `latest_summary.md` with the new agent's entry. Note: the new `latest_summary.md` is an **untracked** file until you `git add` it. `make closeout`'s diff-based check 1 won't see it without that explicit `git add`. If you use Rename, remember to stage the new file before running `make closeout`.

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
