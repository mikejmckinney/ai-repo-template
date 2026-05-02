<!-- TEMPLATE_PLACEHOLDER: Update after each session -->

# Latest Session Summary

> **Purpose**: Capture what happened in the most recent session, especially decisions and lessons learned. This prevents repeating mistakes and enables cognitive handoff.
>
> **Note**: For current task progress, see `.context/state/_active.md` or `task_*.md`

## Session Info

**Date**: Not yet started  
**Duration**: N/A  
**Agent/Developer**: N/A

---

## Close-out: pr-179 (fix/177-phase4-fallback-on-push) — merged 2026-04-25

**What shipped**: Phase 4 fallback parser in `agent-relay-reviews.yml`; graceful Copilot fallback when `CLAUDE_PAT` unavailable; ADR-008 updated to document new default behavior.
**What was harder than expected**: Testing the fallback path without triggering real credential failures; mock setup for the parser edge cases required careful scaffolding.
**What generalizes**: The primary-tool-fails → relay-via-alternate-credential pattern is reusable for any multi-credential agent workflow. Filed as a note in ADR-008 for now; no separate rule yet (N=1).

## Close-out: pr-216 (fix/206-pr-completion-criteria) — merged 2026-04-29

**What shipped**: PR completion criteria for interactive sessions codified in AGENTS.md §"PR completion criteria": stop condition (CI green + every bot thread resolved or deferred with comment + Resolution Report posted).
**What was harder than expected**: Nothing unexpected — straightforward docs/policy update.
**What generalizes**: The named convergence criterion pattern ("done when X, Y, Z are all true" rather than "done when it feels done") is broadly applicable to any iterative loop in agent workflows. Worth promoting to `agent-best-practices.md` once a second instance appears.

## What Was Accomplished

<!-- List concrete outcomes, not just "worked on X" -->

- **#150 / PR #218** — shipped postmortem feedback loop v1: `capture-postmortem.md` + `mirror-postmortem.md` prompts, ADR-015, three-tier promotion policy in `docs/postmortems/README.md`, frontmatter schema on `postmortem-template.md`, backfilled frontmatter on postmortem-001, new postmortem-002 (cloud_migration_POC), test.sh invariants, AGENTS.md pointer.
- **Bot review round 1** — 10 findings across codex (2) / gemini (2) / copilot (6) all resolved in commit `45094e9`. Filed real follow-up #219 (re-evaluate postmortem-002 if multi-prompt-sequence mismatch recurs).
- **What was harder than expected**: postmortem-002's frontmatter had a three-way internal inconsistency (synthesized backfill + `mirror_status: mirrored-from:...` + `generalizes: Yes` + `follow_up_artifact: issue-TBD`) that was invisible during single-pass authoring; bot review caught it. Lesson: when a file's frontmatter encodes a policy claim, the policy's own enforcement rule (here: "no `Yes` without a real follow-up artifact") needs a regex-level gate, not just prose. Pushed that gate into `mirror-postmortem.md` Phase 1 (rejects `TBD`/placeholder forms via `^(ADR-\d+|issue-\d+|PR-\d+|none)$`).
- **What generalizes** → likely promotion candidates: (a) the placeholder-rejection pattern is reusable for any prompt that gates output on "real artifact name" — worth extracting to agent-best-practices once a second instance appears; (b) the awk frontmatter validator (positioning + closing-delimiter, distinct exit codes) is a general repo-wide pattern. No follow-up filed yet — N=1.

## Key Decisions Made

<!-- Document decisions AND their rationale -->

| Decision | Rationale |
|----------|-----------|
| postmortem-002 verdict `Yes` → `Unclear` | N=1 isn't a pattern; README's own rule says "appears once is an anecdote." Filing #219 to re-evaluate on second occurrence preserves the signal without locking in a premature template-rule edit. |
| postmortem-002 `mirror_status: mirrored-from:...` → `original` | The file was *authored* in this template (synthesized backfill); `mirrored-from:` documents file provenance, not incident provenance. The two were conflated. Provenance comment now explains the distinction. |
| postmortem-template.md default `generalizes: Unclear` + `follow_up_artifact: none` → `No` + `none` | Only consistent placeholder combo. `Unclear` requires a follow-up per the schema's own rule, so a template default of `Unclear` would force every copy to start in violation. |
| Pin `source_commit` to SHA, not branch name | Branch refs move; immutability is the whole point of provenance metadata. |
| Auto-resolve all 10 bot threads (Phase 4 default ON) | Per ADR-008/pr-resolve-all.md: every per-thread gate (allow-listed bot author + ✅ Fixed + verification green) passed; relay fallback wasn't needed (no FORBIDDEN). |

## What Didn't Work

<!-- IMPORTANT: This prevents the next session from repeating failed approaches -->

| Approach Tried | Why It Failed |
|----------------|---------------|
| N/A | N/A |

## Problems Encountered

<!-- Issues that came up and how they were resolved (or not) -->

None yet.

## Next Session Should

<!-- Specific, actionable recommendations -->

1. Initialize the project from this template
2. Fill in `.context/00_INDEX.md` with project details
3. Define the roadmap in `.context/roadmap.md`

## Environment Notes

<!-- Any setup issues, dependency problems, or environment quirks discovered -->

None yet.

---

## How to Use This File

1. **End of session**: Update all sections above
2. **Key insight**: The "What Didn't Work" section is the most valuable—it prevents wasted effort
3. **Archiving**: Optionally copy to a dated file (e.g., `2025-01-25_auth.md`) before starting fresh
4. **Start of session**: Read this file to understand recent context before beginning work
