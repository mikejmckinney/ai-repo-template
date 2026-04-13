---
agent: agent
---

# Parallel Agents Setup

> **Purpose**: Prompt/runbook for decomposing a project into parallel workstreams across multiple AI agents with minimal conflicts.
>
> **When to use**: Before starting a multi-agent session. Use this prompt with a coordinator or architect agent to plan the work decomposition.

## Step 1: Classify Complexity

First, determine the appropriate agent count:

| Complexity | Characteristics | Agents |
|-----------|----------------|--------|
| **Trivial** | Single file, clear fix, no side effects | 1 solo agent |
| **Moderate** | Single feature, 2-5 files, limited scope | 1-2 agents + reviewer |
| **Complex** | Multi-component, cross-cutting concerns | 3-5 agents + adversary |
| **Critical** | Security, data migration, breaking changes | Full team with mandatory review |

## Step 2: Identify Natural Boundaries

Analyze the project for natural separation points:

1. **By feature**: User auth, payments, notifications, admin panel
2. **By layer**: Frontend, backend, database, infrastructure
3. **By component**: API gateway, worker service, web app, mobile app
4. **By concern**: Business logic, data access, presentation, testing

Prefer **feature-based (vertical) slicing** — an agent owns a full feature across layers. This minimizes cross-agent dependencies.

## Step 3: Identify Shared Interfaces

Before agents begin, identify files that multiple agents depend on:

- API contracts / OpenAPI specs
- Type definitions / interfaces / schemas
- Database migration files
- Shared utility functions
- Configuration files
- Router/route definitions

**These must be defined upfront by the architect agent or agreed upon by all agents before parallel work begins.**

## Step 4: Create Task Files

For each agent, create a task file using the template at `.context/state/task_template.md`:

```bash
# For a 3-agent project:
cp .context/state/task_template.md .context/state/task_frontend.md
cp .context/state/task_template.md .context/state/task_backend.md
cp .context/state/task_template.md .context/state/task_testing.md
```

Each task file MUST include:
- **Agent Role** from `.context/vision/architecture/agent-roles.md`
- **Owned Files/Dirs** — explicit list, no overlap with other agents
- **Shared Interfaces** — read-only files that multiple agents depend on
- **Dependencies** — which other tasks must finish first

## Step 5: Update `_active.md`

Update `.context/state/_active.md` to list all active tasks:

```markdown
## All Tasks

| Task | Agent Role | Status | File |
|------|-----------|--------|------|
| Frontend implementation | Frontend | In Progress | `task_frontend.md` |
| Backend API | Backend | In Progress | `task_backend.md` |
| Integration tests | Testing | Blocked (waiting on API) | `task_testing.md` |
```

## Step 6: Set Up Branches

Each agent should work on a dedicated branch:

```bash
# Agent 1
git checkout -b feature/frontend-auth

# Agent 2
git checkout -b feature/backend-auth

# Agent 3 (after 1 & 2 merge)
git checkout -b feature/integration-tests
```

## Step 7: Define the Merge Order

Plan the merge sequence to minimize conflicts:

1. Shared interfaces / contracts first (architect)
2. Backend implementation (depends on contracts)
3. Frontend implementation (depends on contracts)
4. Integration tests (depends on both)
5. Documentation and cleanup (after all merge)

## Coordination Protocol

### During Work
- Each agent updates its task file as progress is made
- Blockers are recorded in the task file under `Blockers / Open Questions`
- If an agent needs a file owned by another, add a coordination note

### Handoff
- When an agent completes a subtask, it updates the task file and pushes to its branch
- The reviewer agent is notified via PR
- After review and merge, dependent agents can rebase

### Conflict Resolution
See `.context/rules/domain_multi_agent.md` for conflict resolution rules.

---

## Example: 3-Agent Feature Implementation

**Project**: Add user authentication to a web app

### Agent 1: Backend (owns `src/api/`, `src/services/`, `src/models/`)
- Create user model and migration
- Implement auth endpoints (login, register, logout)
- Create auth middleware

### Agent 2: Frontend (owns `src/components/`, `src/pages/`)
- Create login/register forms
- Implement auth context/state management
- Add protected route wrappers

### Agent 3: Testing (owns `tests/`)
- Write unit tests for auth service
- Write integration tests for auth endpoints
- Write E2E tests for login flow

### Shared Interfaces (defined upfront):
- `src/types/auth.ts` — User type, auth request/response types
- `src/api/routes.ts` — Route definitions (read-only for frontend)

### Merge Order:
1. Shared types (`src/types/auth.ts`) — by Architect or Backend
2. Backend API — by Backend agent
3. Frontend UI — by Frontend agent (parallel with Backend after types merge)
4. Tests — by Testing agent (after Backend and Frontend merge)
