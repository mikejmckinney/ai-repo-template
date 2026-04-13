# Domain: Multi-Agent Collaboration

> **Purpose**: Hard rules for when multiple AI agents work on the same project simultaneously. These prevent merge conflicts, duplicated work, and coordination failures.

## Hard Rules (Never Violate)

1. **File ownership is mandatory**: Every task file (`task_*.md`) must declare which files/directories the assigned agent may modify under `Owned Files/Dirs`. An agent must not modify files outside its declared ownership.

2. **No overlapping file modifications**: Two agents must not modify the same file concurrently. If overlap is unavoidable, one agent must wait for the other to complete and merge first.

3. **Shared interfaces are read-only by default**: Files listed under `Shared Interfaces` in any task file are read-only for all agents unless a coordination note explicitly grants write access to one agent at a time.

4. **Read `_active.md` before starting work**: Every agent must read `.context/state/_active.md` and all existing `task_*.md` files before beginning work, to understand who else is working and on what.

5. **Claim before working**: An agent must update its task file status to "In Progress" before making any code changes. This serves as a lock signal to other agents.

6. **Interface-first for parallel work**: When multiple agents will implement components that interact, shared interfaces (API contracts, type definitions, schemas) must be defined and agreed upon *before* parallel implementation begins.

7. **One branch per agent**: Each agent should work on its own git branch. Never push directly to `main` during parallel work.

## Soft Rules (Prefer Unless Justified)

1. **Prefer vertical slicing over horizontal**: Assign agents complete features (frontend + backend + tests for feature X) rather than horizontal layers (all frontend, all backend) to minimize cross-agent dependencies.

2. **Keep shared interfaces minimal**: The fewer files that appear in multiple agents' `Shared Interfaces`, the less coordination overhead.

3. **Use adversarial review**: At least one agent should be assigned a reviewer/adversary role to review other agents' PRs before merge.

4. **Communicate via state files, not code comments**: Blockers, questions, and coordination notes belong in `.context/state/` files, not scattered in code comments.

## Agent Role Assignments

See `.context/vision/architecture/agent-roles.md` for standard role definitions.

When assigning agents to tasks:
- Match the agent role to the task domain
- Ensure no two agents share the same owned files
- List all dependencies between tasks explicitly
- Designate at least one reviewer if 3+ agents are active

## Conflict Resolution

If two agents need the same file:
1. Check if the file can be split (e.g., separate route files per feature)
2. If not, assign it to one agent and make it read-only for others
3. The second agent should list it as a `Dependency` and wait
4. Use PR-based handoff: first agent merges, second agent rebases

## Rationale

Multi-agent work without ownership boundaries leads to merge conflicts, duplicated effort, and inconsistent implementations. These rules enforce the coordination overhead that humans naturally handle through communication.

## Exceptions Process

If a rule must be violated (e.g., emergency hotfix to a file owned by another agent):
1. Document the exception in the task file under `Coordination Notes`
2. Notify via PR comment tagging the owning agent's task
3. Resolve any resulting conflicts immediately
