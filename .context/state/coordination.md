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
**Role**: <analyst|architect|frontend|backend|pm|qa|devops|docs|critic|judge>
**Session**: <branch name or agent session id>
**Claimed At**: <ISO-8601>
**Expected Duration**: <e.g., 30m, 2h>
**Paths**:
- <glob or file>
**Depends On**: <task-id or 'none'>
**Blocks**: <task-id or 'none'>
**State**: analyzing | backlog | planned | assigned | in_progress | peer_review | judge_review | approved | merged | stakeholder_review
```

## Active Locks

<!-- No active locks. Add new locks here using the template above. -->

## Recent History

<!-- Completed/released locks go here for 1-2 days, then PM prunes. -->

## Blocked / Waiting

<!-- Tasks that cannot proceed until a dependency clears. PM maintains this section. -->

## PM Notes

<!-- PM uses this area for dispatch rationale, sequencing decisions, and cross-role conflict resolutions. -->
