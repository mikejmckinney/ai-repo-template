# Multi-Agent Coordination

> **Purpose**: How role-specialized AI agents work in parallel on this repo without stepping on each other. Read this once; reference the ownership map and coordination board during every session.

## The Roles

| Role       | File                                     | Writes code? |
|------------|------------------------------------------|--------------|
| Analyst    | `.github/agents/analyst.agent.md`        | No — research + analysis only |
| Architect  | `.github/agents/architect.agent.md`      | No — plans + ADRs only |
| Judge      | `.github/agents/judge.agent.md`          | No — procedural plan-gate + diff-gate |
| Critic     | `.github/agents/critic.agent.md`         | No — subjective-quality devil's advocate |
| PM         | `.github/agents/pm.agent.md`             | No — dispatch only |
| Frontend   | `.github/agents/frontend.agent.md`       | Yes — UI layer |
| Backend    | `.github/agents/backend.agent.md`        | Yes — server layer |
| QA         | `.github/agents/qa.agent.md`             | Yes — test code only |
| DevOps     | `.github/agents/devops.agent.md`         | Yes — CI, infra, scripts |
| Docs       | `.github/agents/docs.agent.md`           | Yes — docs + READMEs |

**Judge vs Critic**: Judge is procedural (criteria met? tests present? ownership respected?). Critic is subjective (is this actually good? hand-wavy reasoning? hidden assumptions? AI clichés?). Both run during plan-gate and diff-gate; Judge integrates Critic's notes into the final `DECISION`.

**Analyst vs Architect**: Analyst validates the "what" and "why" (problem definition, competitive landscape, impact scoring). Architect designs the "how" (solution plan, ADRs, file touch list). Analyst runs first; its output feeds Architect.

## The Three Coordination Files

1. **`.context/rules/agent_ownership.md`** — canonical "who owns what" table. Static; rarely changes.
2. **`.context/state/coordination.md`** — live claim board. Dynamic; updated every session.
3. **`.context/state/task_*.md`** — per-task detail files created by PM.

## How AI tools dispatch these roles

Both GitHub Copilot and Claude Code auto-delegate to a role when a user's request matches that role's frontmatter `description:` field, via two parallel registries:

