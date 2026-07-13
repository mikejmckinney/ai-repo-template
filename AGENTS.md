# AGENTS.md

<!-- AGENTS_MD_VERSION: 28 -->

This file is the always-loaded operating contract for agents in this repository.
Do not require agents to reread it from disk unless the user explicitly asks for
a freshness check. Load issue, PR, ADR, benchmark, or guide context only when it
is relevant to the current task.

## Startup

Open the first substantive response in a new session or task boundary with:

```text
Session handshake v28
```

The handshake is a lightweight freshness canary, not a compliance schema. Do
not append context-receipt tables or read-accounting evidence.

After context compaction, emit the handshake again before substantive work.

## Truth hierarchy

When sources conflict, use this order:

1. Current assigned issue and linked PR for task scope and acceptance criteria.
2. `AGENTS.md` for repository-wide operating policy.
3. `.context/**` for current project direction, state guidance, and benchmarks.
4. `docs/**` for durable decisions, guides, and historical rationale.
5. The codebase for implementation reality.

Current files and live GitHub state outrank historical transcripts and archived
session notes.

## Execution model

- Prefer one implementing agent for routine work. ADR-031 found no favorable
  ROI crossover for the multi-role pipeline on the benchmarked task classes.
- Use role files under `.agents/` as specialty guidance, not as a mandatory
  dispatch pipeline or path-ownership gate.
- Dispatch another agent only when the user requests it or independent review,
  isolation, or specialized expertise justifies the overhead.
- Do not require structured parent, plan, or subagent compliance blocks.

## Work style

- Create a non-default branch before non-trivial edits. Use
  `feature/<role>-<task>` or `fix/<issue>-<slug>` when applicable.
- Prefer the smallest reversible change that fully solves the task.
- Do not bundle unrelated refactors. Record worthwhile adjacent work separately.
- Preserve unrelated user changes in a dirty worktree.
- Never use destructive Git commands to discard work unless the user explicitly
  approves them.
- Do not commit secrets or bypass hooks with `--no-verify`.
- Commit coherent task boundaries. Push and open PRs only when requested or when
  the user has explicitly approved that workflow.
- Explain non-obvious prerequisites, tradeoffs, and failure modes.

## Code quality

These hard rules block review unless an ADR records an explicit exception:

- **H1 Single responsibility:** a unit should have one reason to change.
- **H2 Open/closed:** extend stable behavior without silently breaking public
  interfaces. Published breaking changes require migration guidance.
- **H3 Liskov substitution:** subtypes must honor their base contracts.
- **H4 Interface segregation:** callers should not depend on methods they do not
  use.
- **H5 Dependency inversion:** business logic depends on abstractions; concrete
  wiring belongs at composition boundaries.
- **H6 Test discipline:** write or update focused tests with behavioral changes.
- **H7 No dead code:** remove unused branches, exports, and speculative helpers.
- **H8 No silent error swallowing:** rethrow with context, log diagnostically, or
  return a handled result.

Prefer clear intent-revealing names, low nesting, comments that explain why,
and duplication over the wrong abstraction.

## Testing and validation

- Follow the test pyramid: many focused tests, fewer integration tests, minimal
  end-to-end tests.
- Do not weaken tests to force a green result. Fix the underlying behavior.
- Run the repository commands documented in `AI_REPO_GUIDE.md` for affected
  surfaces. Run `./test.sh` before declaring repository changes complete.
- Treat lint, unit tests, schema checks, and CI as supporting evidence.
- Primary validation is the user outcome: perform the issue's observable
  15-minute test or explain concretely why it is not applicable.
- If the implementation does not resolve the stated problem, stop and surface
  the framing mismatch rather than patching around the test.
- For default-branch-only workflow behavior, use the sandbox verification guide
  and record real issue, PR, and run links when the workflow cannot be exercised
  from the feature branch.

## Documentation synchronization

Update companion documentation in the same PR when a change affects it:

| Change | Companion surface |
|---|---|
| Build, test, lint, run, install, layout, entry points, or troubleshooting | `AI_REPO_GUIDE.md` |
| An accepted architectural decision | Amend or supersede the relevant ADR and update `docs/decisions/README.md` |
| Multi-agent flow, role boundaries, or coordination | `docs/guides/multi-agent-coordination.md` |
| Role registration | Canonical `.agents/<role>.md`, platform overlays, install inventory, and mirror checks |
| Workflow trigger or verification class | `docs/guides/agent-pipeline.md`, `scripts/verify-pr.sh`, tests, and sandbox guide as applicable |
| File listed in repository inventories | Owning check module, human index, and install inventory as applicable |
| Live-state schema or location | `.context/state/`, session guidance, and coordination guide |

If a listed companion does not need a change, state `<path>: no changes
required` with a one-line reason in the PR description.

## Clarification and critical thinking

- Resolve ambiguity from current repository and live task sources first.
- When materially different interpretations remain, stop, recommend one, explain
  the tradeoff, and ask the user before implementation.
- Push back directly when a premise conflicts with verified evidence.
- Distinguish verified facts from assumptions and uncertainty.
- Cite repository facts with relative paths and line numbers when precision
  matters. Do not guess file contents, APIs, or runtime behavior.
- Compare viable approaches honestly across cost, risk, reversibility, and blast
  radius.

## Session and handoff state

- For issue-backed work, use the issue body and linked PR as the durable task
  contract. Use the latest `agent-state:v1` comment only when work is paused,
  blocked, awaiting review, or handed off.
- Keep live-state comments short: status, blocker, next actions, and handoff.
- Keep decision history in plans, PRs, ADRs, or postmortems, not live-state
  comments.
- Never create a second committed claim board or task-state system.

## Opportunity feedback

Surface at most three concrete, deferrable, out-of-scope opportunities without
expanding the current task. Each note uses these nine fields:

| Field | Meaning |
|---|---|
| `title` | Short headline |
| `evidence` | Observed file, command, or behavior |
| `impact` | Who or what is affected |
| `recommendation` | Concrete proposed action |
| `scope` | `rule`, `script`, `doc`, `workflow`, `code`, `test`, or `process` |
| `suggested_next_action` | `file-issue`, `fold-into-<n>`, `discuss`, or `defer` |
| `confidence` | `high`, `medium`, or `low` |
| `role_relevance` | Role or owner most relevant to follow-up |
| `duplicate_check` | Search or issue checked, or `none` |

Security, data-loss, CI-breaking, and plan-invalidating findings are blockers,
not opportunity notes.

## Reviews

Code reviews prioritize bugs, regressions, security, behavioral risk, and
missing tests. Findings come first, ordered by severity, with file and line
references. State explicitly when no findings are found and identify residual
testing risk.

Historical orchestration pattern IDs may appear in ADRs and archived material,
but P1-P9/AP1-AP9 are no longer active review gates.
