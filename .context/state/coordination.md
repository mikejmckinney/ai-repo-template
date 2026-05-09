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

## Lock: pr-262-make-closeout
<!-- managed-for-pr:pending -->
**Role**: devops
**Session**: feature/devops-262-make-closeout
**PR**: pending
**Claimed At**: 2026-05-09T00:08:00Z
**Expected Duration**: 1 session
**Paths**:
- Makefile
- scripts/closeout.sh
- scripts/test-closeout.sh
- test.sh
- AI_REPO_GUIDE.md
- scripts/README.md
- .context/sessions/latest_summary.md
- .context/sessions/2026-05-09_archived-266.md
- .context/state/_active.md
- .context/state/coordination.md
**Depends On**: none
**Blocks**: none
**State**: implementation
**Notes**: Implements `make closeout` enforcement target. Self-dogfoods on the chore close-out PR after merge.

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
