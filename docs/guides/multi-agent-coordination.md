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
10. **Close-out** (required, immediately post-merge): the role that led the work appends a 3–5 line entry to `.context/sessions/latest_summary.md` per the close-out format in `.context/sessions/README.md` (Shipped / Harder than expected / Generalizable lesson / Follow-up). Active task scratchpads (`.context/state/task_<slug>.md`, `.context/state/handoff_<slug>.md`) are deleted or archived to `.context/sessions/`. PM verifies the close-out entry exists before flipping `coordination.md` from `merged → done` (see `.github/agents/pm.agent.md` §Responsibilities). Doc-sync companions per `.context/rules/process_doc_maintenance.md` should already be in the merged PR — Judge gates that at diff-time — but if any were deferred, they file as immediate follow-ups here.
11. **Stakeholder review** (optional): PM decides whether to capture feedback. If triggered, findings feed back to Analyst (if assumptions changed) or Architect (if design feedback only) for the next iteration.

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
5. **Judge diff-gate** — Judge blocks merges that violate ownership.
6. **Cross-PR overlap CI** (`agent-parallelism-report.yml`) — runs on every PR, posts a "Parallelism Report" comment listing every other open PR and classifying overlap as **hard** (same file), **soft** (same owned-path glob), or **none**. Comment-only, non-blocking; surfaces conflicts at PR-open time so reviewers/PM can sequence intentionally rather than discover them at merge. See ADR-009 and "Parallel Copilot Fan-Out" below.

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

## Parallel Copilot Fan-Out

When working multiple issues in parallel against this repo, the practical model is **cross-session parallelism**: separate agent sessions on separate issues, each producing a separate PR. The cross-session model is what `MAX_COPILOT_CONCURRENT` (default 3) and the path-ownership map are designed to gate. (For *in-session* role dispatch — i.e. one agent fanning out to roles within a single chat — see "Dispatch reality matrix" below; only Claude Code CLI does this today.)

### When two issues are parallel-safe

Two issues may be worked in parallel — by Copilot, Claude, or a human in any combination — when **all three** of the following hold:

1. Their owned-path globs in `agent_ownership.md` are **disjoint** (no overlap in either direction).
2. Neither lists the other in `depends_on` (transitively).
3. They do not both touch any file in the "Shared / Contested Files" table of `agent_ownership.md`.

When any of those fail, the work must be **sequenced** (one PR after the other) or **PM-arbitrated** (a temporary shared-edit claim recorded in `coordination.md` per `agent_ownership.md` §"Cross-Role Edit Protocol").

### How `MAX_COPILOT_CONCURRENT` interacts

`agent-assign-copilot.yml` only allows up to `MAX_COPILOT_CONCURRENT` (default 3) Copilot sessions to be in flight at any one time, counting open `copilot/*` head-branch PRs plus issues currently labeled `copilot:in-progress`. Beyond that cap, additional `copilot:ready` issues are swapped to `copilot:queued` and re-evaluated when a PR merges. This budget is independent of the parallel-safety check above — it caps wall-clock concurrency regardless of whether the issues happen to be path-disjoint.

`MAX_COPILOT_DAILY` (default 20) is a separate 24-hour assignment cap that gates the *issue-assignment* path only; it does not affect `@copilot` mentions on PRs or the `copilot-relay` workflow.

### Reading the Parallelism Report

Every PR receives a single upserted comment with the `<!-- parallelism-report -->` marker. The comment lists every other open PR and classifies the overlap with the current PR as:

- **hard** — the two PRs touch at least one identical file path. Sequence them (decide which merges first), or capture a PM shared-edit claim.
- **soft** — the two PRs touch different files but inside the same top-level owned-path glob. Likely fine; merge order may matter if one introduces a renaming or shared interface change.
- **none** — disjoint paths. No coordination needed.

The report is **comment-only and non-blocking**. Overlap is not intrinsically wrong — sequential merges resolve cleanly, and PM-arbitrated shared claims are legitimate. The report's purpose is to make the overlap visible at PR-open time. See ADR-009 for the rationale and the future hardening path.

## Subagent nesting

