<!-- Usage: cp task_template.md task_<your-task-id>.md -->

# Task: [Title]

> **Purpose**: Track progress on a specific task. Copy this template to create new tasks.
>
> **Note**: For session history and lessons learned, see `.context/sessions/latest_summary.md`

## Task Info

**ID**: [unique-id, e.g., feature_auth, bugfix_123]
**Title**: [Short descriptive title]
**Created**: [Date]
**Status**: [ ] Not Started / [ ] In Progress / [ ] Blocked / [ ] Complete
**Assigned**: [Agent/Developer, optional]

## Agent Role

<!-- If this task is part of a multi-agent workflow, specify the agent role -->
<!-- Options: Architect, Frontend Agent, Backend Agent, Infra Agent, PM Agent, or custom -->

[e.g., Frontend Agent — or "Single agent" if not using multi-agent workflow]

## Objective

<!-- One sentence: what are we trying to accomplish? -->

[No objective defined]

## Scope

<!-- Which directories/features does this agent own for this task? -->
<!-- Reference: .context/vision/architecture/agent-boundaries.md -->

[No scope defined]

## Files Owned

<!-- List files this agent will modify. Access levels: -->
<!-- Exclusive = only this agent modifies these files -->
<!-- Shared = coordinate with other agents before modifying (see domain_multiagent.md) -->

| File/Directory | Access Level |
|----------------|-------------|
| N/A | N/A |

## Progress

### Completed
- [ ] Nothing yet

### In Progress
- [ ] Nothing yet

### Remaining
- [ ] Define the task objective
- [ ] Break down into steps

## Dependencies on Other Agents

<!-- If multi-agent: list what you need from other agents -->
<!-- If single-agent: delete this section -->

| Agent | What I Need | Status |
|-------|-------------|--------|
| N/A | N/A | N/A |

## Shared Zone Changes

<!-- Document any changes you made to files in the shared zone -->
<!-- This helps other agents know what to rebase against -->

None.

## Blockers / Open Questions

<!-- List anything blocking progress -->

None.

## Verification

When this task is complete, verify by:

```bash
# Add verification commands here
./test.sh
```

## Context References

<!-- Point to relevant context files for this task -->

- Rules: `.context/rules/` (if modifying constrained areas)
- Multi-agent rules: `.context/rules/domain_multiagent.md`
- Agent boundaries: `.context/vision/architecture/agent-boundaries.md`
- Design: `.context/vision/` (if implementing UI/architecture)
- Last session: `.context/sessions/latest_summary.md`

---

## How to Use This Template

1. **Copy**: `cp task_template.md task_<your-id>.md`
2. **Fill in**: Task ID, Title, Objective, Scope, Files Owned, and Remaining items
3. **Multi-agent?** Fill in Agent Role, Files Owned, and Dependencies sections
4. **During work**: Move items through the progress sections; document shared-zone changes
5. **Complete**: Run verification, then delete or archive the task file
6. **End of session**: Update `sessions/latest_summary.md` with lessons learned
