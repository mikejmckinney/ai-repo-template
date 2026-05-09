<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the current agent session's working log per the canonical template in `.context/sessions/README.md` § "Working-Log Template". One entry per agent-session, updated continuously at every wait-for-input pause (see AGENTS.md § "Session-state cadence"). Downstream projects should clear the example body during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`). -->

# Session: 2026-05-09 — chore/closeout-274-state-cleanup — devops

**Status**: done
**Issue/PR**: #255 / #274 (closed) → this PR (chore close-out)
**Started**: 2026-05-09T05:00:00Z

## What Was Accomplished
- Merged PR #274 (`scripts/tests/` bats infrastructure + 11 .bats wrappers + ci-tests.yml integration — issue #255 Phase 4b) at squash commit `409532b` after the pr-resolve-all loop converged with two consecutive clean rounds (R2 + R3). 3 review rounds total: R1 (7 distinct findings — `BATS_TEST_TIMEOUT` in `setup()` no-op flagged by both codex and cursor, ci-tests.yml failure-report ignores `bats-output.log`, README install/CI mismatch, bats failure cancels legacy test step), R2+R3 clean.
- Dispatched the chore close-out per ADR-007: rotated previous session entry (chore-273 close-out) to `.context/sessions/2026-05-09_archived-273.md` using the Copy form (PR #271 / issue #270). Replaced `latest_summary.md` body in place.
- Added `coordination.md` Recent History entry for `pr-255-phase4b` (PR #274 merged, 3 review rounds, R2+R3 clean).
- No `_active.md` Task section to remove and no Active Lock to release for `feature/devops-255-phase4b-bats-migration`: that branch did not appear in `## Active Locks` of `.context/state/coordination.md` at PR-274 merge time (uncertain — same process-gap pattern as PR #271/#272).

## What Shipped
- `scripts/tests/` directory + 11 `.bats` wrapper files (one per legacy `scripts/test-*.sh`).
- `scripts/tests/README.md` — layout, install (apt + brew with `parallel`), run commands, migration approach (wrapping mode now; per-fixture splits later), and conventions.
- `.github/workflows/ci-tests.yml` — apt-get install bats + parallel, `bats scripts/tests/` step, gate-on-combined-results step that fails the job if either suite failed.
- `AI_REPO_GUIDE.md` — directory tree + file table updated for `scripts/tests/`.

## Harder Than Expected
- `BATS_TEST_TIMEOUT=300` set inside `setup()` is a no-op. Bats reads the variable in the *parent* process before forking the test subprocess, so any updates inside `setup()` are invisible. Fix: top-level `export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"` at file-load time. Both codex (P2) and cursor (Medium) flagged this independently in R1 — high-confidence finding.
- The original ci-tests.yml integration would have skipped the legacy `./test.sh` parity gate entirely if bats failed, because Actions skips subsequent steps after a failure. The plan calls for "both run alongside for parity"; achieving that needed `continue-on-error: true` on the bats step + `if: always()` on the legacy step + a final gate step that re-fails the job if either suite failed. Without the final gate, `continue-on-error: true` would let a red bats run merge silently — exactly the pattern the gate prevents.

## Generalizable Lessons
- Variables that gate **before-fork** behavior in test runners (timeouts, isolation modes, hook ordering) must be set at file-load time, not in `setup()`. Easy to get wrong because `setup()` "feels" like the right place — but conceptually it runs *inside* the already-forked test subprocess, which is too late.
- "Run both X and Y alongside for parity" in CI is harder than it sounds: default GitHub Actions semantics skip subsequent steps after a failure. The shape that actually works is `continue-on-error: true` + `if: always()` + a final explicit gate. The pattern is reusable for any future "run two suites in parallel and fail if either fails" scenario.
- Wrapping-mode bats migration (one `@test` per legacy script) is an underrated 80/20 path. It gets bats parallelism + TAP output + named cases into CI today without re-implementing already-passing logic. Per-fixture splitting is genuine follow-up work that benefits from concern-by-concern review.

## Files Modified
- `.context/sessions/latest_summary.md` (this entry, in-place rewrite per the Copy rotation)
- `.context/sessions/2026-05-09_archived-273.md` (rotation archive of previous entry)
- `.context/state/coordination.md` (Recent History entry added retroactively for `pr-255-phase4b`)

## Open Items / Next
- **Issue #255 Phase 4c** (modularize `setup.sh` into `scripts/setup/{00-detect-repo,...}.sh` modules) is the next phase. Independent of Phase 4b — can start immediately.
- **Issue #255 Phase 4d** (slim `test.sh` and `setup.sh` to ≤200 lines + delete legacy `scripts/test-*.sh`) follows 4c. Note: slimming `test.sh` from 1,713 lines to ≤200 requires migrating most of its assertions out (likely into per-concern `.bats` files). That may exceed a single PR; flag for re-scoping when 4c is ready to merge.
- **Per-fixture bats splitting** (each `@test` becomes multiple `@test`s) is intentional follow-up beyond Phase 4. Worth its own sub-issue under epic #251 if the per-fixture cadence becomes valuable in CI debugging.
