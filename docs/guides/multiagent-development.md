# Multi-Agent Development Guide

> **Purpose**: How to run multiple AI agents on the same codebase simultaneously without conflicts. Covers setup, coordination, and troubleshooting.
>
> **Prerequisites**: Read `.context/rules/domain_multiagent.md` for the rules. This guide explains how to apply them.

## When to Use Multi-Agent Development

Multi-agent setups add coordination overhead. They pay off when:

- The project has clearly separable concerns (frontend, backend, infrastructure)
- You're working on a time-sensitive feature with parallelizable components
- The codebase is large enough that a single agent's context window can't hold everything
- You need specialized expertise (e.g., security review + implementation simultaneously)

Don't use multi-agent when:

- The task is small enough for one agent
- The project has high coupling between components (everything touches everything)
- You haven't defined the project structure yet (define architecture first, parallelize second)

## Setup Workflow

### Step 1: Define Boundaries

Before spawning any agents, create or update `.context/vision/architecture/agent-boundaries.md` with your project's actual directory structure. Every directory should be assigned to exactly one agent role or marked as shared.

### Step 2: Create Task Files

For each agent you plan to run, create a task file in `.context/state/`:

```bash
cp .context/state/task_template.md .context/state/task_frontend.md
cp .context/state/task_template.md .context/state/task_backend.md
cp .context/state/task_template.md .context/state/task_infra.md
```

Fill in each task file with:
- The agent's role and scope
- Files owned (exclusive and shared)
- Acceptance criteria
- Dependencies on other agents

### Step 3: Define Shared Interfaces First

The Architect agent (or you, manually) should define all shared type definitions and API contracts before implementation agents start. This is the single most important step for preventing conflicts.

```
# Example: Define types before implementation
src/types/
├── api.ts         # API request/response shapes
├── models.ts      # Shared domain models
└── config.ts      # Configuration types
```

### Step 4: Launch Agents

How you launch agents depends on your tooling:

**Claude Code Agent Teams (recommended if using Claude Code):**
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
claude
# Then describe the team structure in natural language
```

**Manual terminals:**
```bash
# Terminal 1: Architect / PM
cd /your-project && claude
> Read .context/state/task_architect.md for your scope.

# Terminal 2: Frontend Agent
cd /your-project && claude
> Read .context/state/task_frontend.md for your scope.

# Terminal 3: Backend Agent
cd /your-project && claude
> Read .context/state/task_backend.md for your scope.
```

**Other orchestrators (Gas Town, Multiclaude, etc.):**
Follow their setup instructions, but point each agent to its task file for scope.

## Coordination Patterns

### Pattern 1: Interface-First (Recommended)

Best for: New features with frontend + backend components.

```
Timeline:
  1. Architect defines types in src/types/       [10 min]
  2. Frontend + Backend start in parallel         [parallel]
     - Frontend mocks API, builds against types
     - Backend implements API, returns types
  3. Integration test at API boundary             [10 min]
```

Why it works: Both agents code against the same type definitions. They never need to look at each other's code. Integration happens at the well-defined API boundary.

### Pattern 2: Vertical Slice

Best for: Independent features that don't share much.

```
Agent A: User registration (all layers)
  - src/components/auth/register/
  - src/api/auth/register.ts
  - src/services/auth/register.ts
  - tests for all of the above

Agent B: Dashboard analytics (all layers)
  - src/components/dashboard/
  - src/api/analytics/
  - src/services/analytics/
  - tests for all of the above
```

Why it works: Zero overlap. Each agent owns a complete feature. The only shared concern is potentially `package.json` for new dependencies.

### Pattern 3: Sequential Handoff

Best for: Work that must happen in order (e.g., database migration → API → UI).

```
Phase 1: Backend Agent creates migration + models
Phase 2: Backend Agent builds API endpoints
Phase 3: Frontend Agent builds UI against the API
```

This is effectively single-agent with handoff, but useful when the backend must be done before frontend can start.

## Handling Common Problems

### Problem: Two Agents Need the Same File

**Detection:** Check task files — both agents list the file under `Files Owned`.

**Resolution options:**
1. **Split the file.** Can the file be broken into two files that each agent owns separately? Often the answer is yes.
2. **Assign ownership.** One agent owns the file; the other requests changes via their task file.
3. **Sequential access.** Agent A finishes with the file first, commits, then Agent B modifies it.

### Problem: Circular Dependencies

**Detection:** Agent A's task says "blocked by Agent B" and Agent B's task says "blocked by Agent A."

**Resolution:** The Architect or PM agent must break the cycle:
1. Identify the minimal shared interface both agents need
2. Define that interface in the shared zone
3. Both agents code against the interface independently

### Problem: Merge Conflicts on Shared Files

**Prevention:**
- Use the shared-zone rules in `domain_multiagent.md`
- Make changes additive when possible (add lines, don't rewrite)
- Commit and push frequently

**Resolution:**
1. The agent whose task was created first has priority
2. The second agent rebases onto the first agent's changes
3. If conflicts are complex, the PM agent coordinates resolution

### Problem: Agent Drifting Outside Its Scope

**Detection:** An agent modifies files outside its declared zone.

**Resolution:**
1. Revert the out-of-scope changes
2. If the change is needed, create a task for the correct agent
3. If boundaries need updating, the Architect updates `agent-boundaries.md`

### Problem: Context Window Exhaustion

**Symptoms:** Agent produces lower-quality output, forgets earlier instructions, or starts contradicting itself.

**Resolution:**
1. The PM agent captures the current state in the task file
2. Start a fresh agent session pointed at the same task file
3. The new session reads the task file to resume

## Git Strategy for Multi-Agent Work

### Option A: Feature Branches (Simple)

Each agent works on a separate branch. PM agent merges them.

```
main
├── feature/frontend-auth      (Frontend Agent)
├── feature/backend-auth       (Backend Agent)
└── feature/infra-ci           (Infra Agent)
```

**Pros:** Clean separation. Easy to review per-agent.
**Cons:** Integration happens at merge time; conflicts discovered late.

### Option B: Trunk-Based with Short-Lived Branches (Recommended)

Agents work on short-lived branches and merge to `develop` frequently (multiple times per session).

```
develop  ←  all agents merge here frequently
├── frontend/login-form        (merged within 1 hour)
├── backend/auth-endpoint      (merged within 1 hour)
```

**Pros:** Conflicts caught early. Always-integrated codebase.
**Cons:** Requires more frequent coordination.

### Option C: Git Worktrees (Advanced)

For Claude Code Agent Teams or similar orchestrators that need multiple agents on different branches simultaneously:

```bash
git worktree add ../project-frontend feature/frontend
git worktree add ../project-backend feature/backend
```

Each agent operates in its own worktree directory, avoiding git lock conflicts entirely.

## Checklist: Before Starting Multi-Agent Work

- [ ] `.context/vision/architecture/agent-boundaries.md` is current
- [ ] Shared interfaces are defined in the types directory
- [ ] Each agent has a task file with scope and files owned
- [ ] `_active.md` reflects current priorities
- [ ] `.context/rules/domain_multiagent.md` is read by all agents
- [ ] Git strategy is chosen (branches, trunk-based, or worktrees)
- [ ] PM agent or human is available to resolve conflicts

## Checklist: Ending Multi-Agent Session

- [ ] All agents' task files are updated with current progress
- [ ] Shared-zone changes are documented in task files
- [ ] `sessions/latest_summary.md` captures decisions and failures
- [ ] All branches are pushed (no local-only work)
- [ ] Tests pass on the integration branch
