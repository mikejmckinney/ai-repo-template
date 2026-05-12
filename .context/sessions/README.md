# Session History

> **Purpose**: Durable retrospective lessons from completed work — `What Shipped`, `Harder Than Expected`, `Generalizable Lessons`. Preserved in-tree under ADR-025 (issue #298) because they ship to downstream template consumers, survive forks, and are grep-able without GitHub API access.
>
> **What this is NOT (post-ADR-025)**: This is **not** the live coordination surface. Live state — since-last-update delta, blockers, next 1–3 actions, handoff baton — lives in the latest `agent-state:v1` GitHub issue/PR comment per [`.context/state/agent_state_comment_template.md`](../state/agent_state_comment_template.md). Do not mirror live coordination state into `latest_summary.md`.
>
> **Distinction from legacy task files**:
> - `state/task_*.md` (legacy) = was used for in-progress task tracking under the pre-ADR-025 model. Replaced by GitHub issue body + `agent-state:v1` comment.
> - `sessions/` = durable retrospective lessons after PR merge / close-out.

## How to Use

Each agent session that produces a merged PR (or closes work without merging) appends **one** entry to `latest_summary.md` at PR merge / close-out. The entry captures retrospective lessons; the live coordination delta lived in the `agent-state:v1` comment during the work and does not need to be repeated here.

```
sessions/
├── README.md                  # This file
├── latest_summary.md          # Most recent entries (current rotation window)
├── 2026-05-08_pr-261.md       # Archived: previous rotation
├── 2026-05-07_pr-220.md       # Archived: older rotation
└── ...
```

### Rotation rule (post-ADR-025)

Rotate `latest_summary.md` at **PR merge / close-out** for normal PR-backed work. The landed PR is the stable provenance boundary for retrospective lessons. The previous rotation trigger ("new agent starts a fresh task") is no longer normative — agents now read the issue body, the latest `agent-state:v1` comment, and recent `latest_summary.md` entries to onboard, instead of treating `latest_summary.md` as the live working log.

For abandoned/no-PR work, archive only when there are durable lessons worth preserving.

Two equivalent rotation forms:

1. **Copy (preferred — keeps `latest_summary.md` as a tracked modified file):**

   ```bash
   cp .context/sessions/latest_summary.md \
      .context/sessions/<YYYY-MM-DD>_pr-<NNN>.md
   git add .context/sessions/<YYYY-MM-DD>_pr-<NNN>.md
   ```

   Then overwrite `latest_summary.md` in place with the new rotation window. Because `latest_summary.md` is never deleted or renamed, it stays a tracked modified file in the working tree.

2. **Rename (alternative — preserves history without copy-confusion):**

   ```bash
   git mv .context/sessions/latest_summary.md \
          .context/sessions/<YYYY-MM-DD>_pr-<NNN>.md
   ```

   Then create a fresh `latest_summary.md`. Note: the new `latest_summary.md` is an **untracked** file until you `git add` it.

A mid-session agent may also rotate at their discretion if `latest_summary.md` approaches the size cap (see §"Token Efficiency"). Mid-session rotation remains rare; the common case is PR-merge rotation.

> **Bounded retention / pruning policy** is intentionally out of scope for ADR-025 and is tracked separately in #299. Until #299 ships, archives accumulate and PM may prune at discretion.

## Retrospective entry template

Each entry uses the structure below. Fields are filled at PR merge / close-out:

```markdown
# Session: <YYYY-MM-DD> — <branch-or-pr-id> — <role>

**Status**: done
**Issue/PR**: #NNN / #MMM
**Closed**: <ISO-8601 timestamp>

## What Shipped
<one declarative sentence: what is now true that wasn't before>

## Harder Than Expected
<one or two lines, or "nothing notable">

## Generalizable Lessons
<one or two lines, or "none". Open a follow-up issue/PR for any rule/ADR/guide change this implies, and link it here.>

## Files Modified
<key file paths and one-line changes; the PR diff is the full record — keep this short>

## Links
- Issue: #NNN
- PR: #MMM
- Latest live `agent-state:v1` comment: <permalink>
```

Keep entries short and focused — searchable lessons, not changelogs (the git history is the changelog). Aim for under 30 lines per entry; rotate before the file-level size cap.

### Filling the retrospective fields

`What Shipped` is the most important field. Write one declarative sentence: what is now true that wasn't true before. Bad: "Updated AGENTS.md cadence." Good: "AGENTS.md cadence trigger now fires on every wait-for-input pause; lock release stays gated to genuine done — split the working-log refresh from lock release so re-acquisition friction doesn't block follow-up turns."

`Harder Than Expected` and `Generalizable Lessons` should be empty or "nothing notable" / "none" by default. Fill them only when something *was* notable — a constraint that surprised you, a rule that doesn't quite fit a class of work, a convention worth documenting. The prompt is "should some rule, ADR, or guide change because of what I learned?" — if yes, write it down and link the follow-up.

## Why this directory matters (preserved in-tree per ADR-025)

ADR-025 moved live coordination state to GitHub issue/PR comments. Retrospective session lessons stay in-tree because they:

1. **Prevent repeated mistakes** — new sessions can grep what approaches failed.
2. **Capture rationale** — not just the code change, but why it was made.
3. **Ship to downstream consumers** — repos forked from this template inherit the lessons.
4. **Survive without GitHub API access** — grep / read-only repo browsing finds them.
5. **Live alongside ADRs and postmortems** — the in-tree durable-knowledge layer.

`docs/decisions/**` (ADRs), `docs/postmortems/**` (formal incident analysis), and `.context/rules/**` round out that layer. Sessions are the lightest-weight surface — informal lessons from normal work, written as the PR merges.

## Token Efficiency

- Keep `latest_summary.md` under **100 lines** total — rotate to a date-stamped archive when approaching the cap (or at PR merge per the rule above, whichever comes first).
- Keep individual entries under **30 lines** — focus on lessons, not play-by-play.
- Agents should only read recent sessions (`latest_summary.md` + the most recent 2–3 archives) unless investigating a specific issue.
- Old archives are kept indefinitely as searchable history per the current policy. Bounded retention/pruning is tracked in #299.
