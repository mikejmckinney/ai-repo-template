# AGENTS.md

<!-- AGENTS_MD_VERSION: 29 -->

This file is the always-loaded operating contract for agents in this repository.
Do not require agents to reread it from disk unless the user explicitly asks for
a freshness check. Load issue, PR, ADR, benchmark, or guide context only when it
is relevant to the current task.

## Startup

Open the first substantive response in a new session or task boundary with:

```text
Session handshake v29
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

- Use one monolithic implementing agent. ADR-031 found no favorable ROI crossover
  for the multi-role pipeline, and ADR-032 retired the role registry.
- Use the `local-consensus` skill only when the user requests it or consequential
  uncertainty justifies independent multi-model review.
- Advisory review is optional, non-blocking, and may run in parallel with active
  PR implementation. CI and lint remain the blocking pre-merge controls.
- Do not require structured parent, plan, or subagent compliance blocks.

## Work style

- Create a non-default branch before non-trivial edits. Use
  `feature/<task>` or `fix/<issue>-<slug>` when applicable.
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

- **H1 Single responsibility:** every function, class, and module has one reason
  to change. If a unit parses input and writes to storage, split those unrelated
  concerns.
- **H2 Open/closed:** extend behavior with new code instead of silently mutating
  stable interfaces. Breaking a published interface, exported type, or public
  API requires an ADR and migration guidance for downstream callers.
- **H3 Liskov substitution:** subtypes honor their base contract. Do not narrow
  preconditions or widen postconditions in an override; compose when the
  contract cannot be honored.
- **H4 Interface segregation:** callers do not depend on methods they do not
  use. Split broad interfaces along caller concerns.
- **H5 Dependency inversion:** business logic depends on abstractions, not
  concrete low-level modules. Inject dependencies; keep concrete wiring at the
  composition boundary.
- **H6 Test discipline:** write or update a focused test with every behavioral
  change. Prefer an explicit red-green-refactor loop when practical.
- **H7 No dead code:** remove unreachable branches, unused exports, commented-out
  blocks, and speculative helpers. Open a follow-up instead of leaving a stub.
- **H8 No silent error swallowing:** every error handler rethrows with context,
  logs enough detail to diagnose, or returns a handled result the caller can act
  on. Empty handlers and bare `except: pass` fail review.

The following soft rules are preferred unless the change explains why another
shape is clearer:

- **S1 Function length:** aim for a function that fits on one screen. Keep a
  longer function when splitting it would obscure the control flow.
- **S2 Complexity and nesting:** keep control flow easy to hold in working
  memory. A fourth indentation level is a strong extraction signal.
- **S3 Intent-revealing names:** name code for what it accomplishes, not its
  current mechanism. Prefer `calculateRenewalDate` over `addThirtyDays`.
- **S4 Comments explain why:** document non-obvious tradeoffs, issue context,
  and decisions the reader cannot reconstruct. Delete comments that merely
  restate the code.
- **S5 Duplication beats the wrong abstraction:** two similar blocks are often
  cheaper than premature coupling. Extract only when the instances genuinely
  share a reason to change.
- **S6 Test pyramid:** keep many focused tests, fewer integration tests, and
  minimal end-to-end tests.

Downstream projects should record stack-specific thresholds, lint and format
tools, test commands, and coverage expectations in `AI_REPO_GUIDE.md`.

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
| Agent execution or review lifecycle | ADR-032, `docs/guides/agent-pipeline.md` |
| Workflow trigger or verification class | `docs/guides/agent-pipeline.md`, `scripts/verify-pr.sh`, tests, and sandbox guide as applicable |
| File listed in repository inventories | Owning check module, human index, and install inventory as applicable |
| Live-state schema or location | `.context/state/`, session guidance, and coordination guide |

If a listed companion does not need a change, state `<path>: no changes
required` with a one-line reason in the PR description.

## Clarification and critical thinking

- Resolve ambiguity from current repository and live task sources first. Ask a
  clarifying question when the request has materially different reasonable
  interpretations, requires business context only the user has, conflicts with
  a verified rule or decision, or would require inventing an API, data shape, or
  domain fact.
- When clarification is necessary, stop before implementation. Recommend one
  interpretation, explain the tradeoff, and wait for the answer; do not ask and
  build in parallel.
- Push back directly when a premise or proposed design conflicts with verified
  evidence. Explain the flaw and recommend the better approach rather than
  agreeing by default.
- Distinguish verified facts from assumptions and uncertainty. State confidence
  plainly; do not hide uncertainty behind vague qualifiers.
- Cite repository facts with relative paths and line numbers when precision
  matters. Do not guess file contents, APIs, or runtime behavior.
- Compare viable approaches honestly across cost, risk, reversibility, and blast
  radius.
- Explain enough reasoning to make non-obvious decisions reviewable, while
  keeping routine communication concise.
- When an unexpected process repeatedly hangs or fails despite grounded local
  attempts, research whether it is a known upstream issue before inventing a
  repository-specific workaround.

## Session and handoff state

- For issue-backed work, use the issue body and linked PR as the durable task
  contract. Use the latest `agent-state:v1` comment only when work is paused,
  blocked, awaiting review, or handed off.
- Keep live-state comments short: status, blocker, next actions, and handoff.
- Keep decision history in plans, PRs, ADRs, or postmortems, not live-state
  comments.
- Never create a second committed claim board or task-state system.

## Opportunity feedback

Use opportunity notes for adjacent improvements that are outside the current
task but inside the repository improvement surface. A note must be deferrable,
concrete, and supported by a file, command, or observed behavior. Do not widen
the current task to implement it.

This channel fires for brittle scripts, stale or contradictory documentation,
automation gaps, and recommendations that benefit future sessions but are not
required for the current outcome. Surface at most three notes per task. Empty
lists are valid; partially filled notes are not.

Each note uses these nine fields:

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
not opportunity notes. Stop and report them as blocking observations.

An adjacent fix may be folded into the current task without an opportunity note
only when it is directly necessary for the requested outcome, is roughly 20
lines or less in one file, and does not touch a role-sensitive contract or
workflow surface. When in doubt, keep it out of scope and surface the note.

## Reviews

Code reviews prioritize bugs, regressions, security, behavioral risk, and
missing tests. Findings come first, ordered by severity, with file and line
references. State explicitly when no findings are found and identify residual
testing risk.

## Advisory orchestration patterns

The P1-P9/AP1-AP9 catalog is shared vocabulary for reasoning about agent,
workflow, and coordination changes. It is descriptive, not a standalone review
gate: an ID alone never blocks a change. A finding must identify concrete harm
and map it to an active rule, observable regression, or unmet user outcome.

Authors and reviewers may cite these patterns to make design tradeoffs explicit.
Detailed history and examples remain in
`docs/guides/repo-orchestration-patterns-reference.md`.

### Patterns in use

- **P1 Strategy:** one implementing agent applies task-appropriate strategies;
  optional local consensus supplies independent perspectives when justified.
- **P2 Chain of Responsibility (pipeline):** staged handlers have explicit
  pass/block criteria and short-circuit on a blocking result. The full pipeline
  is optional, not the routine default.
- **P3 Mediator (coordination):** a coordinator or explicit live-state surface
  resolves cross-agent dependencies instead of peer-to-peer hidden state.
- **P4 Adapter (multi-registry):** canonical role behavior is wrapped by thin
  platform-specific overlays, with parity checks preventing drift.
- **P5 Template Method (skeletal artifacts):** plans, PRs, ADRs, and role
  registrations use stable skeletons while allowing task-specific content.
- **P6 Facade (tool-specific entry points):** `AGENT.md`, `AI_REPO_GUIDE.md`, and
  tool instructions remain thin entry points to canonical contracts.
- **P7 Owner-Keyed Concurrent State:** concurrent state is partitioned by branch,
  issue, PR, role, or another explicit owner so independent writes can merge.
- **P8 Canonical Manifest with Generated Surfaces:** frequently repeated values
  or structures have one canonical source and generated or parity-checked
  consumers when that automation costs less than manual synchronization.
- **P9 Multi-Model Plan Consensus:** high-risk or ambiguous work may compare up
  to three isolated candidate plans and synthesize one reviewable plan. It is an
  explicit opt-in technique, not default fan-out.

### Anti-patterns to watch

- **AP1 God Object:** one file accumulates unrelated reasons to change, making
  review and context loading unreliable. Signals include many unrelated top-level
  concerns, repeated cross-domain edits, and inability to review the file in one
  focused pass. Remediate by separating stable policy from task-specific detail,
  but do not split always-needed policy into mandatory rereads.
- **AP2 Mirror Duplication:** identical substantive content is manually copied
  across files. Keep one canonical body and use thin adapters, generation, or a
  parity check where multiple consumer formats are unavoidable.
- **AP3 Implicit Contract:** correctness depends on an ordering, precondition, or
  convention that exists only in contributor memory. Encode it in the closest
  contract, type, test, or workflow predicate.
- **AP4 Goal Substitution:** a change produces requested artifacts but misses the
  user action they were meant to enable. State outcomes in do-language and test
  the observable journey, not only file or endpoint existence.
- **AP5 Sequential Coupling:** useful work requires reading or executing a long
  ordered chain before the first meaningful action. Remove redundant steps and
  load task-specific context only when triggered.
- **AP6 Single-Writer Shared State:** parallel writers mutate one unpartitioned
  state record, causing conflicts or lost updates. Partition by owner or move
  coordination to a system with explicit concurrency semantics.
- **AP7 Magic String Sprawl:** labels, variables, identifiers, or route names are
  duplicated across consumers without validation. Centralize when repetition is
  frequent; otherwise add a focused cross-check when the second consumer lands.
- **AP8 Workflow-as-Application:** substantial business logic lives inside
  workflow YAML where it is difficult to test or reuse. Keep workflows as event
  wiring and move complex logic into tested scripts or actions.
- **AP9 Compatibility Surface Entrenchment:** a replacement is accepted, but the
  deprecated path remains a normal operational dependency. Stop extending the
  old surface and retire, archive, or clearly demote it.

New structural pattern IDs require an ADR. New anti-pattern IDs must include
detection signals and remediation, and any promotion from advisory vocabulary to
a blocking rule requires an explicit ADR.
