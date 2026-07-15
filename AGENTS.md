# AGENTS.md

<!-- AGENTS_MD_VERSION: 30 -->

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
  for the multi-role pipeline and retired the role registry.
- Use the `local-consensus` skill only when the user requests it or consequential
  uncertainty justifies independent multi-model review.
- Advisory review is optional, non-blocking, and may run in parallel with active
  PR implementation. CI and lint remain the blocking pre-merge controls.

## Domain: Code Quality

### Hard Rules (Never Violate)

#### H1 — Single Responsibility

Every function, class, and module has **one reason to change**. If you can describe a unit with "and" ("parses input **and** writes to the database"), split it. Flag any unit where two unrelated reasons to change live in the same file.

#### H2 — Open / Closed

Extend behavior by adding new code, not by mutating stable interfaces. Any breaking change to a published interface, exported type, or public API requires an ADR plus a migration note for downstream callers.

#### H3 — Liskov Substitution

Subtypes must honor their base contract. Do not narrow preconditions or widen postconditions in an override. If a subtype can't honor the contract, it's not a subtype — compose instead of inherit.

#### H4 — Interface Segregation

Callers must not be forced to depend on methods they don't use. Split fat interfaces into role-specific ones. "One method per caller concern" is the floor, not the ceiling.

#### H5 — Dependency Inversion

High-level modules depend on abstractions, not concrete low-level modules. Inject dependencies; don't `new` them inside business logic. Concrete wiring lives at the composition root (main / entry point).

#### H6 — TDD Discipline

Write a failing test **before** implementation. Keep the red-green-refactor loop explicit. See `AGENTS.md` → "Testing requirements" for the test pyramid and CI expectations — this file does not duplicate them.

#### H7 — No Dead Code

Unreachable branches, unused exports, commented-out blocks, and speculative helpers ship zero value. Delete them before merge. If you think you'll need something "soon," open a task instead of leaving a stub.

#### H8 — No Silent Error Swallowing

Every `catch` / `rescue` / `recover` block must either rethrow with context, log with enough detail to diagnose, or convert to a handled result that the caller can act on. Empty catch blocks and bare `except: pass` fail diff-gate.

### Soft Rules (Prefer Unless Justified)

#### S1 — Function Length

Target: a function fits on one screen without scrolling. The exact line count is stack-specific — set a threshold in the "How to extend" block below. Rationale matters more than the count: if a longer function is genuinely more readable than its split form, keep it and say why in a comment.

#### S2 — Complexity and Nesting

Target: cyclomatic complexity and nesting depth stay low enough that a reader can hold the control flow in their head. When you feel yourself indenting a fourth level, extract.

#### S3 — Names Describe Intent

Names say **what the code is for**, not **how it works**. Prefer `calculateRenewalDate` over `addThirtyDays`. Avoid abbreviations unless the abbreviation is a term of art in your domain — and if it is, capture it in a glossary.

#### S4 — Comments Explain Why

Comments say **why**, not **what**. If the code already says what it does, a comment that restates it is noise — delete it. Use comments to record non-obvious tradeoffs, links to issues, and decisions the reader can't reconstruct from the code.

#### S5 — Duplication Beats the Wrong Abstraction

Two similar blocks are cheaper than a premature abstraction. Three is a signal to extract — but only if the three genuinely share a reason to change (see H1). Rushing to DRY fuses code that should diverge.

#### S6 — Test Pyramid

Many unit tests, fewer integration tests, minimal E2E tests. Concrete CI commands and coverage expectations live in `AGENTS.md` → "Testing requirements" and the project's own `README.md`.

### Stack-Specific Overrides

- S1 function length:     &lt;N&gt; lines (target), &lt;N&gt; lines (hard max)
- S2 cyclomatic complexity: &lt;N&gt; (target), &lt;N&gt; (hard max)
- S2 nesting depth:       &lt;N&gt; (target), &lt;N&gt; (hard max)
- Lint / format tool:     <tool + config path>
- Test framework:         <framework + command>
- Coverage target:        &lt;percent&gt; (changed files only)

## Clarification and ambiguity

When a request is ambiguous — where different reasonable interpretations lead to meaningfully different work — stop, ask, recommend and explain reasoning before proceeding. Don't guess and build, and don't ask and build in parallel; ask, then wait.

