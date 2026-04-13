# Multi-Agent Coordination

> **Purpose**: How role-specialized AI agents work in parallel on this repo without stepping on each other. Read this once; reference the ownership map and coordination board during every session.

## The Roles

| Role       | File                                     | Writes code? |
|------------|------------------------------------------|--------------|
| Architect  | `.github/agents/architect.agent.md`      | No — plans + ADRs only |
| Judge      | `.github/agents/judge.agent.md`          | No — plan-gate + diff-gate |
| PM         | `.github/agents/pm.agent.md`             | No — dispatch only |
| Frontend   | `.github/agents/frontend.agent.md`       | Yes — UI layer |
| Backend    | `.github/agents/backend.agent.md`        | Yes — server layer |
| QA         | `.github/agents/qa.agent.md`             | Yes — test code only |
| DevOps     | `.github/agents/devops.agent.md`         | Yes — CI, infra, scripts |
| Docs       | `.github/agents/docs.agent.md`           | Yes — docs + READMEs |

## The Three Coordination Files

1. **`.context/rules/agent_ownership.md`** — canonical "who owns what" table. Static; rarely changes.
2. **`.context/state/coordination.md`** — live claim board. Dynamic; updated every session.
3. **`.context/state/task_*.md`** — per-task detail files created by PM.

## End-to-End Flow

```
  user request
       │
       ▼
  ┌──────────┐   plan    ┌───────┐  approve   ┌────┐  dispatch  ┌────────────────┐
  │Architect │──────────▶│ Judge │───────────▶│ PM │───────────▶│ Implementers   │
  └──────────┘           └───────┘            └────┘            │ FE / BE / DO / │
                                                                │ Docs (parallel)│
                                                                └────────┬───────┘
                                                                         │
                                                                         ▼
                                                                      ┌────┐
                                                                      │ QA │
                                                                      └──┬─┘
                                                                         │ green CI
                                                                         ▼
                                                                      ┌───────┐
                                                                      │ Judge │
                                                                      └───┬───┘
                                                                          │ approve
                                                                          ▼
                                                                        merge
```

1. **Architect** turns a request into a plan + ADR.
2. **Judge** plan-gates: APPROVE / REQUEST_CHANGES / BLOCK.
3. **PM** splits the approved plan into role-owned `task_*.md` files and records claims in `coordination.md`.
4. **Implementers** (Frontend / Backend / DevOps / Docs) work in parallel on separate branches, each inside their owned paths.
5. **QA** verifies coverage + CI green.
6. **Judge** diff-gates.
7. Merge.

## Branch-Per-Role Model

Each implementer works on a branch named `feature/<role>-<task-id>`. For example:

```
feature/frontend-login-form
feature/backend-auth-api
feature/docs-auth-guide
```

This is a refinement of the pattern already in `docs/guides/agent-best-practices.md:147-158`. It guarantees that two agents editing different roles' files cannot produce a merge conflict — their changes are in disjoint directories on disjoint branches.

## Conflict-Avoidance Hierarchy

Conflicts are prevented by layered defenses. Earlier layers are cheaper.

1. **Path ownership** (agent_ownership.md) — two roles physically cannot share a file by default.
2. **Live locks** (coordination.md) — within a role's owned paths, claims prevent two sessions of the same role from overlapping.
3. **Branch isolation** — each role works on its own branch, so unrelated changes never touch.
4. **PM arbitration** — when a task genuinely needs a cross-role edit, PM decides: sequence, split, or shared claim.
5. **Judge diff-gate** — the last check: Judge blocks merges that violate ownership.

## Worked Example: Two Agents in Parallel

**Scenario**: Add a login form (UI) + auth endpoint (API). Both need to exist before the feature works.

### Step 1 — Architect plans

```
PLAN: Add login

PHASES:
1. Backend owns POST /auth/login → files: src/api/auth/**, migrations/005_sessions.sql
2. Frontend owns LoginForm → files: src/components/LoginForm.tsx, src/pages/login.tsx
3. Docs owns auth guide → files: docs/guides/auth.md
```

### Step 2 — Judge plan-gate

`DECISION: APPROVE`

### Step 3 — PM dispatches

PM creates three task files and three locks:

```markdown
## Lock: login-backend
Role: backend
Session: feature/backend-login
Paths: src/api/auth/**, migrations/005_sessions.sql

## Lock: login-frontend
Role: frontend
Session: feature/frontend-login
Paths: src/components/LoginForm.tsx, src/pages/login.tsx
Depends On: login-backend  (API contract must exist)

## Lock: login-docs
Role: docs
Session: feature/docs-login
Paths: docs/guides/auth.md
Depends On: login-backend
```

### Step 4 — Parallel execution

- Backend agent starts immediately on its branch.
- Frontend agent waits for Backend's API contract commit, then starts.
- Docs agent waits for Backend, then starts.
- All three branches have **zero shared files**, so no merge conflicts.

### Step 5 — QA + Judge + merge

Each branch goes through QA → Judge → merge independently.

## Rules That Prevent Disasters

- **Never edit outside your owned paths without a PM claim.** This is the single most important rule.
- **Never silently resolve** a lock conflict — escalate to PM.
- **Never mark a task complete with CI red** (see `AGENTS.md:41-44`).
- **Always** release or hand-off your lock at end of session.
- **Always** add/update tests alongside behavior changes.

## Onboarding Checklist (Every Session)

1. `AGENTS.md` — universal rules.
2. `.context/00_INDEX.md` — where everything lives.
3. `.context/state/coordination.md` — what's in flight right now.
4. `.context/rules/agent_ownership.md` — what you may touch.
5. `.github/agents/<your-role>.agent.md` — your specific responsibilities.
6. Your assigned `.context/state/task_*.md`.
7. Report readiness (see `agent-best-practices.md:236-279`).

## See Also

- `docs/guides/agent-best-practices.md` — token limits, session handoff, secrets.
- `.github/agents/judge.agent.md` — plan-gate + diff-gate details.
- `.github/prompts/repo-onboarding.md` — full onboarding workflow.