| Loader | File | Schema |
|---|---|---|
| Copilot SDK custom-agent runtime | `.github/agents/<role>.agent.md` | Copilot schema (`read`, `write`, `search`, `fetch`, `githubRepo`, `usages`; `name`, `description`, `tools`, optional `target`/`user-invocable`/`disable-model-invocation`). Auto-dispatch matches the user's intent against each agent's `description:`. |
| Claude Code native subagents     | `.claude/agents/<role>.md`       | Claude Code schema (`Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `Task`, `WebFetch`; kebab-case `name`, `description`, `tools`, optional `model`). Auto-dispatch matches on `description:`; explicit dispatch via `Task(subagent_type: '<role>', ...)`. |

Both registries describe the **same 10 roles**. The `.claude/` files are short pointers that delegate to the canonical `.github/agents/<role>.agent.md` for responsibilities, Do/Don't lists, and output formats — so the detailed role definition lives in **one** place.

`test.sh` enforces that the `description:` frontmatter line is byte-identical between the two copies. Any drift between the Copilot-facing and Claude-Code-facing description is a hard failure — see the "Agent Mirror Sanity Checks" section of `test.sh`.

**Adding a new role** means adding *both* files (and updating `install.sh`'s `MULTIAGENT_FILES`, the `.context/rules/agent_ownership.md` table, and this guide). `test.sh` will fail loudly if any mirror is missing.

**A subagent can hand off to the next role** by calling `Task` itself (e.g. an architect subagent invokes `Task(subagent_type='judge', ...)` once its plan is ready). So the pipeline chains without the user having to switch modes manually — though the main orchestrator reading this guide and dispatching the first role is still how most sessions begin.

See `docs/decisions/adr-003-claude-code-subagent-registration.md` for the rationale behind the two-registry design.

## End-to-End Flow

```
  user request
       │
       ▼
  ┌──────────┐  analysis  ┌──────────┐   plan    ┌───────┐  notes  ┌──────────┐  approve  ┌────┐
  │ Analyst  │───────────▶│Architect │──────────▶│ Judge │◀────────│  Critic  │──────────▶│ PM │
  └────▲─────┘            └──────────┘           └───┬───┘         └──────────┘           └─┬──┘
       │                                             │                                      │ dispatch
       │                                             │ plan-gate                             ▼
       │                                             │                            ┌────────────────┐
       │                                             │                            │ Implementers   │
       │                                             │                            │ FE / BE / DO / │
       │                                             │                            │ Docs (parallel)│
       │                                             │                            └────────┬───────┘
       │                                             │                                     │
       │                                             │                                     ▼
       │                                             │                                  ┌────┐
       │                                             │                                  │ QA │  peer_review
       │                                             │                                  └──┬─┘
       │                                             │                                     │ coverage + green CI
       │                                             │                                     ▼
       │                                             │                               ┌──────────┐
       │                                             │                               │  Critic  │  peer_review
       │                                             │                               └────┬─────┘
       │                                             │                                    │ subjective notes
       │                                             │                                    ▼
       │                                             └──────────────▶ ┌───────┐  judge_review
       │                                                              │ Judge │
       │                                                              └───┬───┘
       │                                                                  │ APPROVE
       │                                                                  ▼
       │                                                                merge
       │                                                                  │
       │                                                                  ▼
       │                                                     ┌─────────────────────┐
       │                                                     │ stakeholder_review  │ (optional)
       │                                                     │ PM captures feedback│
       │                                                     └─────────┬───────────┘
       │                                                               │
       └───────────────────────────────────────────────────────────────┘
                    feedback loop (if assumptions changed)
```

1. **Analyst** validates the problem: needs analysis, competitive landscape, impact scoring, and (on iterations) re-validates assumptions against stakeholder feedback.
2. **Architect** turns validated findings into a plan + ADR.
3. **Judge** plan-gates (procedural) and integrates **Critic**'s subjective notes. Outputs APPROVE / REQUEST_CHANGES / BLOCK.
4. **PM** splits the approved plan into role-owned `task_*.md` files and records claims in `coordination.md` using the state machine below.
5. **Implementers** (Frontend / Backend / DevOps / Docs) work in parallel on separate branches, each inside their owned paths.
6. **QA** verifies coverage + CI green (`peer_review` state).
7. **Critic** reviews the diff for subjective quality (`peer_review` state).
8. **Judge** diff-gates with Critic's notes in hand (`judge_review` state).
9. Merge.
10. **Stakeholder review** (optional): PM decides whether to capture feedback. If triggered, findings feed back to Analyst (if assumptions changed) or Architect (if design feedback only) for the next iteration.

## Task State Machine

The canonical list of states, their gates, and the role that owns each transition is in `.context/state/coordination.md` → "Task States". In short: `backlog → planned → assigned → in_progress → peer_review → judge_review → approved → merged → [stakeholder_review]`, no skipping, any reviewer can kick a task back to `in_progress`. The `stakeholder_review` state is optional — PM decides whether a merged task enters the feedback loop or goes straight to done.

## Branch-Per-Role Model

Each implementer works on a branch named `feature/<role>-<task-id>`. For example:

```
feature/frontend-login-form
feature/backend-auth-api
feature/docs-auth-guide
```

This refines the "Use Git Branches" pattern in `docs/guides/agent-best-practices.md`. It greatly reduces the chance of merge conflicts — two agents editing different roles' files normally end up in disjoint directories on disjoint branches — but conflicts can still occur in shared or generated files (lockfiles, coordination board, shared rules), which is why the PM arbitration and Judge diff-gate layers below still matter.

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
**Role**: backend
**Session**: feature/backend-login
**Claimed At**: 2026-04-13T09:00:00Z
**Expected Duration**: 4h
**Paths**:
- src/api/auth/**
- migrations/005_sessions.sql
**Depends On**: none
**Blocks**: login-frontend, login-docs
**State**: in_progress

## Lock: login-frontend
**Role**: frontend
**Session**: feature/frontend-login
**Claimed At**: 2026-04-13T09:05:00Z
**Expected Duration**: 3h
**Paths**:
- src/components/LoginForm.tsx
- src/pages/login.tsx
**Depends On**: login-backend   (API contract must exist)
**Blocks**: none
**State**: planned

## Lock: login-docs
**Role**: docs
**Session**: feature/docs-login
**Claimed At**: 2026-04-13T09:10:00Z
**Expected Duration**: 1h
**Paths**:
- docs/guides/auth.md
**Depends On**: login-backend
**Blocks**: none
**State**: planned
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
- **Never mark a task complete with CI red** (see the "Testing requirements" section in `AGENTS.md`).
- **Always** release or hand-off your lock at end of session.
- **Always** add/update tests alongside behavior changes.

## Onboarding Checklist (Every Session)

1. `AGENTS.md` — universal rules.
2. `.context/00_INDEX.md` — where everything lives.
3. `.context/state/coordination.md` — what's in flight right now.
4. `.context/rules/agent_ownership.md` — what you may touch.
5. `.github/agents/<your-role>.agent.md` — your specific responsibilities.
6. Your assigned `.context/state/task_*.md`.
7. Report readiness (see the "Report readiness (The Report Step)" subsection in `docs/guides/agent-best-practices.md`).

## Optional: Scheduled Heartbeat

For teams that want an autonomous daily check on stuck work, the template ships `.github/workflows/agent-heartbeat.yml.template` — a scheduled GitHub Action (disabled by default) that surfaces stale locks in `coordination.md` and posts a summary via webhook or a GitHub issue.

**When to enable**: you have multiple agent sessions running against the repo over multiple days and want a safety net for forgotten locks or stuck tasks.

**When NOT to enable**: single-developer projects or short-lived repos — the workflow will just add noise. Most projects don't need it.

Enable steps are in the template file header.

**Need more than scheduled nudges?** For continuously-running autonomous agents (cron-driven, with a persistent task DB and webhook notifications), see the **OpenClaw** entry in `docs/guides/optional-skills.md`. It's an opt-in runtime, not vendored.

## Using Copilot Fleet (`/fleet`)

[Copilot Fleet](https://github.blog/ai-and-ml/github-copilot/run-multiple-agents-at-once-with-fleet-in-copilot-cli/) is a Copilot CLI slash command that dispatches multiple sub-agents in parallel — automating the "PM dispatches implementers" step described above.

**How it relates to this template**: Fleet's orchestrator can reference the 10 role agents in `.github/agents/` by name (e.g., `@backend.agent.md`). Each agent's `owned_paths` frontmatter tells Fleet which files that agent should touch, enabling clean file-boundary partitioning across sub-agents.

**When to use Fleet vs. manual dispatch**:
- **Fleet**: Multi-file features with clear file boundaries and natural parallelism. Fleet handles decomposition, dispatch, and polling automatically.
- **Manual** (PM + `coordination.md`): Complex cross-cutting work, long-running multi-day tasks, or situations needing explicit lock management and session handoff.

For prompt examples, best practices, and common pitfalls, see `.github/prompts/fleet.md`.

## See Also

- `.github/prompts/fleet.md` — fleet prompt template with worked examples.
- `docs/guides/agent-best-practices.md` — token limits, session handoff, secrets.
- `.github/agents/judge.agent.md` — plan-gate + diff-gate details.
- `.github/agents/critic.agent.md` — subjective-quality devil's advocate review.
- `.github/agents/analyst.agent.md` — needs analysis, market research, problem validation.
- `.context/state/feedback_template.md` — stakeholder feedback capture template.
- `.github/prompts/repo-onboarding.md` — full onboarding workflow.