- **Always Verify details with live sources when available and cite sources**
- **When to trigger a clarifying question.** Ask specifically when: (1) the request could reasonably mean two or more different things, (2) a decision requires information only the user has (business context, preferences, external constraints), (3) the request conflicts with something in the repo's rules or prior decisions (follow the **Push back** rule in [Critical thinking and communication](#critical-thinking-and-communication) rather than just asking), or (4) proceeding would require inventing facts (API shapes, data structures, domain terms) that can't be verified.

For unexpected issues that are difficult to resolve like a process that consistently hangs or fails despite multiple attempts to fix it, research the issue on the internet to see if it is a known issue others have encountered and what the fix or workaround is.

## Critical thinking and communication

Agents must reason critically rather than agree by default. The bar is "objective and evidence-based," not "agreeable."

- **Push back when warranted.** If the user's plan, premise, or proposed code has a flaw, say so directly and explain why. Don't hedge to be polite. If a better approach exists, recommend it and justify the tradeoff.
- **Calibrate confidence.** State what you verified vs. what you assumed. When something is uncertain, say "uncertain" — don't pad with false confidence and don't hide behind vague qualifiers.
- **Don't guess APIs, file contents, or runtime behavior.** Verify by reading the file or searching the codebase. If you can't verify, say so explicitly rather than asserting.
- **Compare approaches honestly.** When multiple options are viable, name the tradeoffs (cost, risk, reversibility, blast radius) before recommending one.
- **Cite your sources.** When stating a fact about the codebase or docs, include a relative path (and a line number when precision matters: `path/to/file.md:42`). Statements without a citation are treated as assumptions and must be marked `uncertain`.
- **Always Explain your reasoning and Default to concise.** Add structure only when it earns its keep; don't pad length or drop detail the answer needs. If a complete answer genuinely requires length, use multiple parts or multiple responses rather than cutting corners.

## Opportunity feedback channel

### Purpose

Adjacent improvements (brittle script, stale doc, automation gap) historically caused scope creep or got dropped. The `opportunity_notes` channel gives agents a capped, evaluable triage queue.

### When this rule fires

- Out-of-scope observation during in-scope work.
- Recommendation benefiting future sessions but not needed now.
- Duplicate, contradictory, or stale convention noticed while reading.

### What counts as an opportunity note

- Outside current task scope but inside repo improvement surface.
- Deferrable — current task can complete without it.
- Concrete — names a file, behavior, or symptom.
- NOT urgent for correctness, security, or in-flight work (use escalation below).

### Required fields (8 total)

Empty list permitted; partially-filled entries are not.

| Field | Type | Description |
| --- | --- | --- |
| `title` | string | One-line headline. ≤80 chars. |
| `evidence` | string | What you observed. File path, command output, or behavior. |
| `impact` | string | Who/what is affected and how. |
| `recommendation` | string | Concrete enough to file. |
| `scope` | enum | `rule`, `script`, `doc`, `workflow`, `code`, `test`, `process`. |
| `suggested_next_action` | enum | `file-issue`, `fold-into-<n>`, `discuss`, `defer`. |
| `confidence` | enum | `high`, `medium`, `low`. |
| `duplicate_check` | string | Search/issue compared. `none` if not checked. |

### When agents may implement directly

MAY implement without a note ONLY when BOTH hold:

1. **≤ ~20 LOC**, single file.
2. **Directly necessary** for in-scope task (not "while I'm here").

When in doubt, surface the note.

### Escalation (blocking observations)

For items that **halt current work**, use `## Blocking observation` — not the 8-field schema.

Use when: **security** (secrets, auth, injection); **data-loss** risk; **CI-breaking** change the task can't fix; **plan-invalidating** false precondition.

If unsure, treat as blocking.

## Session-state cadence

Keep agent working memory current so the next session can resume cleanly. For normal GitHub-connected work, **live coordination state lives in GitHub**, not in manually maintained repo-local markdown.

### Live coordination surface

- **Issue body** — stable task contract. Do not rewrite it for live progress updates.
- **PR body** — implementation/review contract. Link the issue, plan comment(s), verification results, and latest live-state comment when relevant.
- **Latest `agent-state:v1` comment** — mutable baton for current status, blockers, next actions. Use [`.context/state/agent_state_comment_template.md`](./.context/state/agent_state_comment_template.md) as the copy/paste template.
- **Local scratch copies** — if GitHub access is temporarily unavailable, temporarily record the same `agent-state:v1` content locally. Copy it into the issue/PR comment once access returns, then discard the local scratch copy. Do not commit local live-state scratch files as the normal path or reconcile a second persistent state surface.

