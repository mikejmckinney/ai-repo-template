# Coordination Board

> **Purpose**: Live claim board for parallel multi-agent work. Every role reads this before editing and appends a lock before starting. The **Project Manager** agent is the authoritative editor beyond self-claims.

<!-- TEMPLATE_PLACEHOLDER: In a real project, this file tracks active work. Keep the structure below but clear the example locks. -->

## How to Use

1. **Before editing**: read this file and `rules/agent_ownership.md`. If any active lock overlaps your intended paths, stop and escalate to PM.
2. **Claim**: append a new lock block under "Active Locks" using the template below.
3. **Release**: when your task is done or handed off, move your block to "Recent History" with a result line. PM prunes history periodically.

## Task States

Every `task_*.md` file lives in exactly one of these states. Transitions are one-way (no skipping). The "Gate" column says what must be true to advance; the "Owner" column says which role performs the transition.

| State                | Gate to advance                                       | Owner of transition |
|----------------------|-------------------------------------------------------|---------------------|
| `analyzing`          | Analysis complete + Analyst handoff to Architect/PM   | Analyst             |
| `backlog`            | Architect plan exists + Judge plan-gate APPROVE       | PM                  |
| `planned`            | Role assigned + task file created + lock claimed      | PM                  |
| `assigned`           | Implementer starts work + sets `Status: in-progress`  | Implementer         |
| `in_progress`        | Implementation complete + tests added                 | Implementer         |
| `peer_review`        | QA coverage check + Critic subjective review          | QA / Critic         |
| `judge_review`       | Judge diff-gate APPROVE                               | Judge               |
| `approved`           | Branch merged to main                                 | PM                  |
| `merged`             | PM decides: done or stakeholder review                | PM                  |
| `stakeholder_review` | Feedback captured + PM routes to next iteration       | PM                  |

### Transition rules

- **No skipping**: a task in `in_progress` cannot jump to `judge_review` without passing through `peer_review`.
- **Reversible**: any reviewer (QA, Critic, Judge) may kick a task back to `in_progress` with `REQUEST_CHANGES`. Record the reason in the task file before the kickback.
- **Stakeholder review is optional**: after `merged`, PM decides whether to enter `stakeholder_review` or move the task directly to done (Recent History). Small fixes, dependency bumps, and maintenance tasks typically skip this state.
- **Stakeholder review is terminal**: `stakeholder_review` closes out the original task — once feedback is captured, the task file moves to Recent History. Any follow-up work becomes *new* `task_*.md` entries: routed to Analyst (entering `analyzing`) if assumptions need re-validation, or placed directly into `backlog` if the feedback is design-only and goes straight to Architect. New entries are created using `.context/state/feedback_template.md`.
- **Stuck detection**: any state other than `merged` or `stakeholder_review` held for > 24 hours is a "stuck" signal. PM should investigate on the next session or via the optional heartbeat workflow (`.github/workflows/agent-heartbeat.yml.template`).

## Lock Template

```markdown
## Lock: <task-id>
<!-- managed-for-pr:<NNN | pending> -->
**Role**: <analyst|architect|frontend|backend|pm|qa|devops|docs|critic|judge>
**Session**: <branch name or agent session id>
**PR**: <#MMM | pending | N/A>
**Claimed At**: <ISO-8601>
**Expected Duration**: <e.g., 30m, 2h>
**Paths**:
- <glob or file>
**Depends On**: <task-id or 'none'>
**Blocks**: <task-id or 'none'>
**State**: analyzing | backlog | planned | assigned | in_progress | peer_review | judge_review | approved | merged | stakeholder_review
```

