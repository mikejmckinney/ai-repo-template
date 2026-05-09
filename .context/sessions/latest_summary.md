<!-- TEMPLATE_PLACEHOLDER: In a real project, this file captures the current agent session's working log per the canonical template in `.context/sessions/README.md` § "Working-Log Template". One entry per agent-session, updated continuously at every wait-for-input pause (see AGENTS.md § "Session-state cadence"). Downstream projects should clear the example body during onboarding (see AGENTS.md → "Template detection" and `.github/prompts/repo-onboarding.md`). -->

# Session: 2026-05-09 — chore/closeout-272-state-cleanup — devops

**Status**: done
**Issue/PR**: #255 / #272 (closed) → this PR (chore close-out)
**Started**: 2026-05-09T03:30:00Z

## What Was Accomplished
- Merged PR #272 (`scripts/lib/{logging,assertions}.sh` extraction — issue #255 Phase 4a) at squash commit `76e48b7` after the pr-resolve-all loop converged with two consecutive clean rounds (R3 + R4). 4 review rounds total: R1 (5 distinct findings — `log_error` stderr regression, source-path example, set-u rationale, README convention, AI_REPO_GUIDE doc-sync), R2 (1 finding — counter env-poisoning regression), R3+R4 clean.
- Dispatched the chore close-out per ADR-007: rotated previous session entry (`devops-268` working log) to `.context/sessions/2026-05-09_archived-269.md` using the new Copy form (PR #271 / issue #270) instead of `git mv` rename. Per `git log --oneline --since=2026-05-08 -- .context/sessions/` (uncertain — first to dogfood the rotation-rule update; not independently verified across all post-#271 sessions).
- Replaced `latest_summary.md` body in place with this completion entry.
- No `_active.md` Task section to remove and no Active Lock to release for `feature/devops-255-phase4a-extract-helpers`: that branch did not appear in `## Active Locks` of `.context/state/coordination.md` at PR-272 merge time (uncertain — process gap rather than verified intent). The Recent History entry for `pr-255-phase4a` was added retroactively in this PR so the coordination board reflects the merged work; check 1b is satisfied by that `coordination.md` edit.

## What Shipped
- `scripts/lib/logging.sh` — color vars + `log_info`/`log_warn`/`log_error`/`log_step` (4 consumers source it).
- `scripts/lib/assertions.sh` — `PASS`/`FAIL`/`WARN` counters + `pass`/`fail`/`warn` (2 consumers source it).
- `scripts/lib/README.md` — layout, conventions, deferred-scope notes.
- Doc-sync: `AI_REPO_GUIDE.md` directory tree + file-table entries for the new libs.

## Harder Than Expected
- The "behavior-preserving" claim in the lib header was too strong: pre-extraction `log_error` was inconsistent across `setup.sh`/`db-reset.sh` (stdout) vs `sandbox-bootstrap.sh` (stderr). Three reviewers (codex, copilot, cursor) flagged the unification on the same line. Resolution: keep stderr (correct semantic per Unix convention), document the deliberate semantic shift in both the lib header and the README so future readers know it was intentional.
- The "set -u callers" rationale for `: "${PASS:=0}"` parameter expansion turned out to be wrong on two counts: (a) no consumer of `assertions.sh` actually runs under `set -u`, and (b) the parameter-expansion form lets inherited environment variables silently poison the verified-pass counter (codex P2). Reverted to unconditional `PASS=0 / FAIL=0 / WARN=0` to match the pre-extraction contract exactly.

## Generalizable Lessons
- When extracting "shared" helpers, audit the *callers* for inconsistencies first. If two scripts disagree on something subtle (stdout vs stderr, exit code, output format), the extraction is a forcing function — pick the right answer, document it as a deliberate semantic choice, don't pretend the extraction is a no-op.
- "Default unless set" idioms (`: "${VAR:=0}"`) are cargo-culted as the safe form, but for verified-pass counters they're the *unsafe* form: a parent shell exporting `FAIL=1` would silently flip a clean run to a failed run. Hard `=0` initialization is the right default for any counter that gates a downstream decision.
- Plan-as-comment scope deviations (skipping `github.sh`, deferring `closeout.sh` and the 14 `test-*.sh` files) are best documented in the PR body up front with rationale per item — that pre-empts review questions about "where's X from the plan?" and lets reviewers focus on the changed code instead.

## Files Modified
- `.context/sessions/latest_summary.md` (this entry, in-place rewrite per the new Copy rotation)
- `.context/sessions/2026-05-09_archived-269.md` (rotation archive of previous entry)
- `.context/state/coordination.md` (Recent History entry added retroactively for `pr-255-phase4a`)

## Open Items / Next
- **Issue #255 Phases 4b/4c/4d** still open (Bats migration, `setup.sh` modularization, slim entry points). Phase 4a is the foundation; the next phase to attempt is 4b (Bats) since it can run independently of 4c.
- **Process gap**: PR #272 was opened without a `coordination.md` Active Lock or `_active.md` Task section claim (uncertain — not verified against the full set of in-flight branches). Two precedents now (this PR's parent and PR #271). If a third occurs, file an issue to either tighten the gate or relax the requirement for small single-PR feature work.
