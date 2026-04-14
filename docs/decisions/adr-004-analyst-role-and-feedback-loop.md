# ADR-004: Add Analyst role and agile feedback loop

## Status

Accepted

## Date

2026-04-14

## Context

The template's multi-agent pipeline was effectively waterfall:

```
user request → Architect → Judge → PM → Implementers → QA → Critic → Judge → merge → done
```

Two problems motivated this change:

1. **No pre-Architect validation.** Architect assumes the "what" and "why" are settled. There is no structured step for needs analysis, competitive research, stakeholder identification, or impact scoring. Teams jump straight into solution design without validating the problem.

2. **No feedback loop.** Once something is merged, there is no mechanism for stakeholder input to cycle back into the next iteration. The pipeline terminates at `merged` with no path back to re-evaluate assumptions. This is a waterfall anti-pattern that prevents iterative improvement.

## Decision

We will make two coupled changes:

### A. Add a single "Analyst" agent role

A new research-only, no-code role called **Analyst** sits before Architect in the pipeline. Its core responsibilities are needs analysis, market/competitive research, target audience definition, and lightweight impact scoring. For scoring, the Analyst rates Reach, Severity, Feasibility, and Differentiation from 1–5 each, then calculates the composite as the average of the four scores. On subsequent iterations, the Analyst also re-validates assumptions against stakeholder feedback.

The Analyst owns `docs/research/**` for persisting analysis artifacts. To keep analyses comparable, Analyst outputs should record the four component scores and the composite average in a consistent format before handing off to Architect (for solution design) and PM (for task-level items discovered during analysis).

Files created:
- `.github/agents/analyst.agent.md` — canonical role definition (Copilot schema)
- `.claude/agents/analyst.md` — Claude Code mirror (pointer body)

### B. Add optional `stakeholder_review` state to the task state machine

A new state `stakeholder_review` sits between `merged` and the next iteration's `backlog`:

```
... → approved → merged → [stakeholder_review] → (task closed; new task_*.md entries in backlog)
```

PM decides whether a merged task enters stakeholder review or goes straight to done. `stakeholder_review` is terminal for the original task — once feedback is captured, the task file moves to Recent History. Any follow-up work becomes *new* `task_*.md` backlog entries, routed to Analyst (if assumptions changed) or Architect (if design feedback only). Small fixes and maintenance tasks typically skip this state.

A feedback template (`.context/state/feedback_template.md`) provides structure for capturing stakeholder reactions, requested changes, new requirements, and assumption changes.

## Options Considered

### Option 1: Single Analyst role + optional feedback state (chosen)
- **Pros**: Minimal additions (one role, one state). Analyst covers the full pre-design research spectrum without fragmenting responsibilities. Optional feedback state avoids ceremony overhead on small tasks.
- **Cons**: Analyst scope is broad (needs analysis + competitive research + impact scoring). May need to be split later if templates are used for very large teams.

### Option 2: Multiple research roles (Market Researcher, User Researcher, Business Analyst)
- **Pros**: Fine-grained specialization.
- **Cons**: Over-segmented for a template. Most teams using this template have 1–3 agent sessions, not dedicated research teams. Adds 3 role pairs (6 files) instead of 1 pair (2 files). Creates coordination overhead between the research roles themselves.

### Option 3: Mandatory feedback on every task
- **Pros**: Guarantees no task escapes review.
- **Cons**: Too heavy for small fixes, typo corrections, dependency bumps. Would add friction to the most common task types. PM should have discretion.

### Option 4: No structured feedback (status quo)
- **Pros**: No changes needed.
- **Cons**: The waterfall anti-pattern persists. Teams lose learnings between iterations. Assumptions are never re-validated.

## Consequences

### Positive

- The pipeline now supports iterative development: build → demo → learn → refine.
- Problem validation happens before solution design, reducing wasted Architect effort on ill-defined problems.
- Impact scoring provides a lightweight prioritization signal for PM.
- Stakeholder feedback has a structured capture format, enabling cognitive handoff between sessions.
- The feedback loop is optional, so lightweight tasks are not burdened.

### Negative

- Adding a new role increases the per-role maintenance burden (two files, plus updates to `install.sh`, `test.sh`, ownership table, coordination guide, `CLAUDE.md`, `AI_REPO_GUIDE.md`, `README.md`).
- The Analyst role's broad scope (needs + competitive + impact) may feel too wide for specialized teams. Future ADR may split it.
- `stakeholder_review` adds a state to the state machine, slightly increasing the learning curve for new contributors.

### Neutral

- Existing 9 roles are completely unaffected. This is purely additive.
- The `stakeholder_review` state is optional and skippable, so existing workflows continue to work unchanged.

## Implementation

- [x] Create `.github/agents/analyst.agent.md` and `.claude/agents/analyst.md`
- [x] Create `docs/research/.gitkeep`
- [x] Create `.context/state/feedback_template.md`
- [x] Update `.context/rules/agent_ownership.md` — add Analyst row
- [x] Update `.context/state/coordination.md` — add `stakeholder_review` state
- [x] Update `docs/guides/multi-agent-coordination.md` — roles, flow, dispatch
- [x] Update `CLAUDE.md` — add analyst to subagents list
- [x] Update `install.sh` — add analyst files to MULTIAGENT_FILES
- [x] Update `test.sh` — add analyst files to REQUIRED_FILES
- [x] Update `AI_REPO_GUIDE.md` — add Analyst to agent tables
- [x] Update `README.md` — add Analyst to agent tables
- [x] Update `docs/README.md` — add `docs/research/` to structure

## References

- ADR-003 — Claude Code subagent registration (pattern for adding new roles)
- `docs/guides/multi-agent-coordination.md` — pipeline documentation
- `.context/rules/agent_ownership.md` — ownership map
