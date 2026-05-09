<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the current agent session's working log per the canonical template in `.context/sessions/README.md` § "Working-Log Template". One entry per agent-session, updated continuously at every wait-for-input pause (see AGENTS.md § "Session-state cadence"). Downstream projects should clear the example body during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`). -->

# Session: 2026-05-09 — chore/closeout-278-state-cleanup — devops

**Status**: done
**Issue/PR**: #255 / #278 (merged) → this PR (chore close-out)
**Started**: 2026-05-09T13:50:00Z

## What Was Accomplished
- Merged PR #278 (`test.sh` modularization — issue #255 Phase 4d) at squash commit `bc1393e` after the pr-resolve-all loop converged with two consecutive clean rounds (R6 + R7). 7 review rounds total: R1 (7 threads, 4 distinct findings — duplicate comment block in test.sh, AI_REPO_GUIDE doc inconsistency on glob pattern, `$LF_FILE` cross-module coupling in 115-, lexical glob misordering across mixed-width prefixes); R2 (3 reviewers all flagged the same continuity-regex-looser-than-glob issue); R3 (gemini High: unguarded `awk` on AGENTS.md crashes orchestrator under `set -e`); R4 (2 doc-sync followups from R1 renumber: tree doc + 29 module headers); R5 (gemini Medium x2 — schema-bypass-via-comments fixed, syntax-coverage scope expansion deferred); R6 + R7 clean.
- Dispatched the chore close-out per ADR-007: rotated previous session entry (chore-277 close-out) to `.context/sessions/2026-05-09_archived-277.md` using the Copy form (preferred per PR #271 / issue #270). Replaced `latest_summary.md` body in place.
- Added `coordination.md` Recent History entry for `pr-255-phase4d` (PR #278 merged, 7 review rounds, R6+R7 clean).
- Filed two follow-up issues for deferred / scope-expansion work: #280 (un-wrap bats tests + delete legacy `scripts/test-*.sh`) and #281 (expand `055-script-syntax.sh` to cover `scripts/`, `scripts/checks/`, `scripts/setup/`).

## What Shipped
- `test.sh` — was a 1,720-line monolith; now a 95-line orchestrator that sources `scripts/checks/[0-9][0-9][0-9]-*.sh` modules in lexical order, with a continuity-check guard that hard-fails if any `*.sh` file in `scripts/checks/` lacks a 3-digit numeric prefix.
- `scripts/checks/` — 29 single-concern check modules with 3-digit zero-padded prefixes (`010-required-files.sh` through `150-postmortem-frontmatter.sh`). Shape-preserving extraction; every assertion that existed in the monolith exists in the same order in the modules. `bash test.sh` still reports 365 / 1 / 0.
- `scripts/checks/README.md` — module table, ordering, "how to add a new module" recipe, and explicit explanation of why the prefix is 3-digit zero-padded (lexical-vs-numeric sort).
- `AI_REPO_GUIDE.md` — directory tree updated with `scripts/checks/<NNN>-*.sh` entry; Setup Scripts table updated: `test.sh` row now describes the orchestrator pattern; new `scripts/checks/*.sh` row added.

## Harder Than Expected
- **Mixed-width numeric prefixes break lexical sort**: the natural-feeling `10-`, `15-`, …, `100-`, `150-` numbering scheme makes bash globs sort `100-` *before* `15-` (lexical comparison, leftmost differing character wins). Caught by 3 reviewers in R1 (cursor Medium, codex P2, copilot via doc inconsistency). Fix was to renumber all 29 modules to 3-digit zero-padded form (`010-`, `015-`, …, `100-`, `150-`) so lexical sort matches numeric sort, and tighten the loader glob to `[0-9][0-9][0-9]-*.sh`. R2 then surfaced a follow-on: the continuity-check regex `^[0-9]+-` was looser than the glob, so a 1- or 2-digit prefix would pass the guard but be silently skipped — defeating the guard's purpose. Tightened to `^[0-9]{3}-`.
- **`$LF_FILE` cross-module coupling** (R1, gemini High + cursor Medium): `115-phase15-invariants.sh` referenced `$LF_FILE` without defining it locally — relying on `110-lint-format-invariants.sh` having sourced first. The order-dependence was invisible until you mentally executed the modules out of order. Fixed by defining `LF_FILE` locally in 115- and adding an explicit `[[ -f "$LF_FILE" ]]` guard before `grep`.
- **Behavior preservation traps**: 6 distinct reviewer findings across R3-R5 were genuine latent bugs in the monolith that the extraction faithfully preserved (unguarded `awk` on AGENTS.md, schema-bypass-via-comments in `_active.md`, incomplete `bash -n` coverage). Two were cheap one-line guards and got applied; one (syntax-coverage expansion) was a real scope expansion that would change the 365/1/0 baseline and got deferred to issue #281.

## Generalizable Lessons
- **Fixed-width numeric prefixes are a hard requirement, not a style preference**, the moment you have a glob that sources by lexical order. Mixed-width works for the first 9 entries and silently breaks at the 10th. The cheap insurance is to start at 3 digits (`010-`) from day one — costs nothing, immune to the bug class. Phase 4c's `scripts/setup/` happened to use 2-digit prefixes only (00-70, 8 modules total) and got away with it; Phase 4d's 29 modules crossing the 3-digit boundary forced the lesson.
- **Loader glob and continuity-check regex must use the same shape**. R1 introduced `[0-9][0-9][0-9]-*.sh` as the loader glob but left the guard regex as `^[0-9]+-` — and 3 reviewers in R2 flagged the gap independently. Treat the two patterns as a coupled pair: change one, change the other in the same commit.
- **The "Deferred —" thread-reply convention works**. PR #278 had two findings (R3 awk-guard, R5 schema-bypass) that were genuine pre-existing latent bugs and got fixed because they were one-line patches; one finding (R5 syntax-coverage) was a real scope expansion and got deferred via the marker. The convention let the resolve loop converge in 7 rounds instead of looping forever on "while you're in there" findings.

## Files Modified
- `.context/sessions/latest_summary.md` (this entry, in-place rewrite per the Copy rotation)
- `.context/sessions/2026-05-09_archived-277.md` (rotation archive of previous entry)
- `.context/state/coordination.md` (Recent History entry added for `pr-255-phase4d`)

## Open Items / Next
- **Issue #255 stays open** until the two follow-up issues ship: #280 (un-wrap bats tests + delete legacy `scripts/test-*.sh`, the original Phase 4d acceptance criterion that PR #278 deferred because the bats wrappers still call the legacy scripts) and #281 (expand `055-script-syntax.sh` coverage to `scripts/`, `scripts/checks/`, `scripts/setup/`, deferred from PR #278 R5).
- All four structural phases of issue #255 (4a helpers, 4b bats infra, 4c setup.sh slim, 4d test.sh slim) are now merged. The orchestrator pattern (`<NNN>-*.sh` modules under `scripts/{checks,setup}/`) is established and documented; new check modules can be added without touching the orchestrators.
