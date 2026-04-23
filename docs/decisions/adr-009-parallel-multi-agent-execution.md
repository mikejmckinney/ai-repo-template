# ADR-009: Parallel multi-agent execution — patterns, dispatch reality, and conflict enforcement

## Status

Accepted

## Date

2026-04-22

## Context

[Issue #49](https://github.com/mikejmckinney/ai-repo-template/issues/49)
asks: how should role-specialized agents (analyst, architect, judge,
critic, pm, frontend, backend, qa, devops, docs) work in parallel on
this template? Three sub-questions are tangled together in the issue:

1. **Inter-agent parallelism** — multiple agent sessions working
   different issues/PRs at the same time.
2. **Conflict resolution** — what stops two parallel sessions from
   silently corrupting each other's work, and how do we catch it when
   prevention fails?
3. **Recursive subagent nesting** — the VS Code subagents preview
   ([code.visualstudio.com/docs/copilot/agents/subagents](https://code.visualstudio.com/docs/copilot/agents/subagents))
   raises the question of whether a dispatched subagent should itself
   be allowed to dispatch further subagents.

A fourth implicit question surfaces during planning: **does in-session
parallel role dispatch actually work today?** The repo's
documentation (`docs/guides/multi-agent-coordination.md`,
`AGENTS.md`, the role files in `.github/agents/**`) reads as if any AI
runtime can fan out to roles via `Task()`-style dispatch. In practice
this is only true in the Claude Code CLI runtime. Other runtimes
(VS Code Copilot Chat, the cloud Copilot SWE agent) degrade silently
to a single orchestrator wearing all hats. Documenting this reality
matrix is part of the decision so future contributors aren't misled.

### What already exists

- **Path ownership**: `.context/rules/agent_ownership.md` declares
  which role may edit which paths.
- **Live coordination board**: `.context/state/coordination.md` tracks
  active locks and the task state machine (10 states from `analyzing`
  through `stakeholder_review`).
- **Branch-per-role convention**: `feature/<role>-<task-id>` documented
  in `docs/guides/multi-agent-coordination.md`.
- **Concurrent-Copilot budget**: `MAX_COPILOT_CONCURRENT` (default 3)
  enforced by `agent-assign-copilot.yml`. Caps how many Copilot sessions
  can be in flight at once across the repo.
- **Daily Copilot budget**: `MAX_COPILOT_DAILY` (default 20) gates
  total Copilot assignments per 24 h window.
- **Role registries (two parallel)**:
  `.github/agents/<role>.agent.md` (Copilot SDK schema) and
  `.claude/agents/<role>.md` (Claude Code schema). `test.sh` enforces
  byte-identical `description:` lines between the two.

### What's missing

- **Cross-PR conflict detection.** Path ownership prevents two roles
  from editing the same file *intentionally*. It does not catch
  *accidental* path overlap when two PRs from the same role (or two
  cross-cutting tasks dispatched in parallel) end up editing the same
  file on different branches. Today this is only caught at merge
  conflict time.
- **An honest accounting of where parallel role dispatch actually
  fires.** The repo's documentation conflates "documented role" with
  "dispatchable role in your runtime."
- **A position on subagent nesting.** The VS Code preview makes this
  newly relevant; without a position, contributors will improvise.

## Decision

ADR-009 makes four coupled decisions:

### 1. Inter-agent parallelism: keep the cross-session model. Document the prerequisites.

Parallel multi-agent work in this repo means **separate agent sessions
working on separate issues, each producing a separate PR**, gated by
`MAX_COPILOT_CONCURRENT` and the path-ownership map. Within a single
session, role specialization is provided by *role-playing the role
file* (the runtime reads `.github/agents/<role>.agent.md` and adopts
the responsibilities and constraints), not by genuine in-process fan-out
— except in Claude Code CLI, which actually dispatches.

Two issues are **parallel-safe** when all three of the following hold:

1. Their owned-path globs in `agent_ownership.md` are **disjoint**
   (no overlap in either direction).
2. Neither lists the other in `depends_on` (or in any transitive
   dependency chain).
3. They do not both touch any file in the "Shared / Contested Files"
   table of `agent_ownership.md`.

When any of those fail, the work must be **sequenced** (one PR after
the other) or **PM-arbitrated** (a temporary shared-edit claim recorded
in `coordination.md`). PM arbitration is described in
`agent_ownership.md` §"Cross-Role Edit Protocol" and is unchanged
by this ADR.

### 2. Conflict resolution: add a sixth defense layer (cross-PR overlap CI).

The existing five-layer defense from `docs/guides/multi-agent-coordination.md`
("Conflict-Avoidance Hierarchy") is preserved verbatim:

1. Path ownership map
2. Live locks in coordination.md
3. Branch isolation
4. PM arbitration
5. Judge diff-gate

ADR-009 adds layer **6: cross-PR overlap CI**. A new workflow
(`agent-parallelism-report.yml`) runs on every `pull_request` and
upserts a single PR comment ("Parallelism Report") that lists every
*other* open PR and classifies the overlap with the current PR as:

- **hard** — the two PRs touch at least one identical file path.
- **soft** — the two PRs touch different files but inside the same
  top-level owned-path glob (so they're in the same role's territory
  and merge-order may matter).
- **none** — disjoint paths.

The report is **comment-only and non-blocking**. Overlap is not
intrinsically wrong: sequential merges resolve cleanly, and PM-arbitrated
shared claims are legitimate. The report's job is to surface the
overlap so reviewers and PM can sequence intentionally rather than
discover the conflict at merge time. If reviewers want to enforce
"no hard overlap without a PM claim," that's a future hardening — see
§Future work below.

The report parses ownership globs from `agent_ownership.md` directly
(not a duplicated copy) so the source of truth stays single. If the
parse fails, the report posts a warning and skips the soft-overlap
classification rather than blocking.

### 3. Dispatch reality: name what works where.

This ADR records, as a stable contract, the matrix of which runtimes
support in-session parallel role dispatch from `.github/agents/**` /
`.claude/agents/**` today:

| Runtime                                | Loads role files? | In-session role dispatch? | Notes |
|----------------------------------------|-------------------|---------------------------|-------|
| Claude Code CLI (local + `claude.yml`) | Yes (`.claude/agents/**`)  | **Yes** — native `Task(subagent_type: ...)`, including auto-dispatch on `description:` match | Only runtime where role fan-out is fully wired today. See ADR-003. |
| VS Code Copilot Chat                   | Public preview ([docs](https://code.visualstudio.com/docs/copilot/agents/subagents)) | **Unverified** — preview exists; tool-name compatibility, auto-dispatch behavior, and parallelism model not validated against `.github/agents/**` | Tracked in [#111](https://github.com/mikejmckinney/ai-repo-template/issues/111). |
| Cloud Copilot SWE agent (issue assignment / `@copilot follow`) | Reads `AGENTS.md` + `copilot-instructions.md` + the prompt file | **No** — runs as a single session per issue/PR; no dispatch primitive exposed | Product gap, not a code gap. Multi-role behavior in this runtime is achieved by *separate* SWE-agent sessions on *separate* issues, gated by `MAX_COPILOT_CONCURRENT`. |
| Other (Cursor, Gemini, Aider, etc.)    | Reads `AGENTS.md` only | **No** — single orchestrator | Treat the role files as documentation the orchestrator reads. |

The implication: when "parallel multi-agent execution" is discussed
in this repo, it almost always means **cross-session parallelism**
(separate PRs from separate sessions), **not** in-session
`Task()`-style fan-out. Claude Code CLI is the exception. The new
overlap CI is what makes the cross-session model safe at scale.

### 4. Recursive subagent nesting: disabled by default.

A "nested subagent" means a dispatched subagent itself dispatching
another subagent (e.g. PM dispatches Architect, Architect dispatches
Judge). The VS Code preview makes this newly easy in runtimes that
implement the dispatch primitive.

ADR-009's default is **disabled**. Allowed only when **all** of:

- **Parent role is non-implementer** — only PM, Architect, Analyst,
  Judge, or Critic may nest. Implementers (frontend, backend, devops,
  docs, qa) may not. Implementers nesting violates the
  one-primary-role-per-task rule from PM's responsibilities.
- **Child stays within parent's owned paths.** A nested child cannot
  expand the parent's blast radius.
- **Depth ≤ 2.** A subagent dispatching a subagent is the maximum.
  Anything deeper is almost always a sign that the orchestration
  belongs in PM dispatch instead.

Why the conservative default: nesting hides ownership escalation
behind a `Task()` call. A frontend subagent that nests a docs subagent
to "just update the README" silently breaks the ownership map without
appearing in `coordination.md`. The blast-radius caps above keep
nesting useful (PM → Architect → Judge for plan-gate review) while
preventing the silent-escalation failure mode.

This default applies wherever in-session dispatch exists — practically,
that's Claude Code CLI today and (pending #111) potentially VS Code.

## Options Considered

### Option 1: Build a multi-issue dispatcher workflow

Build `.github/workflows/agent-parallel-dispatch.yml` that scans
`copilot:ready` issues, computes which subset are mutually
parallel-safe (disjoint owned paths, no `depends_on`), and assigns
them all to Copilot up to `MAX_COPILOT_CONCURRENT`.

- **Pros**: Active orchestration; closer to "true" automated parallel
  execution.
- **Cons**: Premature. We've never run two Copilot sessions in real
  parallel against this repo; we don't know what the dispatcher needs
  to enforce. The cloud SWE agent runtime can't actually fan out
  in-session, so this doesn't unlock new capability — it just
  re-implements the existing label-driven assignment with extra logic.
  Also costly to validate (requires burning concurrent SWE-agent
  sessions).
- **Verdict**: defer to a follow-up issue.

### Option 2: Hard-block PRs with hard overlap

Make the overlap CI a required status check that fails on **hard**
overlap unless a PM-claim marker is present in the PR body.

- **Pros**: Enforces the rule rather than just surfacing it.
- **Cons**: Creates new escape-hatch friction. Sequential merges
  resolve hard overlap cleanly today. We don't yet know how often
  hard overlap happens in legitimate workflows. Hard-blocking before
  observing the data risks blocking more than it should.
- **Verdict**: not now; revisit after observing overlap patterns from
  the comment-only V1.

### Option 3: Comment-only Parallelism Report (this ADR)

Surface every other open PR's overlap classification in a single
upserted PR comment. Non-blocking. Parses ownership globs from the
canonical source.

- **Pros**: Cheapest to ship and validate. Zero risk of false
  blockage. Forces no new conventions on existing workflows. Single
  source of truth (parses, doesn't duplicate). Easy to upgrade to
  Option 2 later if data justifies it.
- **Cons**: Information without enforcement — relies on reviewers /
  PM to act on it.
- **Verdict**: chosen.

### Option 4: Status-quo + docs only

Document the parallel-safe prerequisites and the dispatch reality
matrix; ship no new automation.

- **Pros**: Cheapest possible.
- **Cons**: Leaves the "two PRs silently overlap" gap open. Documents
  rules nothing enforces.
- **Verdict**: rejected — the value of this ADR is mostly the new CI
  layer; without it we'd just be writing prose about gaps we have no
  intention of closing.

## Consequences

### Positive

- **Conflict surfacing happens at PR-open time, not merge time.** The
  Parallelism Report tells reviewers and PM about overlap with every
  other open PR before any merge attempt. Cheap signal that previously
  required manual cross-checking.
- **Documented honest dispatch matrix.** Future contributors won't
  expect VS Code Copilot Chat or the cloud SWE agent to fan out
  in-session and won't waste cycles debugging "why doesn't it
  delegate." They'll know to use Claude Code CLI for true in-session
  fan-out, or to design the work as cross-session parallelism with
  separate PRs.
- **Subagent nesting has a stable, conservative default.** Contributors
  using Claude Code CLI (or a future VS Code dispatch) won't silently
  bypass ownership via nested `Task()` calls.
- **Single source of truth preserved.** The new CI parses
  `agent_ownership.md` instead of duplicating its content; format
  drift is caught by a `test.sh` assertion at the change PR rather
  than at the next overlap report.

### Negative

- **The Parallelism Report adds noise on every PR.** Every PR (even
  trivial doc fixes) gets the comment. We mitigate by upserting
  (single comment per PR, edited on subsequent pushes) and keeping
  the comment compact when there are no overlaps.
- **Comment-only is advisory.** A reviewer who ignores the report can
  still merge a hard-overlapping PR. We accept this in V1 to avoid
  the false-block risk; Option 2 remains available if data justifies
  hardening.
- **Ownership-map parsing is fragile.** If a future PR restructures
  the markdown table, the parser breaks. Mitigated by a `test.sh`
  assertion against the live file (so format-changing PRs fail CI
  with a clear message), and by the workflow's fail-soft behavior
  (warning instead of hard error).
- **Cloud Copilot SWE agent in-session dispatch remains a product
  gap.** Nothing in this ADR closes it; it can't be closed at the
  repo level. Documented honestly in the dispatch matrix.

### Neutral

- **No change to existing workflows.** `agent-relay-reviews.yml`,
  `agent-assign-copilot.yml`, `agent-fix-reviews.yml`, `claude.yml`,
  and the auto-merge pipeline are untouched.
- **No change to `MAX_COPILOT_CONCURRENT` / `MAX_COPILOT_DAILY`
  semantics.** The existing budgets remain the cross-session
  rate-limiter; ADR-009 adds an *orthogonal* per-PR overlap signal.
- **No new role.** The 10 existing roles are preserved unchanged.

## Implementation

The plan landing alongside this ADR (one PR, milestone 1 of #49) ships:

- `.github/workflows/agent-parallelism-report.yml` — the new workflow.
- `scripts/test-parallelism-report-parser.sh` — unit test for the
  ownership-table parser, including fixtures for hard overlap, soft
  overlap, none, and malformed-table fallback.
- `test.sh` — wires the parser test into the verification pipeline,
  including a live-format assertion that the current
  `agent_ownership.md` parses cleanly.
- `docs/guides/multi-agent-coordination.md` — three new sections:
  "Parallel Copilot Fan-Out" prerequisites, "Subagent nesting"
  defaults, "Dispatch reality matrix."
- `.context/rules/agent_ownership.md` "Shared / Contested Files"
  table — adds the new workflow file and this ADR.

Out of scope (filed as follow-up issues):

- Multi-issue dispatcher (Option 1 above) — **shipped** (#114).
- Coordination board ↔ open-PR sync check.
- Conflict auto-rebase on safe (non-overlapping) histories — **shipped** as ADR-010 (#116).
- VS Code Copilot Chat dispatch wiring — see [#111](https://github.com/mikejmckinney/ai-repo-template/issues/111).

## Verification

1. `bash test.sh` stays green (~+6 assertions from the new parser
   test).
2. `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agent-parallelism-report.yml'))"`
   → OK.
3. ADR-009 references to ADR-003, ADR-006, ADR-008, and #111 all
   resolve.
4. **Live three-PR test.** Open scratch PR-A touching `docs/foo.md`,
   PR-B touching `scripts/bar.sh`, PR-C touching `docs/foo.md`.
   Expected:
   - PR-A's report lists PR-B as **none**, PR-C as **hard**.
   - PR-B's report lists PR-A and PR-C as **none**.
   - PR-C's report lists PR-A as **hard**, PR-B as **none**.
5. **Idempotency.** Push a second commit to PR-C; verify the report
   comment is **edited**, not duplicated.
6. **Fork-safety.** Workflow `if:` guard skips when
   `pull_request.head.repo.full_name != github.repository`.
7. **Format-drift guard.** Temporarily corrupt the
   `agent_ownership.md` table in a scratch branch; confirm `test.sh`
   fails with a clear message naming the format expectation.

## Future work

- **Promote to Option 2** (hard-block on hard overlap without PM
  claim) once we have at least two months of report data showing how
  often hard overlap happens in legitimate workflows.
- **Extend the report** to flag `depends_on`-chain violations
  (PR-B's owned task depends on PR-A's task being merged, but PR-A
  isn't merged).
- **Multi-issue dispatcher** (deferred Option 1).
- **VS Code Copilot Chat dispatch** — see #111.

## References

- Issue #49 — parent.
- Issue #111 — VS Code Copilot Chat in-session dispatch
  investigation (referenced by §Decision 3).
- ADR-003 — Claude Code subagent registration. ADR-009 §Decision 3
  builds on this.
- ADR-006 — Auto-merge opt-in model. Cross-references the
  `MAX_COPILOT_CONCURRENT` budget that gates cross-session
  parallelism.
- ADR-008 — Phase 4 default + Copilot fallback. Establishes the
  workflow patterns (CLAUDE_PAT, fork-skip guard, marker-based
  comment upsert) that the new overlap workflow reuses.
- `docs/guides/multi-agent-coordination.md` — the canonical guide;
  three new sections added by this ADR.
- `.context/rules/agent_ownership.md` — the canonical ownership map
  the new workflow parses.
- VS Code custom subagents preview:
  [code.visualstudio.com/docs/copilot/agents/subagents](https://code.visualstudio.com/docs/copilot/agents/subagents)