A "nested subagent" is a dispatched subagent that itself dispatches another subagent (e.g. PM dispatches Architect, Architect dispatches Judge). The VS Code subagents preview ([docs](https://code.visualstudio.com/docs/copilot/agents/subagents)) makes nesting newly easy in runtimes that implement the dispatch primitive.

**Default: nesting is disabled.** Allowed only when **all** of:

- **Parent role is non-implementer** — only PM, Architect, Analyst, Judge, or Critic may nest. Implementers (frontend, backend, devops, docs, qa) may not.
- **Child stays within parent's owned paths.** A nested child cannot expand the parent's blast radius.
- **Depth ≤ 2.** A subagent dispatching a subagent is the maximum.

Why conservative: nesting hides ownership escalation behind a `Task()` call. A frontend subagent that nests a docs subagent silently breaks the ownership map without appearing in `coordination.md`. The blast-radius caps keep nesting useful (PM → Architect → Judge for plan-gate review) while preventing the silent-escalation failure mode.

Full rationale: ADR-009 §Decision 4.

## Dispatch reality matrix

The role files in `.github/agents/**` and `.claude/agents/**` describe **the same 10 roles**, but only some runtimes actually fan out to them in-session. Treat this matrix as the contract:

| Runtime                                | Loads role files? | In-session role dispatch? | Notes |
|----------------------------------------|-------------------|---------------------------|-------|
| Claude Code CLI (local + `claude.yml`) | Yes (`.claude/agents/**`)  | **Yes** — native `Task(subagent_type: ...)`, including auto-dispatch on `description:` match | Only runtime where role fan-out is fully wired today. See ADR-003. |
| VS Code Copilot Chat                   | Public preview ([docs](https://code.visualstudio.com/docs/copilot/agents/subagents)) | **Unverified** — preview exists; tool-name compatibility, auto-dispatch behavior, and parallelism model not validated against `.github/agents/**` | Tracked in [#111](https://github.com/mikejmckinney/ai-repo-template/issues/111). |
| Cloud Copilot SWE agent (issue assignment / `@copilot follow`) | Reads `AGENTS.md` + `copilot-instructions.md` + the prompt file | **No** — runs as a single session per issue/PR; no dispatch primitive exposed | Multi-role behavior in this runtime is achieved by *separate* SWE-agent sessions on *separate* issues, gated by `MAX_COPILOT_CONCURRENT`. |
| Other (Cursor, Gemini, Aider, etc.)    | Reads `AGENTS.md` only | **No** — single orchestrator | The role files are documentation the orchestrator reads. |

Practical implication: when "parallel multi-agent execution" is discussed in this repo, it almost always means **cross-session parallelism** (separate PRs from separate sessions), not in-session `Task()`-style fan-out. Claude Code CLI is the exception. The cross-PR overlap CI (layer 6 of the conflict-avoidance hierarchy) is what makes the cross-session model safe at scale.

## Verifying overlap workflow changes

Any PR that modifies `.github/workflows/agent-parallelism-report.yml`, the parser in `scripts/test-parallelism-report-parser.sh`, or the role table in `.context/rules/agent_ownership.md` should run the live smoke test below before merge. Unit tests cover the parser logic but cannot exercise the GitHub API calls (PR list, file fetch, comment upsert) or real-world path classification.

**Setup.** Branch each scratch PR off the *workflow's source branch* (the PR being verified) and target it back at the same source branch. Targeting `main` defeats the test because PRs branched from `main` won't have the workflow file yet, and PRs targeting `main` will show every parent-branch file as a "diff" and trip every classification as `hard`. Targeting the source branch isolates each scratch PR to a single-file diff.

**The five checks.** Open three scratch PRs (label them `[SMOKE TEST — DO NOT MERGE]`):

1. **Hard overlap** — touch any one file the source branch also modifies. Expect `hard` with that file as evidence.
2. **Soft overlap** — touch a different file inside an owned-path glob the source branch also touches (e.g., the source branch edits `docs/guides/foo.md`, your scratch PR edits `docs/FAQ.md`; both fall under Docs `docs` prefix). Expect `soft` with the role + prefix as evidence.
3. **None** — touch a file outside every prefix the source branch hits (e.g., `config/README.md` when the source branch only touches `docs/`, `scripts/`, `.context/rules/`). Expect `none`.
4. **Upsert idempotency** — push a second commit to the hard-overlap scratch PR. Capture the parallelism-report comment ID before and after; it must be unchanged (the workflow edits, never duplicates).
5. **Fail-soft on broken table** — on the same scratch PR, mangle the role names in `agent_ownership.md` so the parser regex no longer matches (e.g., `s/^| Analyst /| ZZAnalyst/`). Push. The next report must include the `> ⚠️ Parser warning:` block AND must still detect hard overlaps (which don't depend on the prefix table).

**Cleanup.** Close all scratch PRs unmerged and delete their branches. Record the run in the PR description (5 ✅/❌ rows is enough — no separate doc needed).

When to skip: trivial doc-only edits to comments inside the workflow file, or test-only edits that the unit tests already cover. When in doubt, run it — three scratch PRs cost about ten minutes of CI and are reversible.

## See Also

- `docs/guides/agent-best-practices.md` — token limits, session handoff, secrets.
- `.github/agents/judge.agent.md` — plan-gate + diff-gate details.
- `.github/agents/critic.agent.md` — subjective-quality devil's advocate review.
- `.github/agents/analyst.agent.md` — needs analysis, market research, problem validation.
- `.context/state/feedback_template.md` — stakeholder feedback capture template.
- `.github/prompts/repo-onboarding.md` — full onboarding workflow.
