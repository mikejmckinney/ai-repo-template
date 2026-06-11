# Session: 2026-05-13 — feature/307-compliance-phase1 — pm/devops

**Status**: done
**Issue/PR**: [#307](https://github.com/mikejmckinney/ai-repo-template/issues/307) / [#308](https://github.com/mikejmckinney/ai-repo-template/pull/308) (merged at [`fa4a81b`](https://github.com/mikejmckinney/ai-repo-template/commit/fa4a81bde5c9753a3ffce4c12e8edadbe0e67615))
**Started**: 2026-05-13T13:39:45Z

## What Was Accomplished
- Merged [PR #308](https://github.com/mikejmckinney/ai-repo-template/pull/308) after resolving repeated bot feedback on ADR-026 compliance contracts; final head `1ca1836` squash-merged as [`fa4a81b`](https://github.com/mikejmckinney/ai-repo-template/commit/fa4a81bde5c9753a3ffce4c12e8edadbe0e67615).
- Recorded corrected live evidence: PR body and [issue #307 plan comment](https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4441585572) validate, [sandbox PR #11](https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/11) verified workflow behavior, and templated [sandbox issue #14](https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/14) / [PR #15](https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/15) verified the 15-minute reviewer artifact path; supplemental evidence is recorded at [PR #308 comment 4443685774](https://github.com/mikejmckinney/ai-repo-template/pull/308#issuecomment-4443685774).
- Posted a late ADR-025 [`agent-state:v1` closeout repair](https://github.com/mikejmckinney/ai-repo-template/pull/308#issuecomment-4443802692) on PR #308 after discovering the cadence had been missed earlier.

## What Shipped
- ADR-026 compliance contracts are now in the template: `plan_compliance`, `parent_compliance`, parsed `subagent_compliance`, canonical `role_contract_version`, validators, fixtures, template fields, role bootstrap guidance, and process-discipline checks.
- CI and bootstrap packaging now install/copy the compliance assets needed by fresh clones, and canonical role metadata is validated for duplicate names and filename/frontmatter drift.

## Harder Than Expected
- Local schema tests were not enough to prove the user outcome. The useful smoke was a templated sandbox issue, plan comment, and PR body fetched back from GitHub and validated live.
- ADR-025 live-state cadence was available but not operationalized during the long review loop; the closeout comment repaired final state only, not the missed historical cadence.

## Generalizable Lessons
- Treat "go ahead and fix it" as permission to orchestrate the repo process and dispatch role subagents; do not absorb role-owned work into the default agent for convenience.
- For compliance/process changes, include a live templated artifact smoke in addition to local validators and sandbox workflow checks.
- `agent-state:v1` is an active cadence obligation at start, pauses, compaction, handoffs, review waits, and closeout; PR reports and resolution comments are not substitutes.

## Files Modified
- `.context/sessions/latest_summary.md` - new durable retrospective for PR #308.
- `.context/sessions/2026-05-13_archived-297.md` - archived previous PR #297 retrospective via copy rotation.

## Open Items / Next
- [Issue #309](https://github.com/mikejmckinney/ai-repo-template/issues/309) tracks the markdownlint baseline cleanup deferred from PR #308.
- [Issue #307](https://github.com/mikejmckinney/ai-repo-template/issues/307) remained open at merge time; maintainer can close it if PR #308 satisfies the remaining umbrella scope.
