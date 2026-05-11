# Agent Ownership Map

> **Purpose**: Canonical source of truth for "which agent role may edit which files." This file is consulted before any cross-role edit. When it conflicts with anything else, this file wins within its domain (see `AGENTS.md` truth hierarchy).

## How to Use

1. Before editing any file, find its path in the table below.
2. If your role owns that path, proceed.
3. If another role owns it, **stop** and escalate to the Project Manager (`.agents/pm.md`). PM will either sequence the work or split the task.
4. Record your claim in `.context/state/coordination.md` before you start editing.

## Ownership Table

<!--
NOTE: This table is both (a) ai-repo-template's own ownership map AND
(b) the example for projects derived from this template. When deriving
this template for a new project:
- KEEP every template-governance role row (Analyst / Architect / PM /
  QA / DevOps / Docs / Judge / Critic) and the `docs/**`, `.context/**`,
  `.github/**`, `scripts/**`, `config/**`, `install.sh`, `test.sh` globs
  on the DevOps / Docs / Architect / PM rows — they are load-bearing
  for the multi-agent workflow.
- ADJUST the project-specific globs to match your source tree. The
  Frontend / Backend / QA rows below are shown with illustrative globs:
  keep the role rows themselves (they are load-bearing), but replace
  the path globs (`src/frontend/**`, `src/backend/**`, `tests/**`,
  `e2e/**`, etc.) with your project's real paths once a source tree
  exists.
- DO NOT delete this file or wholesale replace the table — `test.sh`,
  Judge, the parallelism-report parser, and every role consult it.
-->