### `agent-state:v1` update cadence

Update or post the latest `agent-state:v1` issue/PR comment at each of these boundaries:

1. **Task start.** Record branch, current status, blockers, and next actions.
2. **Every wait-for-input pause, no exceptions.** This includes clarification questions mid-task, plan approval pauses, review-feedback pauses, and "task done, what's next?" pauses. Write now; do not defer until closeout or merge.
3. **Durability-risk boundaries.** If a single conversation exceeds ~30 turns, the runtime auto-summarizes mid-flight, or the session ends while the task is not merged/closed, update the `agent-state:v1` comment before responding to the next message. Use runtime-provided turn counters or auto-summary notices when available; otherwise self-count approximately and treat any injected conversation summary as an auto-summary boundary.
4. **Closeout.** Set `Status: done` when the agent has fully left the work.

Each turn, update the `agent-state:v1` comment on the active issue/PR. **Maintain a current
comprehensive snapshot — merge, do not replace, do not append:**

- **Carry forward** items still relevant; **add** new; **drop** superseded; **compress landed items
  to `references`** — when an outcome lands durably (commit/PR/doc edit), replace its prose with the pointer
  (commit SHA / PR #) since git is the permanent record. The snapshot evolves "thinking about X" →
  "X → `6315da1`".
- **Why merge, not replace:** during the *deliberation* phase (hashing out an issue/plan across many
  turns, no commit yet) the comment is the only running record; a replace would lose earlier
  decisions on compaction. **Why merge, not append:** git already captures landed work permanently, so
  accumulating per-turn JSON in the comment is redundant and hits the 65,536-char comment cap. A
  merged snapshot stays naturally bounded (superseded/landed items drop out).
- Edited **in place** (one canonical comment).
- **Rate limits:** binding limit is GitHub's secondary content-creation cap (~500/hour per user). A
  turn spans minutes → ~20–30 writes/hour even with pipeline + other agents on the same PAT (>15×
  headroom).
- **Circuit breaker (required):** check `x-ratelimit-remaining`/`retry-after`; on 403/429 stop GitHub
  writes for the session and fall to local-only — never retry into a ban.
- **Fall back to local buffer** on any GitHub failure / no active issue/PR.

### Postmortem feedback loop

When a downstream project (a repo built *from* this template) hits an incident worth a postmortem, run `.github/prompts/capture-postmortem.md` in that project repo. If the resulting postmortem's `generalizes:` is `Yes` or `Unclear`, run `.github/prompts/mirror-postmortem.md` against this template to mirror it back with a same-PR follow-up. The promotion policy is defined in `docs/postmortems/README.md` and ratified in [ADR-015](docs/decisions/adr-015-postmortem-feedback-loop.md). Do NOT add per-stack guidance (Terraform, Python, Rust, etc.) to this file — that is the failure mode the policy exists to prevent.

## Work style, testing, validation

### Work style

- **Branch first, then commit per task boundary.** You MUST be on a non-default branch *before* making any non-trivial edit — branching is a precondition for the work, not a wrap-up step. You MUST also commit (and push, when a remote exists) at least once per task boundary, *not* only at the end of a multi-task session. Working directly on `main`/`master` is not acceptable, even for "I'll branch later" exploration. Branch naming: use `feature/<task-id>` as the standard form; a `fix/<slug>` form is also acceptable for bug-fix branches when that naming is clearer.
- **Surface prerequisites and edge cases** when explaining a plan or how-to: required tools, dependencies, non-obvious failure modes, safety issues. Skip boilerplate warnings on trivial work.
- **Don't weaken tests or make unrelated source changes to force them green.** If a test exposes a real bug, fix the bug in the source. Tests document behavior; weakening them to go green is a regression in disguise.
- **GitHub issue close keywords — intentional in PRs, careful in commits.** Use `Closes #N` / `Fixes #N` / `Resolves #N` (and synonyms: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`) in the **PR description** when merge should link and close the tracked issue(s). That is the intended workflow; reference the **correct** issue numbers only. **Commit messages and squash-merge bodies also parse these keywords** when the commit lands on the default branch — a subject like `fix #N links` closes issue N even when you only meant to fix markdown URLs pointing at that issue. In commits: reference issues without a closing keyword (`issue N`, `(#N)`, `for issue N`) unless the commit itself should close the issue. **Do not use real issue numbers in bad examples** in commit or PR merge text (even as illustrations); GitHub still parses them. Repo setting **Settings → General → Issues → Auto-close issues with merged linked pull requests** controls sidebar/PR-body links; it does not fully disable commit-message keyword closes. See [linking a PR to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue).

### Testing requirements

- Follow the test pyramid: many unit tests, fewer integration tests, minimal E2E tests.
- Write tests before or alongside implementation (TDD preferred).
- All behavioral changes must include appropriate tests.
- A pragmatic sandbox/dogfood test must be performed and `Sandbox issue:` and `Sandbox PR:` labels (with real URLs) must appear in the test/verification section per ADR-029. Read and follow the [sandbox verification playbook](docs/guides/sandbox-verification.md) which details the process for using sandbox and which sandbox instance to use.
- CI must pass before marking tasks complete. If CI fails:
  1. Read the error logs
  2. Fix the underlying issue
  3. Push and retry until green

### Validation

#### Primary validation: User outcome / 15-minute test

Before marking any non-exempt issue implementation complete, perform the issue's
`User outcome (15-minute test)` against the actual problem statement and record
the result with concrete evidence in the PR body.

Outcome validation answers: did the shipped artifact solve the user's stated
problem?

If the user outcome does not resolve the problem statement, do not patch around
the test merely to make it pass. Stop, document the framing disconnect, and
escalate to the user or revise the issue/plan.

A pragmatic sandbox/dogfood test with concrete steps is required in the
verification section of issues and plans. Read and follow the
[sandbox verification playbook](docs/guides/sandbox-verification.md)
playbook which details the process for using sandbox and which sandbox instance to use.
The `Sandbox issue:` and `Sandbox PR:`
labels (canonical literals per ADR-029, the PR template) should be linked as proof that
the user outcome solves the problem. For example,
An issue opened to add a .md file that walks an agent through the development and
implementation of a new feature should, as part of the test and validation, walk
through and run the process defined in the .md file in a sandbox or test environment
to verify that it meets the user outcome which in turn, should solve the problem.
If this does not happen, then there is a disconnect between the user outcome
and the problem statement and that should be raised to the user for review.

#### Supporting validation

Unit tests, integration tests, `./test.sh`, lint, pre-commit, schema validators,
and CI are supporting regression and hygiene evidence.
They do not replace user-outcome validation.  Artifact creation, static prose
review, schema validation, or logical similarity are not sufficient evidence for
operational process/user-outcome claims.

A green CI run with no user-outcome evidence is not ready for review.

- Run the repo's verification commands (prefer those documented in AI_REPO_GUIDE.md) before declaring done.
- Ensure all tests pass locally before pushing.
- Check that CI pipeline is green.

## Reviews

Code reviews prioritize bugs, regressions, security, behavioral risk, and
missing tests. Findings come first, ordered by severity, with file and line
references. State explicitly when no findings are found and identify residual
testing risk.

## Repo Orchestration Patterns

The P1-P9/AP1-AP10 catalog is shared vocabulary for reasoning about agent,
workflow, and coordination changes. It is descriptive, not a standalone review
gate: an ID alone never blocks a change. A finding must identify concrete harm
and map it to an active rule, observable regression, or unmet user outcome.

Authors and reviewers may cite these patterns to make design tradeoffs explicit.
Detailed history and examples remain in
`docs/guides/repo-orchestration-patterns-reference.md`.

### Patterns in use

- **P1 Strategy (role specialization - deprecated):** role files provide focused strategies
  selected when specialization is worth the overhead; routine implementation
  still defaults to one agent.
- **P2 Chain of Responsibility (pipeline):** staged handlers have explicit
  pass/block criteria and short-circuit on a blocking result. The full pipeline
  is optional, not the routine default.
- **P3 Mediator (coordination):** a coordinator or explicit live-state surface
  resolves cross-agent dependencies instead of peer-to-peer hidden state.
- **P4 Adapter (multi-registry - deprecated):** canonical role behavior is wrapped by thin
  platform-specific overlays, with parity checks preventing drift.
- **P5 Template Method (skeletal artifacts):** plans, PRs, ADRs, and roles (deprecated)
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
- **AP10 Undifferentiated Infrastructure Ownership:** the project owns custom
  infrastructure that duplicates a maintained platform capability without a
  verified project-specific requirement or measurable benefit. Prefer the
  maintained capability; retain custom infrastructure when evidence justifies
  its compliance, isolation, performance, or reproducibility cost.
