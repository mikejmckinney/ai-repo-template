<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the most recent session's outcomes. Downstream projects should clear the example body below during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`); ongoing maintenance is per AGENTS.md → "Session-state cadence". -->

# Latest Session Summary

> **Purpose**: Capture what happened in the most recent session, especially decisions and lessons learned. This prevents repeating mistakes and enables cognitive handoff.
>
> **Note**: For current task progress, see `.context/state/_active.md` or `task_*.md`

## Session Info

**Date**: 2026-05-03
**Duration**: ~1h
**Agent/Developer**: GitHub Copilot (copilot/phase-1-issue-229)

---

## Close-out: pr-229-phase1 — in progress 2026-05-03

**What shipped**: Phase 1 of issue #229. Replaced `lint-and-format.yml` TEMPLATE_PLACEHOLDER with shellcheck (warning+, blocks) + shfmt (-d, blocks) + actionlint (blocks). Added `scripts/pr-iteration-stats.sh` — rolling 14-day PR review-loop metric with three counters (total_rounds, fix_rounds, rejected_rounds) plus thread counts, `--window`, and `--json` flags. Added `scripts/test-pr-iteration-stats.sh` with 19 smoke-test assertions. Ran shfmt auto-format on 14 pre-existing scripts. Added 8 new test.sh invariants. Updated `AI_REPO_GUIDE.md` with new script in table + verification commands.
**What was harder than expected**: `python3 - << 'PYEOF'` combined with stdin pipe fails under shellcheck (SC2259 — heredoc overrides pipe). Fixed by writing Python scripts to `mktemp -d` temp files and piping JSON to them separately.
**What generalizes**: SC2259 pattern: never combine `cmd | python3 - << 'HEREDOC'`. Always write inline Python to a temp file and call it as `python3 "$TMP_FILE"` when stdin data must be piped.



**What shipped**: Released stale locks for pr-216 and pr-179 in `coordination.md`; added missing `Result:` lines; refreshed `_active.md` to Issue #220 Phase 2 state; added missing close-out summaries for pr-179 and pr-216 to `latest_summary.md`; pre-registered `issue-220-phase2` lock template in PM Notes with `Paths` including `.github/agents/*.agent.md` and `adr-003` (kept out of Active Locks to avoid false stale-lock alerts before the branch exists).
**What was harder than expected**: Copilot relay (copilot-swe-agent) made an incorrect ISS-03 fix — removed `.github/agents/*.agent.md` from `_active.md` citing ADR-003, but live VS Code docs verify `.agent.md` supports `model:`. Required manual revert in `132452f`. The relay agent was operating on stale ADR knowledge.
**What generalizes**: When a relay agent cites an ADR as justification for a correction, verify the cited ADR is not itself under active revision. If a Phase 2 plan is in flight that supersedes an ADR, `_active.md` should reference the plan, not the soon-to-be-obsolete ADR. Add a note to agent-best-practices once a second instance appears.

## Backfilled History: pr-179 (fix/177-phase4-fallback-on-push) — merged 2026-04-25

**What shipped**: Phase 4 fallback parser in `agent-relay-reviews.yml`; graceful Copilot fallback when `CLAUDE_PAT` unavailable; ADR-008 updated to document new default behavior.
**What was harder than expected**: Testing the fallback path without triggering real credential failures; mock setup for the parser edge cases required careful scaffolding.
**What generalizes**: The primary-tool-fails → relay-via-alternate-credential pattern is reusable for any multi-credential agent workflow. Filed as a note in ADR-008 for now; no separate rule yet (N=1).

## Backfilled History: pr-216 (fix/206-pr-completion-criteria) — merged 2026-04-29

**What shipped**: PR completion criteria for interactive sessions codified in AGENTS.md §"PR completion criteria": stop condition (CI green + every bot thread resolved or deferred with comment + Resolution Report posted).
**What was harder than expected**: Nothing unexpected — straightforward docs/policy update.
**What generalizes**: The named convergence criterion pattern ("done when X, Y, Z are all true" rather than "done when it feels done") is broadly applicable to any iterative loop in agent workflows. Worth promoting to `agent-best-practices.md` once a second instance appears.

## What Was Accomplished

<!-- List concrete outcomes, not just "worked on X" -->

- **PR #225 / chore/coordination-cleanup** — released stale locks for pr-179 and pr-216 in `coordination.md`; added missing `Result:` lines and full lock blocks to Recent History; refreshed `_active.md` to Issue #220 Phase 2 state; backfilled missing `latest_summary.md` close-out entries for pr-179 and pr-216; pre-registered `issue-220-phase2` lock template in PM Notes with correct Paths and `State: backlog` (omitted from Active Locks to avoid false stale-lock alerts before branch exists).
- **Issue #224 closed** — the stale-lock alert that triggered this PR; root cause was lock blocks never moved to Recent History when PRs #179 and #216 merged.
- **5 bot-review rounds** — 15 total findings across gemini (11), chatgpt (3), and copilot (1); all resolved across commits `cbbf175` → `35eae6e` (copilot-swe-agent) → `132452f` → `5d52405` → `7a1e515` → `07b3de7`.

## Key Decisions Made

<!-- Document decisions AND their rationale -->

| Decision | Rationale |
|----------|-----------|
| `issue-220-phase2` lock `Session: feature/architect-220-phase2` | `TBD` breaks coordination automation (no branch match); expected implementation branch name used so on-open and on-close hooks fire correctly when Phase 2 work starts. |
| Lock state `planned` → `backlog` | No `task_issue-220-phase2.md` created in this PR; `backlog` is the accurate pre-dispatch state per Task States table. |
| ISS-03 revert of copilot-swe-agent fix | Agent removed `.github/agents/*.agent.md` from `_active.md` citing ADR-003; live VS Code docs verify `.agent.md` supports `model:` field — the ADR is superseded by Phase 2 plan. |

## What Didn't Work

<!-- IMPORTANT: This prevents the next session from repeating failed approaches -->

| Approach Tried | Why It Failed |
|----------------|---------------|
| `Session: chore/coordination-cleanup` on `issue-220-phase2` lock | Stale-lock workflow would fire false alert on PR #225 close — corrected to expected implementation branch. |
| `Session: TBD` on `issue-220-phase2` lock | Coordination automation keys off exact Session value; TBD matches nothing, causing duplicate missing-lock suggestions on future PRs. |

## Problems Encountered

<!-- Issues that came up and how they were resolved (or not) -->

- Copilot relay (copilot-swe-agent) incorrectly reverted ISS-03 by citing stale ADR-003. Required manual fix in commit `132452f`.

## Next Session Should

<!-- Specific, actionable recommendations -->

1. Start Issue #220 Phase 2 on branch `feature/architect-220-phase2`; create `task_issue-220-phase2.md` and move lock to `planned`
2. Address Issue #226 (state-file discipline): 4 sequenced PRs per plan comment #4364665611
3. Verify copilot-relay workflow failure (noted by user; deferred from this session)

## Environment Notes

<!-- Any setup issues, dependency problems, or environment quirks discovered -->

- Copilot relay workflow (`agent-relay-reviews.yml`) failing as of 2026-05-02; copilot-swe-agent FORBIDDEN errors when resolving threads. Manual GraphQL resolution used as workaround.

---

## How to Use This File

1. **End of session**: Update all sections above
2. **Key insight**: The "What Didn't Work" section is the most valuable—it prevents wasted effort
3. **Archiving**: Optionally copy to a dated file (e.g., `2025-01-25_auth.md`) before starting fresh
4. **Start of session**: Read this file to understand recent context before beginning work
