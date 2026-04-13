# Agent Ownership Map

> **Purpose**: Canonical source of truth for "which agent role may edit which files." This file is consulted before any cross-role edit. When it conflicts with anything else, this file wins within its domain (see `AGENTS.md` truth hierarchy).

## How to Use

1. Before editing any file, find its path in the table below.
2. If your role owns that path, proceed.
3. If another role owns it, **stop** and escalate to the Project Manager (`.github/agents/pm.agent.md`). PM will either sequence the work or split the task.
4. Record your claim in `.context/state/coordination.md` before you start editing.

## Ownership Table

<!-- TEMPLATE_PLACEHOLDER: replace path globs with your project's real structure -->

| Role       | Owned path globs                                                     | May also edit (with PM claim) |
|------------|----------------------------------------------------------------------|-------------------------------|
| Architect  | `docs/decisions/**`, `.context/roadmap.md`, `.context/vision/architecture/**`, `.context/rules/**` (except `agent_ownership.md`) | nothing (plan-only) |
| Frontend   | `src/frontend/**`, `src/components/**`, `src/pages/**`, `src/styles/**`, `public/**`, colocated `*.test.*` / `*.spec.*` under those paths | UI-adjacent tests in `tests/ui/**` |
| Backend    | `src/backend/**`, `src/api/**`, `src/server/**`, `src/models/**`, `migrations/**`, `db/**`, colocated `*.test.*` / `*.spec.*` under those paths | API-adjacent tests in `tests/api/**` |
| PM         | AGENTS.md, .context/state/**, .context/rules/agent_ownership.md             | nothing (dispatch-only)       |
| QA         | `tests/**`, `e2e/**`                                                 | nothing                       |
| DevOps     | .github/workflows/**, config/**, install.sh, test.sh, scripts/**, .pre-commit-config.yaml.template, .cursorignore | nothing                       |
| Docs       | README.md, AI_REPO_GUIDE.md, CLAUDE.md, AGENT.md, docs/** (except docs/decisions/**)  | nothing                       |
| Judge      | nothing (review-only, `.github/agents/judge.agent.md`)               | nothing                       |
| Critic     | nothing (review-only, `.github/agents/critic.agent.md`)              | nothing                       |

### Colocated test files

Test files colocated under a source tree (e.g. `src/components/LoginForm.test.tsx`, `src/api/auth/login.spec.ts`) are owned by the role that owns the enclosing source path. QA ownership is limited to the dedicated test directories (`tests/**`, `e2e/**`) unless PM records a temporary shared-edit claim.

## Shared / Contested Files

These files require **PM coordination** regardless of role, because any role may need to touch them:

| File                              | Coordinated by | Notes                                            |
|-----------------------------------|----------------|--------------------------------------------------|
| `AGENTS.md`                       | PM             | Rules that bind every agent; rarely changes      |
| `CLAUDE.md` / `AGENT.md`          | Docs           | Tool-specific redirect pointers; edit in lockstep with `AGENTS.md` headers only |
| `.context/00_INDEX.md`            | PM             | Lazy-load map; append-only in most cases         |
| `.context/rules/agent_ownership.md` | PM           | This file. PM records cross-role decisions; Architect may propose via ADR |
| docs/decisions/**              | Architect      | Architect defines decisions; Docs polishes prose |
| .context/rules/** (except agent_ownership.md) | Architect  | Architect owns domain rules; PM records claims in coordination.md before edits |
| `.context/state/coordination.md`  | PM (writes), all (read-then-self-claim) | See lock protocol below |
| `test.sh`                         | DevOps         | Must be updated in lockstep with template structure changes |

## Lock Protocol (for `coordination.md`)

A role **self-claims** by appending a lock block; only PM edits or removes other roles' locks. The canonical lock format is defined in `.context/state/coordination.md` → "Lock Template" (with background in `docs/guides/agent-best-practices.md` → "Lock Before Working"):

```markdown
## Lock: <task-id>
**Role**: <frontend|backend|...>
**Session**: <agent session id or branch name>
**Claimed At**: <ISO-8601>
**Expected Duration**: <e.g., 30m, 2h>
**Paths**:
- <glob or file>
**Depends On**: <task-id or 'none'>
```

Expired locks (past their duration) may be released by PM after confirming the previous session ended.

## Cross-Role Edit Protocol

When a task genuinely requires edits across two roles' owned paths:

1. The implementing role **stops** before crossing the boundary.
2. PM evaluates whether to:
   - **Sequence**: one role completes, then the other.
   - **Split**: extract a new task owned by the other role.
   - **Share**: PM records a temporary shared-edit claim with both roles named and a tight duration.
3. PM updates `coordination.md` with the decision.
4. Judge verifies the cross-role edit during diff-gate.

## Default When Unsure

If ownership is ambiguous, escalate to PM. **Never guess** ownership silently — that is exactly how parallel agents produce merge conflicts.