> **`PR` field cadence (ADR-018 Amendment #1)**: write `pending` at lock-claim time (branch exists, PR not yet opened). PR numbers are only assigned by GitHub *after* the PR is created (whether by `gh pr create`, the API, or the web UI), so the `pending` → `#MMM` update is necessarily a *separate* commit from the one that triggered PR creation. Make the update at your next push after PR-open — typically the first review-feedback fix commit, or an explicit "claim-update" commit if no review feedback is forthcoming. Use `N/A` for branches that will not produce a PR (rare — local exploration, abandoned spikes). The field is optional on legacy locks predating this amendment; new locks must include it. The existing `<!-- managed-for-pr:NNN -->` HTML comment is automation's audit trail and remains the source of truth for the auto-updater; the `PR:` field is the human-readable mirror — keep the two values in sync when both are populated.

## Active Locks

## Lock: pr-256-design-patterns
<!-- managed-for-pr:290 -->
**Role**: docs
**Session**: feature/docs-256-design-patterns
**PR**: #290
**Claimed At**: 2026-05-09T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- docs/guides/design-patterns.md
- docs/guides/design-patterns-gof.md
- docs/guides/design-patterns-post-gof.md
- scripts/checks/030-docs-structure.sh
- .context/rules/repo_orchestration_patterns.md
- .context/state/_active.md
- .context/state/coordination.md
**Depends On**: none
**Blocks**: none
**State**: in_progress
**Notes**: Sub-issue #256 of parent epic #251. Path overlap with stale locks (test.sh / AGENTS.md / _active.md / coordination.md) treated as non-conflicting; this PR does not edit AGENTS.md or test.sh. Touches `.context/rules/repo_orchestration_patterns.md` (currently held by pr-252-orchestration-patterns lock above) only to replace 2 placeholder "(planned)" markers — non-conflicting micro-edit; will rebase if pr-252 lands first.

## Lock: pr-252-orchestration-patterns
<!-- managed-for-pr:259 -->
**Role**: architect
**Session**: feature/architect-252-orchestration-patterns-reference
**PR**: #259
**Claimed At**: 2026-05-08T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- .context/rules/repo_orchestration_patterns.md
- .context/rules/agent_ownership.md
- .context/rules/process_doc_maintenance.md
- docs/decisions/adr-020-orchestration-patterns-reference.md
- docs/decisions/README.md
- AGENTS.md
- AI_REPO_GUIDE.md
- install.sh
- .github/agents/critic.agent.md
- .github/agents/judge.agent.md
- .claude/agents/critic.md
- .claude/agents/judge.md
- test.sh
- .context/state/_active.md
- .context/state/coordination.md
- .context/sessions/latest_summary.md
**Depends On**: none
**Blocks**: none
**State**: in_progress
**Notes**: Sub-issue #252 of parent epic #251. Path overlap with stale locks (test.sh, AGENTS.md, critic/judge agent files, _active.md, coordination.md) treated as non-conflicting — the older locks reference merged or open-PR work whose diffs do not touch the new content here.

## Lock: pr-220-phase2
<!-- managed-for-pr:pending -->
**Role**: devops
**Session**: feature/devops-220-phase2
**Claimed At**: 2026-05-07T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- docs/decisions/adr-019-per-role-model-tiering.md
- docs/decisions/adr-003-claude-code-subagent-registration.md
- docs/decisions/README.md
- .claude/agents/*.md
- .github/agents/*.agent.md
- AGENTS.md
- .github/PLAN_TEMPLATE.md
- docs/guides/agent-pipeline.md
- test.sh
- .context/state/_active.md
- .context/state/coordination.md
- .context/sessions/latest_summary.md
**Depends On**: none
**Blocks**: none
**State**: in_progress
**Notes**: Pre-existing locks (pr-229-*, pr-228, pr-225) reference merged PRs and are stale; not pruning here (PM owns prune). Path overlap with stale locks (test.sh, AGENTS.md, .github/agents/critic.agent.md, .github/agents/judge.agent.md) treated as non-conflicting.

## Lock: pr-229-phase3
<!-- managed-for-pr:244 -->
**Role**: devops
**Session**: feature/devops-229-phase3-v2
**Claimed At**: 2026-05-06T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- .github/prompts/pre-push-review.md
- .github/prompts/README.md
- .github/agents/critic.agent.md
- .github/agents/devops.agent.md
- AGENTS.md
- AI_REPO_GUIDE.md
- docs/guides/agent-best-practices.md
- test.sh
- .context/state/_active.md
- .context/state/coordination.md
- .context/sessions/latest_summary.md
**Depends On**: pr-229-phase1 (merged), pr-229-phase1.5 (merged)
**Blocks**: none
**State**: in_progress

## Lock: pr-229-phase4
<!-- managed-for-pr:229 -->
**Role**: devops
**Session**: feature/devops-229-phase4
**Claimed At**: 2026-05-05T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- docs/decisions/adr-017-template-repo-pre-commit-default.md
- docs/decisions/README.md
- .pre-commit-config.yaml
- .pre-commit-config.yaml.template
- .github/prompts/pr-resolve-all.md
- .github/agents/judge.agent.md
- .cursor/BUGBOT.md
- .gemini/styleguide.md
- docs/guides/agent-pipeline.md
- test.sh
- AI_REPO_GUIDE.md
- README.md
- .context/state/_active.md
- .context/state/coordination.md
- .context/sessions/latest_summary.md
**Depends On**: pr-229-phase1 (merged)
**Blocks**: none
**State**: in_progress

## Lock: pr-229-phase1.5
<!-- managed-for-pr:229 -->
**Role**: devops
**Session**: copilot/phase-1.5-issue-229
**Claimed At**: 2026-05-09T00:00:00Z
**Expected Duration**: 1 session
**Paths**:
- scripts/lint-shell-conventions.sh
- scripts/test-verify-env.sh
- scripts/test-jq-filters.sh
- scripts/lib/jq/relay-cycle-count.jq
- scripts/lib/jq/fixtures/
- scripts/test-parallelism-report-parser.sh
- .github/workflows/lint-and-format.yml
- .github/workflows/agent-relay-reviews.yml
- .github/agents/judge.agent.md
- .cursor/BUGBOT.md
- .gemini/styleguide.md
- test.sh
- AI_REPO_GUIDE.md
- .context/sessions/latest_summary.md
- .context/state/_active.md
- .context/state/coordination.md
**Depends On**: pr-229-phase1 (merged)
**Blocks**: pr-229-phase3
**State**: in_progress

## Lock: pr-229-phase1
<!-- managed-for-pr:229 -->
**Role**: devops
**Session**: copilot/phase-1-issue-229
**Claimed At**: 2026-05-03T22:25:50Z
**Expected Duration**: 1 session
**Paths**:
- .github/workflows/lint-and-format.yml
- scripts/pr-iteration-stats.sh
- scripts/test-pr-iteration-stats.sh
- test.sh
- AI_REPO_GUIDE.md
- .context/sessions/latest_summary.md
- .context/state/_active.md
- .context/state/coordination.md
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Lock: pr-228
<!-- managed-for-pr:228 -->
**Role**: architect
**Session**: feature/architect-226-template-placeholders
**Claimed At**: 2026-05-03T17:49:57Z
**Expected Duration**: TBD
**Paths**:
- .context/sessions/latest_summary.md
- .context/state/_active.md
- .context/state/coordination.md
- .github/prompts/repo-onboarding.md
- AGENTS.md
- scripts/verify-env.sh
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Lock: pr-225
<!-- managed-for-pr:225 -->
**Role**: docs
**Session**: chore/coordination-cleanup
**Claimed At**: 2026-05-02T12:00:00Z
**Expected Duration**: TBD
**Paths**:
- .context/sessions/latest_summary.md
- .context/state/_active.md
- .context/state/coordination.md
- .github/workflows/agent-relay-reviews.yml
- .github/prompts/pr-resolve-all.md
**Depends On**: none
**Blocks**: none
**State**: in_progress

## Recent History

<!-- Completed/released locks go here for 1-2 days, then PM prunes. -->

## Lock: pr-281-expand-syntax-check
<!-- managed-for-pr:288 -->
**Role**: devops
**Session**: feature/devops-281-expand-syntax-check
**PR**: #288
**Claimed At**: 2026-05-09T15:15:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #288 (squash `e8f5f96`). Issue #281 — expanded `scripts/checks/055-script-syntax.sh` from 2 hardcoded `bash -n install.sh / test.sh` calls to a 5-glob set (`./*.sh scripts/*.sh scripts/checks/*.sh scripts/lib/*.sh scripts/setup/*.sh`) covering 53 .sh files. `scripts/tests/*.bats` intentionally excluded (bats syntax ≠ bash syntax; bats files exercised via the 070/075/080/085/090/115/140 modules). 5 review rounds: R1 (9 findings — duplicate-block own-goal flagged by 4 reviewers, plus nullglob-ordering, _active.md PR-pending, scripts/tests wording); R2 (1 finding — stale verify-step counts in _active.md); R3 (3 findings — provenance citations, missing `## Plan` section, suppressed bash -n stderr); R4 clean; R5 (1 finding — ADR-005 pre-flight, deferred as epic-followup of #255); R6+R7 clean. `bash test.sh` 353 → 404 (+51 new syntax assertions).

## Lock: pr-280-unwrap-bats-tests
<!-- managed-for-pr:287 -->
**Role**: devops
**Session**: feature/devops-280-unwrap-bats-tests
**PR**: #287
**Claimed At**: 2026-05-09T13:30:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #287 (squash `6946d04`). Issue #280 — un-wrapped 11 legacy `scripts/test-*.sh` shims by inlining each body into its matching `scripts/tests/*.bats` via a `_legacy_body()` shell function invoked through `bats run`; deleted the 11 .sh files (~2,919 LOC); created `scripts/lib/bats-helpers.sh` with `run_bats_check()` (warn-skip when bats not installed, mktemp template, extended-grep+wc-l for per-assertion count); refactored 7 `scripts/checks/*.sh` modules to use it; updated `AI_REPO_GUIDE.md`, `scripts/README.md`, `.context/rules/process_doc_maintenance.md`, `.context/rules/agent_ownership.md`, `.github/prompts/pre-push-review.md` to drop stale `scripts/test-*.sh` references. 5 review rounds: R1 (5 findings — `amt_passed` grep still on legacy `^PASS` pattern, bats not guarded by command -v, stale doc descriptions, obsolete bats comments); R2 (5 findings — `set -e` regression in closeout, harsh fail vs warn for missing bats, argument validation, mktemp template, redundant existence check); R3 (3 findings — doc-sync gap in 2 process docs, dead `for f in scripts/test-*.sh` glob in pre-push-review.md, per-assertion count regression solved via `>&3` trick + extended grep pattern); R4+R5 clean. 228 internal assertions across 11 .bats files now surface correctly.

## Lock: pr-255-phase4d
<!-- managed-for-pr:278 -->
**Role**: devops
**Session**: feature/devops-255-phase4d-slim-test
**PR**: #278
**Claimed At**: 2026-05-09T13:00:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #278 (squash `bc1393e`). Issue #255 Phase 4d — slimmed `test.sh` from 1,720-line monolith to 95-line orchestrator that sources `scripts/checks/[0-9][0-9][0-9]-*.sh` modules (3-digit zero-padded prefixes so lexical sort matches numeric order). 29 single-concern check modules + `scripts/checks/README.md`. Shape-preserving extraction; 365/1/0 baseline preserved. 7 review rounds: R1 (4 distinct findings — duplicate comment, doc inconsistency, $LF_FILE coupling, lexical glob misordering); R2 (continuity regex tighter than glob); R3 (awk on AGENTS.md unguarded under set -e); R4 (2 doc-sync followups from R1 renumber); R5 (schema-bypass-via-comments fixed, syntax-coverage scope expansion deferred to #281); R6 + R7 clean. Followups filed: #280 (un-wrap bats + delete legacy scripts/test-*.sh) and #281 (expand 055-script-syntax.sh coverage). Issue #255 stays open until #280 + #281 ship.

## Lock: pr-255-phase4c
<!-- managed-for-pr:276 -->
**Role**: devops
**Session**: feature/devops-255-phase4c-modularize-setup
**PR**: #276
**Claimed At**: 2026-05-09T05:00:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #276 (squash `ebf1fed`). Issue #255 Phase 4c — modularized scripts/setup.sh (508 lines) into a thin orchestrator + 8 phase modules under scripts/setup/<NN>-*.sh + scripts/setup/README.md. Shape-preserving extraction; behavior verified end-to-end against this repo. 5 review rounds (R1: 5 findings — 2 fixed, 3 deferred as pre-existing monolith bugs; R2: shfmt array-init fix; R3: codex P2 missing-phase manifest assertion; R4+R5 clean). Phase 4d still open.

## Lock: pr-255-phase4b
<!-- managed-for-pr:274 -->
**Role**: devops
**Session**: feature/devops-255-phase4b-bats-migration
**PR**: #274
**Claimed At**: 2026-05-09T04:00:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #274 (squash `409532b`). Issue #255 Phase 4b — bats infra in scripts/tests/, 11 .bats wrappers around legacy scripts/test-*.sh, ci-tests.yml install + run + combined-results gate. 3 review rounds (R1: 7 findings, R2+R3 clean).

## Lock: pr-255-phase4a
<!-- managed-for-pr:272 -->
**Role**: devops
**Session**: feature/devops-255-phase4a-extract-helpers
**PR**: #272
**Claimed At**: 2026-05-09T02:30:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #272 (squash `76e48b7`). Issue #255 Phase 4a — extracted shared `logging.sh` + `assertions.sh` helpers into `scripts/lib/`. 4 review rounds (R1: 5 findings, R2: 1 finding, R3+R4 clean). Phases 4b/4c/4d still open.

## Lock: pr-262
<!-- managed-for-pr:268 -->
**Role**: devops
**Session**: feature/devops-262-make-closeout
**PR**: #268
**Claimed At**: 2026-05-09T00:08:00Z
**State**: merged
**Result**: Merged 2026-05-09 as PR #268 (squash `66930f2b`). Adds `make closeout` six-check enforcement target with 6 fixture cases. 12 review rounds before convergence (R11+R12 clean).

## Lock: pr-261
<!-- managed-for-pr:261 -->
**Role**: architect
**Session**: claude/setup-context-verification-19clR
**PR**: #261
**Claimed At**: 2026-05-08T03:13:31Z
**State**: merged
**Result**: Merged 2026-05-08 as PR #261 (squash). Three-trigger cadence rewrite + ADR-018 Amendment #1 (PR field).

## Lock: pr-216
<!-- managed-for-pr:216 -->
**Role**: architect
**Session**: fix/206-pr-completion-criteria
**Claimed At**: 2026-04-28T22:54:03Z
**Expected Duration**: TBD
**Paths**:
- .context/state/_active.md
- .github/prompts/pr-resolve-all.md
- AGENTS.md
- test.sh
**Depends On**: none
**Blocks**: none
**State**: merged
**Result**: Merged 2026-04-29 as PR #216. Lock cleanup deferred; released 2026-05-02.

## Lock: pr-179
<!-- managed-for-pr:179 -->
**Role**: architect
**Session**: fix/177-phase4-fallback-on-push
**Claimed At**: 2026-04-25T02:53:28Z
**Expected Duration**: TBD
**Paths**:
- .github/workflows/agent-relay-reviews.yml
- docs/decisions/adr-008-phase4-default-and-copilot-fallback.md
**Depends On**: none
**Blocks**: none
**State**: merged
**Result**: Merged 2026-04-25 as PR #179. Lock cleanup deferred; released 2026-05-02. Triggered stale-lock alert #224.

## Blocked / Waiting

<!-- Tasks that cannot proceed until a dependency clears. PM maintains this section. -->

## PM Notes

<!-- PM uses this area for dispatch rationale, sequencing decisions, and cross-role conflict resolutions. -->

**Issue #220 Phase 2 (pre-registration)** — Not yet claimed; lock block omitted from Active Locks to avoid false stale-lock alerts before the branch exists. When work starts on `feature/architect-220-phase2`, add the lock block below to Active Locks and create `task_issue-220-phase2.md`.

```
## Lock: issue-220-phase2
**Role**: architect
**Session**: feature/architect-220-phase2
**Claimed At**: <ISO-8601 when branch opens>
**Expected Duration**: TBD
**Paths**:
- .claude/agents/*.md
- .github/agents/*.agent.md
- docs/decisions/adr-016*.md
- docs/decisions/adr-003-claude-code-subagent-registration.md
- test.sh
- AGENTS.md
**Depends On**: none
**Blocks**: none
**State**: backlog
```
