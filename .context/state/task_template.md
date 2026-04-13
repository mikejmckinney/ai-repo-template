<!-- TEMPLATE_PLACEHOLDER: Copy this file to create a new task -->
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

## Multi-Agent Coordination

<!-- Remove this section if working solo. Required when multiple agents work in parallel. -->
<!-- See .context/vision/architecture/agent-roles.md for role definitions. -->

**Agent Role**: [architect | frontend | backend | testing | devops | reviewer | adversary | PM | solo]  
**Owned Files/Dirs**: [List of files/directories this agent may modify]  
**Shared Interfaces**: [Files/APIs multiple agents depend on — read-only unless coordinated]  
**Dependencies**: [Other task IDs that must complete before this task can start]  
**Coordination Notes**: [How to communicate blockers — PR comments, state file updates, etc.]

## Objective

<!-- One sentence: what are we trying to accomplish? -->

[No objective defined]

## Progress

### Completed
- [ ] Nothing yet

### In Progress
- [ ] Nothing yet

### Remaining
- [ ] Define the task objective
- [ ] Break down into steps

## Checkpoint Verification

<!-- Verify after each subtask, not just at the end -->

| Checkpoint | Verification Command | Status |
|-----------|---------------------|--------|
| After setup | `./test.sh` | [ ] |
| After implementation | `npm test` (or equivalent) | [ ] |
| After cleanup | `npm run lint` (or equivalent) | [ ] |

## Files Being Modified

| File | Purpose of Changes |
|------|-------------------|
| N/A | N/A |

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
- Multi-agent rules: `.context/rules/domain_multi_agent.md` (if working in parallel)
- Orchestration rules: `.context/rules/domain_orchestration.md` (if coordinated work)
- Design: `.context/vision/` (if implementing UI/architecture)
- Agent roles: `.context/vision/architecture/agent-roles.md`
- Last session: `.context/sessions/latest_summary.md`

---

## How to Use This Template

1. **Copy**: `cp task_template.md task_<your-id>.md`
2. **Fill in**: Task ID, Title, Objective, and Remaining items
3. **During work**: Move items through the progress sections
4. **Complete**: Run verification, then delete or archive the task file
5. **End of session**: Update `sessions/latest_summary.md` with lessons learned
