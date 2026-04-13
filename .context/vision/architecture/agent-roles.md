# Agent Role Definitions

> **Purpose**: Standard role definitions for multi-agent project work. Use these when decomposing a project into parallel workstreams.

## Standard Roles

| Role | Responsibility | Typical Owned Files |
|------|---------------|-------------------|
| **Architect** | System design, API contracts, schema definitions, technology decisions | `docs/decisions/`, `.context/vision/architecture/`, interface/contract files |
| **Frontend** | UI components, styling, client-side logic, browser interactions | `src/components/`, `src/pages/`, `src/styles/`, `public/` |
| **Backend** | API endpoints, business logic, data access, server configuration | `src/api/`, `src/services/`, `src/models/`, `src/middleware/` |
| **Testing** | Test strategy, test implementation, coverage analysis, test infrastructure | `tests/`, `*.test.*`, `*.spec.*`, test config files |
| **DevOps** | CI/CD pipelines, deployment configs, infrastructure, monitoring | `.github/workflows/`, `config/`, `Dockerfile`, `docker-compose.yml` |
| **Reviewer / Adversary** | Code review, break-testing, quality gates, security review | *(read-only — reviews PRs, does not own files)* |
| **PM / Coordinator** | Task decomposition, prioritization, progress tracking, synthesis | `.context/state/`, `.context/roadmap.md` |

## When to Use Each Role

### Solo Agent (Simple Tasks)
- One agent handles everything
- No role assignment needed
- Use for: bug fixes, small features, documentation updates

### Small Team (2-3 Agents)
Recommended for moderate complexity:
- **Implementer** (1-2 agents): Owns the code changes
- **Reviewer** (1 agent): Reviews all PRs before merge

### Full Team (4+ Agents)
Recommended for complex, multi-component work:
- **Architect** (1): Defines contracts and interfaces upfront
- **Frontend** (1): Implements client-side
- **Backend** (1): Implements server-side
- **Testing** (1): Writes integration/E2E tests after interfaces are defined
- **Reviewer** (1): Adversarial review of all changes

### Coordinator Pattern (5+ Agents)
For large-scale work:
- **PM/Coordinator** (1): Does not write code; decomposes tasks, tracks progress, resolves blockers
- **Architect** (1): Designs system, defines interfaces
- **Implementers** (2-3): Feature-specific agents
- **Adversary** (1): Actively tries to break implementations

## Role Boundaries

### Architect
- **Does**: Creates ADRs, defines API schemas, chooses libraries, designs data models
- **Does not**: Implement features, write tests, configure CI

### Frontend
- **Does**: UI components, state management, routing, styling
- **Does not**: API logic, database queries, deployment configs
- **Coordinates with**: Backend (on API contracts), Testing (on component tests)

### Backend
- **Does**: API endpoints, business logic, database queries, auth
- **Does not**: UI components, CI/CD pipelines, test strategy
- **Coordinates with**: Frontend (on API contracts), Architect (on schema changes)

### Testing
- **Does**: Test plans, test implementation, coverage gaps, test infrastructure
- **Does not**: Feature implementation, deployment, architecture decisions
- **Coordinates with**: All implementers (on testable interfaces)

### DevOps
- **Does**: CI/CD, Docker, deployment scripts, monitoring
- **Does not**: Feature code, test implementation, architecture design
- **Coordinates with**: All agents (on build/deploy requirements)

### Reviewer / Adversary
- **Does**: Reviews PRs, identifies bugs, suggests improvements, tests edge cases
- **Does not**: Own any files, make direct code changes
- **Special rule**: Adversary should actively try to break the system — test edge cases, race conditions, invalid inputs

### PM / Coordinator
- **Does**: Decomposes projects, creates task files, tracks progress, resolves blockers
- **Does not**: Write code, make architecture decisions, review PRs
- **Special rule**: Never executes on hard problems directly; routes to specialist agents

## Task Assignment Template

When a coordinator assigns work, each task file should include:

```markdown
**Agent Role**: [Role from table above]
**Owned Files/Dirs**: [Explicit list of files this agent may modify]
**Shared Interfaces**: [Files multiple agents depend on — read-only by default]
**Dependencies**: [Other task IDs that must complete first]
```

See `.context/state/task_template.md` for the full template.
