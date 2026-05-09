<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the current agent session's working log per the canonical template in `.context/sessions/README.md` § "Working-Log Template". One entry per agent-session, updated continuously at every wait-for-input pause (see AGENTS.md § "Session-state cadence"). Downstream projects should clear the example body during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`). -->

# Session: 2026-05-09 — chore/closeout-276-state-cleanup — devops

**Status**: done
**Issue/PR**: #255 / #276 (merged) → this PR (chore close-out)
**Started**: 2026-05-09T05:50:00Z

## What Was Accomplished
- Merged PR #276 (`scripts/setup.sh` modularization — issue #255 Phase 4c) at squash commit `ebf1fed` after the pr-resolve-all loop converged with two consecutive clean rounds (R4 + R5). 5 review rounds total: R1 (5 findings — 2 fixed: README wording mismatch + nullglob no-modules guard; 3 deferred as pre-existing in the monolithic `setup.sh` and out of scope for shape-preserving extraction: `\s` in basic grep, `_ensure_label` `grep -qF` substring match, `pip` vs `pip3`); R2 (shfmt v3.8.0 rejected `[0-9]` glob in array initializer — rewrote as for-loop append); R3 (codex P2: missing-phase regression — added explicit `_expected_phases` manifest assertion); R4 + R5 clean.
- Dispatched the chore close-out per ADR-007: rotated previous session entry (chore-275 close-out) to `.context/sessions/2026-05-09_archived-275.md` using the Copy form (preferred per PR #271 / issue #270). Replaced `latest_summary.md` body in place.
- Added `coordination.md` Recent History entry for `pr-255-phase4c` (PR #276 merged, 5 review rounds, R4+R5 clean).

## What Shipped
- `scripts/setup.sh` — was a 508-line monolith; now an 88-line orchestrator that asserts an explicit `_expected_phases` manifest (00, 10, 20, 30, 40, 50, 60, 70) before sourcing `scripts/setup/[0-9][0-9]-*.sh` in lexical order.
- `scripts/setup/` — 8 single-concern phase modules: `00-detect-repo.sh`, `10-env-file.sh`, `20-install-dependencies.sh`, `30-build.sh`, `40-ensure-labels.sh`, `50-ensure-variables.sh`, `60-check-secrets.sh`, `70-verify-env.sh`.
- `scripts/setup/README.md` — module table, ordering, "how to run a single module" recipe, and "how to add a new module" section.
- `test.sh` — four hardcoded greps that asserted label/variable wiring on `scripts/setup.sh` updated to point at the new module files (`scripts/setup/40-ensure-labels.sh` and `scripts/setup/50-ensure-variables.sh`); baseline 365/1/0 preserved.
- `AI_REPO_GUIDE.md` — Setup Scripts table updated: `scripts/setup.sh` row now describes the orchestrator pattern; new `scripts/setup/*.sh` row added.

## Harder Than Expected
- **shfmt v3.8.0 array-init parsing**: `_setup_modules=("$SCRIPT_DIR"/setup/[0-9][0-9]-*.sh)` parsed cleanly under bash but errored under shfmt with `"[x]" must be followed by =`. The fix was rewriting as `_setup_modules=(); for _module in ...; do _setup_modules+=("$_module"); done` — slightly more verbose, but accepts both linters. Worth remembering: shfmt has its own opinion about where bracket-glob patterns may legally appear.
- **Missing-phase regression** (codex P2 in R3): the initial nullglob check only caught the *zero-modules* case — a partial checkout dropping a *single* module file (e.g., `50-ensure-variables.sh`) would silently skip that phase and still print "Setup Complete". The monolith never had this failure mode because all phases lived in one file. Fix: declare an explicit `_expected_phases` manifest in the orchestrator and assert each prefix has a matching module before sourcing. Verified by removing `50-ensure-variables.sh` and confirming the new `[ERROR] Missing setup phase module(s): 50.` line + exit 1.

## Generalizable Lessons
- **Decomposing a script introduces "missing-piece" failure modes the monolith cannot have**. The natural reflex (check for non-emptiness) is too weak — partial checkouts and packaging errors typically drop *a* file, not *all* files. The right shape is an explicit manifest assertion: declare what you expect, fail loudly if it's missing. Cheap to add, catches the regression class generically.
- **Shape-preserving refactors should aggressively defer "while you're in there" findings**. Three R1 findings were genuine bugs (`\s` portability, `grep -qF` substring match, `pip` vs `pip3`) but all pre-existed in the monolith on `main`. Fixing them mid-extraction would have made the diff harder to verify byte-equivalent. The deferral pattern (`Deferred — pre-existing in monolithic ...; out of scope for shape-preserving extraction; worth a follow-up`) keeps the refactor's blast radius tight.
- **Test fixtures pinned to file paths break under modularization**. `test.sh` had four hardcoded `grep ... scripts/setup.sh` assertions; after extraction, those greps had to point at the new module files. Worth searching the test suite for hardcoded path references *before* moving any code, so the test updates land in the same commit.

## Files Modified
- `.context/sessions/latest_summary.md` (this entry, in-place rewrite per the Copy rotation)
- `.context/sessions/2026-05-09_archived-275.md` (rotation archive of previous entry)
- `.context/state/coordination.md` (Recent History entry added for `pr-255-phase4c`)

## Open Items / Next
- **Issue #255 Phase 4d** (slim `test.sh` and `setup.sh` to ≤200 lines + delete legacy `scripts/test-*.sh`) is the final phase. `setup.sh` is now 88 lines (well under the 200-line cap); the remaining work is on `test.sh` (1,713 lines today). Slimming `test.sh` to ≤200 lines requires migrating most of its assertions out — likely into per-concern `.bats` files under `scripts/tests/`. May exceed a single PR; will re-scope at plan time if needed.
- The three deferred R1 findings on PR #276 (`\s` portability, `grep -qF` substring match, `pip` vs `pip3`) are good candidates for a small follow-up issue. They affect `scripts/setup/{30-build,40-ensure-labels,20-install-dependencies}.sh` and are all single-line fixes.
