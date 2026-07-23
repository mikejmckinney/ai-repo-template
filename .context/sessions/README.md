# Session History

> **Purpose**: Preserve existing historical retrospective records without
> creating a second task-state surface.

## Current Contract

GitHub is the state machine for normal work:

- The issue body stores the task contract and implementation plan.
- The PR body stores implementation and verification evidence.
- The latest `agent-state:v1` comment stores mutable status, blockers, and next
  actions.
- Issue and PR history preserve completed task outcomes.

Do not create or maintain a rolling repository-local session summary. Promote
durable technical decisions to `docs/decisions/` and formal incident analysis
to `docs/postmortems/`.

## Contents

Existing date-stamped retrospective files are retained as historical evidence.
They are read only when investigating a specific past decision or incident and
are not onboarding prerequisites or current-state inputs.

`feedback_template.md` remains an optional starter for explicit stakeholder
feedback records. Create one only when a task specifically requires a durable
feedback artifact.