| Role       | Owned path globs                                                     | May also edit (with PM claim) |
|------------|----------------------------------------------------------------------|-------------------------------|
| Analyst    | `docs/research/**`                                                   | nothing (research-only)       |
| Architect  | `AGENTS.md`, `.agents/**`, `docs/decisions/**`, `docs/postmortems/**`, `.context/roadmap.md`, `.context/vision/architecture/**`, `.context/rules/**` (except `agent_ownership.md`) | nothing (plan-only) |
| Frontend   | `src/frontend/**`, `src/components/**`, `src/pages/**`, `src/styles/**`, `public/**`, colocated `*.test.*` / `*.spec.*` under those paths | UI-adjacent tests in `tests/ui/**` |
| Backend    | `src/backend/**`, `src/api/**`, `src/server/**`, `src/models/**`, `migrations/**`, `db/**`, colocated `*.test.*` / `*.spec.*` under those paths | API-adjacent tests in `tests/api/**` |
| PM         | `.context/state/**`, `.context/rules/agent_ownership.md` (see §"PM ownership carve-out" below) | nothing (dispatch-only)       |
| QA         | `tests/**`, `e2e/**`                                                 | nothing                       |
| DevOps     | .github/workflows/**, config/**, install.sh, test.sh, scripts/**, .pre-commit-config.yaml.template, .cursorignore | nothing                       |
| Docs       | README.md, AI_REPO_GUIDE.md, CLAUDE.md, AGENT.md, docs/** (except docs/decisions/**, docs/postmortems/**, docs/research/**)  | nothing                       |
| Judge      | nothing (review-only, `.agents/judge.md`)                            | nothing                       |
| Critic     | nothing (review-only, `.agents/critic.md`)                           | nothing                       |

### PM ownership carve-out (`.context/state/**`)

PM owns `.context/state/**` for cross-role coordination, but **every agent self-writes** the parts of state files that describe their own work:

- Each agent adds and removes its own `## Task: <branch>` section in `.context/state/_active.md` per the cadence rules.
- Each agent adds its own lock to `.context/state/coordination.md` Active Locks at task start, and moves it to Recent History at genuine task close-out.

PM is the **backstop** (catches forgotten cleanup via the daily reconciliation pass at `.github/workflows/agent-coordination-sync.yml`) and the **only role that may edit another agent's section**, prune Recent History, or arbitrate cross-role conflicts. See `.context/state/README.md` §"Cadence" for the agent-self / PM-backstop split.

### Colocated test files

Test files colocated under a source tree (e.g. `src/components/LoginForm.test.tsx`, `src/api/auth/login.spec.ts`) are owned by the role that owns the enclosing source path. QA ownership is limited to the dedicated test directories (`tests/**`, `e2e/**`) unless PM records a temporary shared-edit claim.

## Shared / Contested Files

These files require **PM coordination** regardless of role, because any role may need to touch them:

| File                              | Coordinated by | Notes                                            |
|-----------------------------------|----------------|--------------------------------------------------|
| `CLAUDE.md` / `AGENT.md`          | Docs           | Tool-specific redirect pointers; edit in lockstep with `AGENTS.md` headers only (see ADR-002) |
| `.context/00_INDEX.md`            | PM             | Lazy-load map; append-only in most cases         |
| `.context/rules/agent_ownership.md` | PM           | This file. PM records cross-role decisions; Architect may propose via ADR |
| docs/decisions/**              | Architect      | Architect defines decisions; Docs polishes prose |
| docs/postmortems/**            | Architect      | Architect ratifies the "What generalizes" verdict; anyone may draft, but a postmortem that proposes a rule/ADR change requires Architect sign-off |
| .context/rules/** (except agent_ownership.md) | Architect  | Architect owns domain rules; PM records claims in coordination.md before edits |
| `.context/rules/repo_orchestration_patterns.md` | Architect | Orchestration patterns + anti-patterns reference (`P1`–`P8`, `AP1`–`AP8`) cited by Critic and Judge at diff-gate. Block conditions are a Critic/Judge contract; changes require an ADR. See ADR-020. (Covered by `.context/rules/**` row above; listed explicitly for citation clarity.) |
| `.context/state/coordination.md`  | PM (writes), all (read-then-self-claim) | See lock protocol below |
| `test.sh`                         | DevOps         | Must be updated in lockstep with template structure changes |
| `.github/agents/**` / `.claude/agents/**` | Architect | Role definitions; changes require an ADR, must update both mirrors in lockstep, and `test.sh` enforces `description:` parity between them. See `docs/decisions/adr-003-claude-code-subagent-registration.md`. |
| `.github/agents/consensus-candidate-*.agent.md` | Architect | Multi-model consensus dry-run candidate planners (Copilot-only). Pinned to one Copilot model each via `model:` frontmatter so `.github/prompts/multi-model-consensus-plan.md` can fan three planning passes across distinct vendors via `runSubagent` (which has no `model` parameter). Intentionally not mirrored to `.claude/agents/` or `.agents/`; `scripts/checks/050-agent-mirror.sh` exempts the `consensus-candidate-*` name prefix. Promote to N-way once a third platform with a meaningfully different model catalog (e.g., Cursor) is added. See issue #295 / PR #297. |
| `.github/workflows/agent-parallelism-report.yml` | DevOps | Cross-PR overlap detector; parses this ownership table to classify overlaps. Format-changing PRs must keep the table parser-friendly (covered by the live-format assertion in `scripts/tests/parallelism-report-parser.bats` and `test.sh`). See ADR-009. |
| `.github/workflows/auto-rebase-on-merge.yml` | DevOps | Post-merge auto-rebase for soft-overlap PRs and advisory-comment for hard-overlap PRs. Reuses `classify_overlap` from `scripts/multi-dispatch-safety.sh`. Decision logic lives in `scripts/auto-rebase-overlapping.sh` (unit-tested via `scripts/tests/auto-rebase-overlapping.bats`). See ADR-010. |
| `scripts/auto-rebase-overlapping.sh` | DevOps | Pure-bash library backing the auto-rebase workflow. Format/behavior changes must keep the unit tests green. See ADR-010. |

## Lock Protocol (for `coordination.md`)

A role **self-claims** by appending a lock block; only PM edits or removes other roles' locks. The canonical lock format is defined in `.context/state/coordination.md` → "Lock Template" (with background in `docs/guides/agent-best-practices.md` → "Lock Before Working"):

```markdown
## Lock: <task-id>
**Role**: <frontend|backend|...>
**Session**: <agent session id or branch name>
**PR**: <#MMM | pending | N/A>
**Claimed At**: <ISO-8601>
**Expected Duration**: <e.g., 30m, 2h>
**Paths**:
- <glob or file>
**Depends On**: <task-id or 'none'>
```

> The snippet above is illustrative; the **canonical** lock template (with all fields including `**Blocks**` and `**State**`) lives in `.context/state/coordination.md` → "Lock Template". When the two diverge, follow the canonical version. The `**PR**:` field is required on new locks per ADR-018 Amendment #1 (cadence: write `pending` at lock-claim time; update to `#MMM` at the next push after PR-open; `N/A` for branches with no planned PR).

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
