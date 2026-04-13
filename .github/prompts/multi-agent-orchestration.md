---
agent: agent
---

# Multi-Agent Orchestration Runbook

> **Purpose**: Guide for setting up and managing a multi-agent workflow. Use this when you need multiple AI agents working on the same project simultaneously.
>
> **Prerequisites**: Read `.context/rules/domain_orchestration.md` for hard rules.

## When to Use Multi-Agent Orchestration

### Use Single Agent When:
- Task is straightforward (bug fix, small feature, documentation)
- Changes touch ≤ 5 files
- No cross-cutting concerns
- Time pressure doesn't justify coordination overhead

### Use Multi-Agent When:
- Task spans multiple system components (frontend + backend + infrastructure)
- Changes are large enough that sequential work would take too long
- Different expertise domains are needed (security review, UI/UX, database design)
- Quality is critical and adversarial review adds value

## Orchestration Patterns

### Pattern 1: Hub-and-Spoke (Recommended Default)

**When**: 3+ agents, moderate-to-complex work.

```
Coordinator decomposes → Specialists implement → Reviewer validates → Coordinator synthesizes
```

**Setup**:
1. Designate one agent as **Coordinator** (PM role)
2. Coordinator reads the full project context and creates task files
3. Each specialist agent reads only its task file + shared interfaces
4. Reviewer agent gets read access to all branches
5. Coordinator tracks progress in `_active.md`

**Coordinator responsibilities**:
- Create and maintain task files for each agent
- Define shared interfaces before implementation starts
- Resolve blockers and dependency conflicts
- Synthesize results and validate integration
- Never implement complex features directly

### Pattern 2: Pair Programming

**When**: 2 agents, moderate work, high quality requirements.

```
Implementer writes code → Reviewer challenges → Implementer revises → Both approve
```

**Setup**:
1. One agent implements on a feature branch
2. Second agent reviews the PR, focusing on:
   - Edge cases and error handling
   - Security implications
   - Performance concerns
   - Test coverage
3. Iterate until both agents approve

### Pattern 3: Pipeline

**When**: Work is inherently sequential (design → implement → test → deploy).

```
Architect → Backend → Frontend → Testing → DevOps
```

**Setup**:
1. Each agent completes its phase and documents outputs
2. Next agent picks up where the previous left off
3. Session handoff protocol applies at each transition
4. Each agent verifies the previous agent's work before building on it

### Pattern 4: Adversarial Review

**When**: Critical changes (security, data migration, public API, financial logic).

```
Implementer builds → Adversary tries to break → Implementer fixes → Adversary re-tests
```

**Setup**:
1. Implementer creates the solution
2. Adversary agent specifically tries to:
   - Find edge cases that break the logic
   - Identify security vulnerabilities
   - Test with invalid/malicious inputs
   - Find race conditions or concurrency issues
3. Findings are documented in the PR
4. Implementer addresses all findings
5. Adversary verifies fixes

## Setting Up a Multi-Agent Session

### Step 1: Read Context
```
Read: .context/00_INDEX.md
Read: .context/state/_active.md
Read: .context/roadmap.md (for current phase)
```

### Step 2: Classify and Decompose
Use `.github/prompts/parallel-agents.md` to:
- Classify the complexity
- Identify boundaries
- Define shared interfaces

### Step 3: Create Task Files
```bash
# Create a task file per agent
cp .context/state/task_template.md .context/state/task_<role>.md
```

Fill in all multi-agent coordination fields (see task template).

### Step 4: Establish Branches
```bash
# Main integration branch (optional)
git checkout -b feature/project-name

# Per-agent branches
git checkout -b feature/project-name-frontend
git checkout -b feature/project-name-backend
```

### Step 5: Define Quality Gates
Document in `_active.md`:
- What constitutes "done" for each task
- Required review process
- Integration test requirements
- Merge order and sequence

### Step 6: Execute
- Each agent works on its branch
- Updates its task file with progress
- Pushes changes and creates PRs
- Reviewer/Adversary reviews PRs
- Coordinator tracks overall progress

### Step 7: Integrate
- Merge in defined order (typically: contracts → backend → frontend → tests)
- Run full test suite after each merge
- Address integration issues immediately
- Coordinator verifies overall feature completeness

## Coordination via State Files

Agents communicate through `.context/state/` files:

| What to Communicate | Where |
|---------------------|-------|
| Task progress | Your `task_*.md` file |
| Blockers | Your `task_*.md` under `Blockers / Open Questions` |
| Priority changes | `_active.md` |
| Coordination requests | PR comments or `Coordination Notes` in task file |
| Completion | Update task status to "Complete" |

## Common Pitfalls

1. **Too many agents**: Coordination overhead > productivity gain. Start with 2-3 agents.
2. **Undefined interfaces**: Agents build incompatible components. Always define contracts first.
3. **No reviewer**: Bugs compound when agents don't review each other's work.
4. **File conflicts**: Two agents edit the same file. Enforce ownership rules strictly.
5. **Abandoned tasks**: An agent session ends without updating the task file. Always follow the session handoff protocol.

## References

- Agent roles: `.context/vision/architecture/agent-roles.md`
- Multi-agent rules: `.context/rules/domain_multi_agent.md`
- Orchestration rules: `.context/rules/domain_orchestration.md`
- Task template: `.context/state/task_template.md`
- Best practices: `docs/guides/agent-best-practices.md`
