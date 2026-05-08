# Repo Orchestration Patterns

> **Purpose**: Shared vocabulary for naming the patterns this template uses and the anti-patterns to watch for during review. Critic and Judge cite entries from this file by ID (`P1`–`P8`, `AP1`–`AP8`) when reviewing changes to the orchestration layer (`AGENTS.md`, `.context/rules/**`, `.github/agents/**`, `.github/workflows/**`, `scripts/**`).
>
> **Scope**: This file describes the *orchestration* layer of this template — multi-agent workflow, role definitions, rule files, gates, and coordination state. Code-layer patterns for downstream projects (CMMC enclave, FedRAMP OSCAL, etc.) live in `docs/guides/design-patterns.md` (planned under sub-issue 5 of parent epic #251).

This file is **descriptive, not prescriptive**. Its job is to give reviewers concrete language for what already exists and what to flag — not to mandate new abstractions. Adding new patterns is rarely the answer; recognizing existing ones to keep changes consistent is what this file is for.

The pattern names borrow from Gang of Four where the GoF analog is close enough to be useful shorthand. Where a pattern doesn't map cleanly, the closest GoF analog is named with a caveat. **Pattern naming is not the point** — shared vocabulary is. Don't litigate whether something is "really" Bridge or Adapter; pick the closest analog and move on.

### Citation convention

The `Where it appears` and `Currently triggered by` lists in each entry cite **file paths** rather than `path:line` because (a) these are descriptions of whole-file or whole-feature concerns (e.g., "P3 appears in `scripts/multi-dispatch-safety.sh`"), not assertions about a specific line, and (b) `:line` precision on long-lived files like `AGENTS.md`, `setup.sh`, and the workflow YAMLs would create the exact `AP1` ("hardcoded line numbers") drift trap this file warns against. Per AGENTS.md §"Critical thinking and communication": "include a relative path (and a line number when precision matters)" — in this reference doc, the file path *is* the precision. Inline citations elsewhere in the file (anchor-stable references like `AGENTS.md:3` for the version canary) follow `path:line` form.

## How to use this file

- **Authors and contributors**: when changing the orchestration layer, scan the patterns (`P1`–`P8`) to keep new code consistent with existing structure. Scan the anti-patterns (`AP1`–`AP8`) before opening a PR — if your change matches a detection signal, address it or justify it in the PR description.
- **Critic**: cite anti-pattern IDs in your review notes when flagging drift (e.g., "AP1 trigger: process_session_state.md now covers three concerns"). Use `MAJOR CONCERNS` for block-able anti-patterns (`AP1`, `AP2`, `AP3`, `AP6`, `AP7`) and for advisory ones (`AP4`, `AP5`, `AP8`) when their per-entry block triggers are met (see Judge's bullet below); otherwise use `CRAFT NOTES` for advisory ones — match the citation severity to the anti-pattern's effective diff-gate designation for this PR.
- **Judge**: cite anti-pattern IDs at diff-gate when blocking. `AP1`, `AP2`, `AP3`, `AP6`, and `AP7` are block-able when triggered without justification. `AP4`, `AP5`, and `AP8` are advisory unless the PR's `User outcome` section is missing or clearly inverted (`AP4`), the canonical read list is materially extended without an ADR (`AP5`), or the workflow has caused a postmortem or is being materially extended without extracting logic (`AP8`).
- **Architect**: when proposing structural changes via ADR, reference any pattern or anti-pattern this change interacts with so reviewers can locate the relevant context.

---

## Patterns currently used

These describe the orchestration layer as it exists today. Changes that touch them should preserve the pattern unless the ADR ratifying the change explicitly retires it.

### P1 — Strategy (role specialization)

The 10 role files in `.github/agents/*.agent.md` and their mirrors in `.claude/agents/*.md` are interchangeable strategies for a single abstract operation: "do work on this task in this repo." Each role specializes the strategy by frontmatter `description:` (when this role applies), `tools:` (what it can use), and body content (how it proceeds). Dispatchers (Copilot, Claude Code, manual selection) pick a role by matching user intent against `description:`.

**Where it appears**:
- `.github/agents/{analyst,architect,backend,critic,devops,docs,frontend,judge,pm,qa}.agent.md` — full role definitions (canonical strategy bodies)
- `.claude/agents/<role>.md` — Claude Code registration pointers per ADR-003; only the `description:` frontmatter is byte-mirrored, the body delegates back to the canonical `.github/agents/<role>.agent.md`
- Role selection logic referenced from `AGENTS.md` → §"Role selection" (planned for sub-issue 2 decomposition: `.context/rules/process_role_selection.md` — file does not yet exist; current selection logic lives inline in AGENTS.md)

**What good usage looks like**: each role file has one focused responsibility (`H1` parity); roles don't reach into each other's owned paths (per `agent_ownership.md`); cross-role coordination goes through PM (see `P3`).

---

### P2 — Chain of Responsibility (pipeline)

Tasks flow through a fixed sequence: Analyst → Architect → Judge (plan review) → Critic (plan review) → PM (dispatch) → Implementer roles (Frontend / Backend / DevOps / Docs / QA) → QA (verification) → Critic (PR review) → Judge (diff-gate). Each handler decides to handle, pass, or block. Block decisions short-circuit the chain.

**Where it appears**:
- `docs/guides/multi-agent-coordination.md` defines the canonical sequence
- `AGENTS.md` → §"Analyst pre-flight gate" and §"Plan-as-comment requirement" describe the two block points (Analyst pre-flight, plan-as-comment) that act as early-chain interrupts
- `.github/agents/judge.agent.md` and `.github/agents/critic.agent.md` describe the review-stage handlers

**What good usage looks like**: each handler has clear pass/block criteria; criteria are testable and traceable to a rule file or ADR; new handlers added via ADR, not by drive-by edits to the pipeline.

---

### P3 — Mediator (PM coordinates implementers)

Implementer roles (Frontend, Backend, DevOps, Docs, QA) don't coordinate directly. When a task touches multiple roles' owned paths, PM mediates: it claims the lock, sequences the work, and resolves contention. Implementers only know "ask PM" — they don't track each other's state.

**Where it appears**:
- `.github/agents/pm.agent.md` defines PM's mediating role
- `.context/rules/agent_ownership.md` → "Lock Protocol" defines the mediation contract
- `.context/state/coordination.md` is the shared lock board PM writes to

**What good usage looks like**: implementers escalate to PM rather than negotiating directly; locks are explicit (one task per lock block); PM holds the only legitimate edit privilege over other roles' lock blocks.

---

### P4 — Adapter (dual registry)

The same canonical role exposed through two incompatible tool interfaces: GitHub Copilot expects `.github/agents/<role>.agent.md` with one frontmatter schema; Claude Code expects `.claude/agents/<role>.md` with a different schema. Both files describe the same role; each adapts the canonical content to its target tool's conventions. ADR-003 documents this.

**Where it appears**:
- `.github/agents/<role>.agent.md` — Copilot-format adapter
- `.claude/agents/<role>.md` — Claude Code-format adapter
- `test.sh` enforces `description:` byte-identity between the two adapters

**What good usage looks like**: a third tool (Cursor, Gemini, Windsurf) is added by writing a *third* adapter file, not by mutating the existing ones. **Caveat**: this pattern is being actively reconsidered in #248 / #249 — see `AP2` for why the current implementation is also an anti-pattern. The pattern itself (multiple per-platform interfaces over one canonical role) is correct; the implementation (manually-synchronized duplicates) is the issue.

---

### P5 — Template Method (skeletal artifacts)

Several artifacts in the repo are templates: a fixed skeleton with slots filled per instance. The repo doesn't use the OOP version (subclass overrides hook methods); it uses the literal-document version (markdown templates with placeholder sections).

**Where it appears**:
- `.github/PLAN_TEMPLATE.md` — implementation plan skeleton
- `.github/ISSUE_TEMPLATE/{feature_request,bug_report,agent_init}.md` — issue skeletons
- `.github/pull_request_template.md` — PR skeleton
- `docs/decisions/adr-template.md` — ADR skeleton (referenced by every ADR)
- `.github/agents/<role>.agent.md` frontmatter — role skeleton (canonical fields: `name`, `description`, `tools`, `model`)

**What good usage looks like**: filling all skeleton sections (use `N/A — <reason>` for sections that don't apply, per the PLAN_TEMPLATE convention); skeleton changes happen via ADR, not by drive-by edits.

---

### P6 — Facade (tool-specific entry points)

`CLAUDE.md` and `AGENT.md` are explicit pointer-facades over `AGENTS.md`. They exist because specific tools (Claude Code, Aider) auto-load files at those paths; the facades unify those tool-specific entry points to the canonical contract without duplicating it. `AI_REPO_GUIDE.md` is a unified reference facade over `.context/**` and `docs/**`.

**Where it appears**:
- `CLAUDE.md` — Claude Code facade
- `AGENT.md` — Aider facade
- `AI_REPO_GUIDE.md` — unified reference facade
- `.github/copilot-instructions.md` — Copilot facade (auto-loaded by Copilot)

**What good usage looks like**: facades stay thin and contain only pointers + enough framing to redirect; they do not duplicate rule content; when the canonical changes, facades update in lockstep (enforced by `process_doc_maintenance.md` trigger table).

---

### P7 — Owner-Keyed Concurrent State

Working-memory files written by parallel agents use a multi-section schema keyed by owner identifier (branch, role, session ID) instead of single-writer rewrite. Each writer owns its own section; readers merge. This emerged from PM-003 and was ratified in ADR-018 for `.context/state/_active.md`.

**Where it appears**:
- `.context/state/coordination.md` — multi-claim lock board, keyed by lock block
- `.context/state/_active.md` — multi-section per-agent active-task schema (post-ADR-018)
- The corresponding anti-pattern (`AP6`) is what this pattern fixes

**What good usage looks like**: any new shared-state file used by parallel agents starts with the multi-section schema; single-writer schemas require ADR justification; merge semantics are explicit (`coordination.md`'s "PM writes, all read-then-self-claim" is the canonical example).

---

### P8 — Canonical Manifest with Generated Surfaces

A single canonical source (typically YAML) is the source of truth for some governance content; per-tool, per-platform, or per-format surfaces are *generated* from it rather than maintained in parallel. Pre-commit regenerates on edits to the canonical source; CI verifies generated outputs are not stale. This pattern is the structural fix for `AP2` (Mirror Duplication) and `AP7` (Magic String Sprawl).

**Where it appears**:
- *Currently in flight*: role files via #248 / #249, which propose `.agents/<role>.md` as canonical with `.github/agents/`, `.claude/agents/`, and `.cursor/agents/` generated from it.
- *Candidate applications* (not yet implemented): pipeline labels currently hardcoded in `scripts/setup.sh` and referenced in workflows + docs; agent budget variables (`MAX_COPILOT_DAILY`, `MAX_COPILOT_CONCURRENT`, `PR_RESOLVE_MAX_ROUNDS`); doc-sync triggers in `process_doc_maintenance.md`; the PR-label state machine implicit in workflow conditions.
- *Conceptually used*: the shape of `agent_ownership.md` — though human-edited rather than generated, it acts as a manifest that scripts (`scripts/multi-dispatch-safety.sh`, the parallelism-report parser) read.

**What good usage looks like**:
- Canonical source is one file or one directory of files in a structured format (YAML or JSON), version-controlled and reviewable.
- Generators are scripts in `scripts/` (or composite actions in `.github/actions/`) with their own tests.
- Generated outputs are checked into the repo (so external consumers can read them without running generators) but flagged as generated in a header comment.
- Pre-commit hook regenerates on canonical changes; CI fails if generated outputs are stale relative to the canonical source.
- Adding a new platform / tool / consumer means writing one new generator output template, not touching the canonical source.

**Caveats**: this pattern earns its keep when the canonical content has 3+ surfaces or changes frequently. For 2-surface, low-change duplication, manual sync with a parity test (the current `.github/agents/` ↔ `.claude/agents/` arrangement) may be cheaper than a generator. Don't introduce manifests prophylactically — wait for the third surface or the third sync miss.

---

## Anti-patterns to watch for

These describe failure modes the orchestration layer is vulnerable to. Reviewers cite by ID when flagging or blocking. Each entry includes detection signals and a remediation path.

### AP1 — God Object

**Description**: a single file accumulates many unrelated reasons to change. The file becomes simultaneously load-bearing (everyone reads it) and unstable (everyone edits it). Re-read cost grows linearly with size; staleness risk grows with edit frequency. Single-responsibility (`H1` from `domain_code_quality.md`) applies — orchestration files are not exempt.

**Detection signals** (any one is enough to flag; two warrants blocking):
- File covers more than ~5 distinct concerns (counted as top-level sections that don't share a verb).
- File has had more than 5 substantive content changes within 90 days, in unrelated sections.
- File requires a version-canary or freshness mechanism to detect stale copies — the canary itself is evidence the file changes too often for its size.
- Re-reading the file end-to-end takes longer than 5 minutes for the average reader.

**Currently triggered by**: `AGENTS.md` (~330+ lines, version-canary at `AGENTS.md:3` in active use, 18+ concerns). Tracked in sub-issue 2 of parent epic #251.

**Remediation**: decompose by concern into focused files. Top-level file becomes a thin contract + link table. Document the decomposition in an ADR. Re-evaluate any version-canary mechanism after decomposition; if the new top-level file is small and stable, the canary may not be needed.

**Block condition**: a PR adds a new concern to an already-flagged God Object file (currently `AGENTS.md`) without an ADR justifying why the addition belongs there.

---

### AP2 — Mirror Duplication

**Description**: the same canonical content lives in two or more files that must be kept identical, with byte-identity enforced by tests rather than generated from a single source. This is DRY violation that's been *managed* rather than *eliminated*. Maintenance cost compounds with each new tool added (add a tool → add a mirror → add a sync test).

**Detection signals**:
- Two or more files contain content that must be byte-identical, enforced by tests or pre-commit hooks.
- Adding a new instance (third platform, fourth platform) requires manually copying content rather than running a generator.
- A diff to one file requires a paired diff to others; reviewers regularly catch missed pairs.

**Currently triggered by**: `.github/agents/<role>.agent.md` ↔ `.claude/agents/<role>.md` byte-identity on `description:` field. ADR-003 documents the current implementation; #248 and #249 track the canonicalization work to fix it.

**Remediation**: factor out a single canonical source; generate per-platform files from it via a script in `scripts/`; replace byte-identity tests with generator-output-stale tests. See #248 for the current design discussion.

**Block condition**: a PR adds a third mirror to an already-mirrored set instead of factoring out a canonical source. Adding to existing mirror sets is permitted but should reference the canonicalization issue (#248) in the PR description.

---

### AP3 — Implicit Contract

**Description**: a load-bearing precondition exists only in someone's head, not in a rule file, type, or test. Generalized from PM-001 (`docs/postmortems/postmortem-001-workflow-bypass.md`). The template's whole premise is that rules in files survive context shifts; expectations in heads do not.

**Detection signals**:
- A reviewer flags missing behavior; the response is "everyone knows you do X first" — but no rule file, role file, or workflow encodes that.
- A workflow has implicit ordering requirements not stated in its triggers, comments, or documentation.
- A new agent session repeatedly fails the same precondition that experienced agents do automatically.
- An ADR's "Negative consequences" section names a tribal-knowledge dependency without specifying where the knowledge lives.

**Historically triggered by**: pre-ADR-012 phase progression (PM-001), pre-ADR-018 `_active.md` schema (PM-003).

**Remediation**: codify the precondition in the closest-fit rule file (a `.context/rules/process_*.md` file, a role file, or a workflow `if:` condition). If the precondition is currently informal, the rule file is the new home; if it's enforceable in CI, add the check.

**Block condition**: a PR introduces a new workflow, role behavior, or rule that depends on an unstated precondition. Reviewers should ask "where is this enforced?" — if the answer is "everyone knows," block until it's written down.

---

### AP4 — Goal Substitution

**Description**: work is defined as a list of deliverables (files, prompts, sections) and the agent builds exactly those, satisfying the spec but missing the user outcome. Generalized from PM-002 (`docs/postmortems/postmortem-002-poc-outcome-mismatch.md`), explicitly marked universal in `docs/postmortems/README.md`. The 15-minute test in `feature_request.md` exists specifically to head this off.

**Detection signals**:
- The issue's `User outcome (15-minute test)` paragraph describes files created or sections written rather than what a user can DO.
- The PR description's verification section asserts file existence rather than user-observable behavior.
- The deliverable lands and a downstream consumer asks "OK but what does this *do*?"
- Plan describes "build X, then Y, then Z" without naming the user-observable change at the end.

**Historically triggered by**: `cloud_migration_POC` Prompts 1–6 (PM-002), pre-design-for-outcomes enforcement.

**Remediation**: rewrite the user outcome in DO-language ("a reviewer can open a PR and confirm…"); rewrite verification in DO-language ("running this command produces this output"); if the outcome can't be expressed in DO-language, the work isn't ready to ship — escalate to Architect for re-scoping.

**Advisory only**: AP4 is advisory rather than block-on-sight because outcome quality is judgment-dependent. Critic flags; Judge blocks only when the User outcome is missing entirely or is clearly inverted (deliverable-flavored).

---

### AP5 — Sequential Coupling

**Description**: a procedure requires reading N files in a specific order before any work can begin, where N is large enough that agents skip steps in practice. The cost of compliance is high enough that non-compliance is the norm.

**Detection signals**:
- The onboarding procedure specifies more than ~5 files to read before the first edit.
- The procedure's "what to read first" list has grown without anything being removed.
- Agents in practice skip middle steps (visible in PRs that miss rules covered in skipped files).
- The re-read cadence rule (re-read AGENTS.md at every task boundary) is honored only on the first task of a session.

**Currently flagged**: `AGENTS.md` § "Onboarding procedure" plus § "Session-state cadence" together specify ~7 files to read per task boundary. Sub-issue 2 (decomposition) and sub-issue 3 (top-level audit) of parent epic #251 reduce this load.

**Remediation**: shorten the canonical read list to the minimum needed for the average task; move task-specific rules to focused files agents read only when relevant; lower the per-task-boundary re-read scope (e.g., re-read the thin top-level contract only, not every rule file).

**Advisory only**: AP5 is judgment-dependent (the orchestration layer is genuinely complex; some sequence is unavoidable). Critic flags; Judge blocks only when a PR materially extends the canonical read list without an ADR justifying the addition.

---

### AP6 — Single-Writer Shared State

**Description**: a working-memory file is written by parallel agents but uses a single-writer rewrite schema, with no owner-keyed partitioning. Concurrent writes produce hard merge conflicts (or silent overwrites). Generalized from PM-003 (`docs/postmortems/postmortem-003-active-md-merge-conflict.md`); inverse of `P7` (Owner-Keyed Concurrent State).

**Detection signals**:
- A new shared-state file is added with a single-writer "rewrite at every boundary" schema, with no owner identifier in the schema.
- An existing single-writer file is referenced by a workflow that runs in parallel branches.
- Conflict resolution guidance for the file says "take ours" or "take theirs" without specifying owner — i.e., the file's content has no owner.

**Historically triggered by**: pre-ADR-018 `_active.md` schema (PM-003).

**Remediation**: redesign the schema as a multi-section structure keyed by owner identifier (branch, role, session ID); each writer owns its own section; readers merge. ADR-018's `_active.md` schema is the canonical example. See `P7`.

**Block condition**: a PR adds or modifies a shared-state file (under `.context/state/**` or any other concurrent-write surface) with a single-writer schema. Block until the schema is owner-keyed or the ADR justifies why concurrent writes can't happen for this specific file.

---

### AP7 — Magic String Sprawl

**Description**: identifiers (label names, variable names, role names, prompt names, path globs) are duplicated as raw strings across multiple files with no canonical source. A typo or forgotten update in one file silently breaks automation that depends on string equality. The structural fix is `P8` (Canonical Manifest with Generated Surfaces).

**Detection signals** (any one is enough to flag; two warrants blocking):
- The same identifier appears in 3+ files (typically: one or more workflows, `setup.sh`, a docs file, a rules file) with no manifest declaring it as canonical.
- A PR introduces a new label, variable, or named identifier in one file without updating the consumer files that need to know about it.
- A PR modifies an identifier in one file (rename, retype) without paired updates to consumers.
- A test or workflow failure traces back to a string mismatch between two files that should agree.

**Currently triggered by**:
- Pipeline labels (`copilot:ready`, `copilot:queued`, `copilot:in-progress`, `copilot:budget-paused`, `copilot:daily-cap-hit`, `cap-override`, `auto-merge`, `claude-fix`, `copilot-relay`, `agent-complete`, `needs-human`, etc.) hardcoded in `scripts/setup.sh` and referenced in `.github/workflows/*.yml`, `docs/guides/agent-pipeline.md`, `AGENTS.md`, and rule files.
- Agent budget variables (`MAX_COPILOT_DAILY`, `MAX_COPILOT_CONCURRENT`, `PR_RESOLVE_MAX_ROUNDS`) set in `setup.sh`, referenced in workflows and docs.

**Remediation**: factor identifiers into a YAML manifest under `.config/`; update consumers to read from the manifest (in scripts) or be validated against it (in workflows/docs via a `validate-label-references.sh`-style check). See `P8` for the broader pattern.

**Block condition**: a PR introduces, removes, or renames an identifier without updating all known consumers. Once a canonical manifest exists, the block condition tightens to "any new identifier must be added to the manifest in the same PR."

---

### AP8 — Workflow-as-Application

**Description**: heavy business logic is embedded in GitHub Actions YAML where it's hard to unit-test, hard to reason about, and hard to reuse. The workflow becomes the application; the scripts and composite actions become afterthoughts. Logic-heavy YAML accumulates conditional branches, hardcoded magic strings, and provider-specific caveats that no test can cover.

**Detection signals**:
- A `.github/workflows/*.yml` file exceeds ~150 lines.
- A workflow contains 3+ substantive `if:` conditional branches with logic (not just trigger filters).
- A workflow hardcodes magic strings (label names, role names, branch patterns) the existing tests cannot verify.
- A workflow has caused a postmortem traceable to YAML logic that would have been a bug in equivalent script form.
- Reviewing the workflow requires reading the workflow plus 2+ external context files (docs, role files) to understand what the workflow does.

**Currently flagged by inspection**:
- `agent-fix-reviews.yml` — event filtering, fork guards, budget enforcement, review batching, provider-specific delegation logic.
- `agent-multi-dispatch.yml` — parallel dispatch logic with multiple guards and ownership checks.
- `agent-relay-reviews.yml` — provider routing logic.
- `auto-rebase-on-merge.yml` — overlap classification + decision logic (some already extracted to `scripts/auto-rebase-overlapping.sh`; partial migration).

**Remediation**: keep workflows as event-wiring + step orchestration. Push logic into testable scripts (`scripts/workflows/<workflow-name>/<step>.sh`) or composite actions (`.github/actions/<action-name>/`). Each extracted unit gets its own test (Bats fixture or unit test under `scripts/tests/`).

**Advisory only**: AP8 is advisory because the line between "trigger filter" and "business logic" is judgment-dependent. Critic flags; Judge blocks only on workflows that have caused a postmortem traceable to YAML logic, or on PRs that materially extend an already-flagged workflow without extracting any logic.

---

## How to extend

This file describes patterns specific to *this* template. Downstream projects derived from this template:

1. **May add project-specific patterns** to a separate file under `.context/rules/` (e.g., `domain_security_patterns.md` for the CMMC enclave) — keep this file's scope focused on orchestration.
2. **Should not delete entries** without an ADR. Postmortem-derived entries (`AP3`, `AP4`, `AP6`, and `P7`) in particular are load-bearing — removing them implicitly says "we no longer think this lesson applies."
3. **May tighten advisory entries to block-on-sight** if local conventions warrant — document the change in an ADR amending this file's "Block condition" lines.

When adding a new entry to this file:

- New patterns get the next available `P<n>` ID and require an ADR if they describe a structural choice (otherwise just a Docs/Architect PR).
- New anti-patterns get the next available `AP<n>` ID and require an ADR (block conditions are a Critic/Judge contract; changing them is a process change).
- Each entry includes: description, where it appears (or appeared), detection signals, remediation, block-or-advisory designation.

## See Also

- `docs/decisions/` — ADRs are the canonical record of structural decisions; many entries here cross-reference ADRs.
- `docs/postmortems/` — postmortem-derived entries (`AP3`, `AP4`, `AP6`, `P7`) link back to their originating postmortem.
- `.context/rules/domain_code_quality.md` — code-layer Hard/Soft rules (`H1`–`H8`, `S1`–`S6`); orchestration patterns here parallel those rules at the workflow layer.
- `.context/rules/agent_ownership.md` — confirms Architect ownership of this file; PM coordinates cross-role edits.
- `docs/guides/design-patterns.md` (sub-issue 5 of parent epic #251, when filed) — code-layer patterns for downstream projects; complementary scope to this file.
- `.github/agents/critic.agent.md`, `.github/agents/judge.agent.md` — the review roles that cite entries from this file at PR time.
- `docs/decisions/adr-020-orchestration-patterns-reference.md` — ADR ratifying the addition of this file.
