# Session History

> **Purpose**: Preserve durable retrospective lessons from previous coding sessions so future agents do not repeat mistakes.
>
> **Distinction from live state (ADR-025)**:
>
> - GitHub issue/PR + latest `agent-state:v1` comment = live coordination baton.
> - `sessions/` = what shipped, what was harder than expected, and what generalizes.

## How to Use

`latest_summary.md` carries the most recent durable retrospective entry. It is not the live coordination state for an in-flight task; update the latest `agent-state:v1` issue/PR comment for status, blockers, next actions, and handoff.

`feedback_template.md` is the durable starter for optional stakeholder-review notes. Copy it to `.context/sessions/feedback_<iteration-or-feature>.md` when that path is used.

```text
sessions/
├── README.md                  # This file
├── feedback_template.md       # Optional stakeholder feedback starter
├── latest_summary.md          # Latest durable retrospective entry
├── 2026-05-08_pr-261.md       # Archived: previous retrospective entry
├── 2026-05-07_pr-220.md       # Archived: older session
└── ...
```

### Rotation rule

For normal PR-backed work, rotate/archive `latest_summary.md` at PR merge or closeout, using the landed PR as the provenance boundary. For abandoned or no-PR work, archive only when there are durable lessons worth preserving. Two equivalent forms:

1. **Copy (preferred — keeps `latest_summary.md` as a tracked modified file):**

   ```bash
   cp .context/sessions/latest_summary.md \
      .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   git add .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then overwrite `latest_summary.md` in place with the new retrospective entry. Because `latest_summary.md` is never deleted or renamed, it stays a tracked modified file in the working tree, which makes the next durable-summary update easy to spot in normal git status and PR diffs.

2. **Rename (alternative — preserves history without copy-confusion):**

   ```bash
   git mv .context/sessions/latest_summary.md \
          .context/sessions/<YYYY-MM-DD>_<branch-or-topic>.md
   ```

   Then create a fresh `latest_summary.md` with the new agent's entry. Note: the new `latest_summary.md` is an **untracked** file until you `git add` it. If you use Rename, remember to stage the new file before you continue so the fresh retrospective entry lands in the branch diff.

A **mid-session agent** may also rotate at their discretion if `latest_summary.md` approaches the size cap (see §"Token Efficiency"). Rotation mid-session is rare; the common case is rotation at PR merge/closeout.

## Working-Log Template

Each entry uses the canonical structure below. The fields capture durable outcomes, not live handoff state:

- **Required when drafting an entry**: the header + `Status` + `Issue/PR` + `Started`.
- **Filled by PR merge/closeout**: `What Was Accomplished`, `What Shipped`, `Harder Than Expected`, `Generalizable Lessons`, `Files Modified`, and `Open Items / Next`.
- **For live status before merge/closeout**: update the latest `agent-state:v1` comment instead.

The `Status` field tracks the retrospective entry state: `in_progress` while a durable closeout summary is being drafted, `awaiting_user_input` only when retrospective content is blocked on the user, and `done` when the durable entry is complete. PR/live task state lives in GitHub and the latest `agent-state:v1` comment.

```markdown
# Session: <YYYY-MM-DD> — <branch-or-task-id> — <role>

**Status**: in_progress | awaiting_user_input | done
**Issue/PR**: #NNN / #MMM (or `pending` / `N/A`)
**Started**: <ISO-8601 timestamp>

## What Was Accomplished
<short list of completed chunks worth remembering>

## What Shipped
<one or two lines: what is now true that wasn't before — fill in at done>

## Harder Than Expected
<one or two lines, or "nothing notable" — fill in at done>

## Generalizable Lessons
<one or two lines, or "none" — fill in at done. Open a follow-up issue/PR for any rule/ADR/guide change this implies, and link it here.>

## Files Modified
<short list of important file paths and one-line changes>

## Open Items / Next
<follow-ups, deferred items, or "none — task complete">
```

Keep entries short and focused. The point is searchable lessons, not a changelog — the git history is already the changelog. Aim for under 30 lines per entry; rotate before the file-level size cap.

### Filling the retrospective fields

`What Shipped` is the most important close-out field. Write one declarative sentence: what is now true that wasn't true before. Bad: "Updated AGENTS.md cadence." Good: "AGENTS.md cadence trigger now fires on every wait-for-input pause; lock release stays gated to genuine done — split the working-log refresh from lock release so re-acquisition friction doesn't block follow-up turns."

`Harder Than Expected` and `Generalizable Lessons` should be empty or "nothing notable" / "none" by default. Fill them only when something *was* notable — a constraint that surprised you, a rule that doesn't quite fit a class of work, a convention worth documenting. The prompt is "should some rule, ADR, or guide change because of what I learned?" — if yes, write it down and link the follow-up.

## Why This Matters

1. **Prevents Repeated Mistakes**: New sessions can see what approaches failed
2. **Captures Decisions**: Rationale is preserved, not just outcomes
3. **Preserves Lessons**: Different agents/developers can find what shipped and what generalizes
4. **Reduces Re-exploration**: No need to re-discover what was already learned

## Token Efficiency

- Keep `latest_summary.md` under **100 lines** total — rotate to a date-stamped archive when approaching the cap.
- Keep individual entries under **30 lines** — focus on decisions and blockers, not play-by-play.
- Agents should only read recent sessions (`latest_summary.md` + the most recent 2–3 archives) unless investigating a specific issue.
- Old archives are kept as searchable history. Long-term retention and pruning policy is tracked in #299.
