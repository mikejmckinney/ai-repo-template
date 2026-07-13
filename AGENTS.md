# AGENTS.md

<!-- AGENTS_MD_VERSION: 27 -->

## Domain: Code Quality

## Hard Rules (Never Violate)

Hard rules block diff-gate. If you relax one, the Architect writes an ADR under `docs/decisions/` recording the tradeoff and Judge references it during review.

### H1 — Single Responsibility
Every function, class, and module has **one reason to change**. If you can describe a unit with "and" ("parses input **and** writes to the database"), split it. Flag any unit where two unrelated reasons to change live in the same file.

### H2 — Open / Closed
Extend behavior by adding new code, not by mutating stable interfaces. Any breaking change to a published interface, exported type, or public API requires an ADR plus a migration note for downstream callers.

### H3 — Liskov Substitution
Subtypes must honor their base contract. Do not narrow preconditions or widen postconditions in an override. If a subtype can't honor the contract, it's not a subtype — compose instead of inherit.

### H4 — Interface Segregation
Callers must not be forced to depend on methods they don't use. Split fat interfaces into role-specific ones. "One method per caller concern" is the floor, not the ceiling.

### H5 — Dependency Inversion
High-level modules depend on abstractions, not concrete low-level modules. Inject dependencies; don't `new` them inside business logic. Concrete wiring lives at the composition root (main / entry point).

### H6 — TDD Discipline
Write a failing test **before** implementation. Keep the red-green-refactor loop explicit. See `AGENTS.md` → "Testing requirements" for the test pyramid and CI expectations — this file does not duplicate them.

### H7 — No Dead Code
Unreachable branches, unused exports, commented-out blocks, and speculative helpers ship zero value. Delete them before merge. If you think you'll need something "soon," open a task instead of leaving a stub.

### H8 — No Silent Error Swallowing
Every `catch` / `rescue` / `recover` block must either rethrow with context, log with enough detail to diagnose, or convert to a handled result that the caller can act on. Empty catch blocks and bare `except: pass` fail diff-gate.

## Soft Rules (Prefer Unless Justified)

Soft rules are targets. Judge does not block on them; Critic flags them as `CRAFT NOTES` or `NITS`. A justified exception in the commit message is enough.

### S1 — Function Length
Target: a function fits on one screen without scrolling. The exact line count is stack-specific — set a threshold in the "How to extend" block below. Rationale matters more than the count: if a longer function is genuinely more readable than its split form, keep it and say why in a comment.

### S2 — Complexity and Nesting
Target: cyclomatic complexity and nesting depth stay low enough that a reader can hold the control flow in their head. When you feel yourself indenting a fourth level, extract.

### S3 — Names Describe Intent
Names say **what the code is for**, not **how it works**. Prefer `calculateRenewalDate` over `addThirtyDays`. Avoid abbreviations unless the abbreviation is a term of art in your domain — and if it is, capture it in a glossary.

### S4 — Comments Explain Why
Comments say **why**, not **what**. If the code already says what it does, a comment that restates it is noise — delete it. Use comments to record non-obvious tradeoffs, links to issues, and decisions the reader can't reconstruct from the code.

### S5 — Duplication Beats the Wrong Abstraction
Two similar blocks are cheaper than a premature abstraction. Three is a signal to extract — but only if the three genuinely share a reason to change (see H1). Rushing to DRY fuses code that should diverge.

### S6 — Test Pyramid
Many unit tests, fewer integration tests, minimal E2E tests. Concrete CI commands and coverage expectations live in `AGENTS.md` → "Testing requirements" and the project's own `README.md`.
## Stack-Specific Overrides

- S1 function length:     <N> lines (target), <N> lines (hard max)
- S2 cyclomatic complexity: <N> (target), <N> (hard max)
- S2 nesting depth:       <N> (target), <N> (hard max)
- Lint / format tool:     <tool + config path>
- Test framework:         <framework + command>
- Coverage target:        <percent> (changed files only)
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
- **Cite your sources.** When stating a fact about the codebase or docs, include a relative path (and a line number when precision matters: `path/to/file.md:42`). Statements without a citation are treated as assumptions and must be marked `uncertain`. Judge and Critic reject uncited claims of fact.
- **Always Explain your reasoning and Default to concise.** Add structure only when it earns its keep; don't pad length or drop detail the answer needs. If a complete answer genuinely requires length, use multiple parts or multiple responses rather than cutting corners.

## Opportunity feedback channel

## Purpose

Adjacent improvements (brittle script, stale doc, automation gap) historically caused scope creep or got dropped. The `opportunity_notes` channel gives agents a capped, evaluable triage queue.

## When this rule fires

- Out-of-scope observation during in-scope work.
- Recommendation benefiting future sessions but not needed now.
- Duplicate, contradictory, or stale convention noticed while reading.

## What counts as an opportunity note

- Outside current task scope but inside repo improvement surface.
- Deferrable — current task can complete without it.
- Concrete — names a file, behavior, or symptom.
- NOT urgent for correctness, security, or in-flight work (use escalation below).

## Required fields (9 total)

Empty list permitted; partially-filled entries are not.

| Field | Type | Description |
|---|---|---|
| `title` | string | One-line headline. ≤80 chars. |
| `evidence` | string | What you observed. File path, command output, or behavior. |
| `impact` | string | Who/what is affected and how. |
| `recommendation` | string | Concrete enough to file. |
| `scope` | enum | `rule`, `script`, `doc`, `workflow`, `code`, `test`, `process`. |
| `suggested_next_action` | enum | `file-issue`, `fold-into-<n>`, `discuss`, `defer`. |
| `confidence` | enum | `high`, `medium`, `low`. |
| `duplicate_check` | string | Search/issue compared. `none` if not checked. |

## When agents may implement directly

MAY implement without a note ONLY when ALL FOUR hold:

1. **≤ ~20 LOC**, single file.
2. **Directly necessary** for in-scope task (not "while I'm here").
3. Does **not** touch role-sensitive surfaces.

When in doubt, surface the note.

## Escalation (blocking observations)

For items that **halt current work**, use `## Blocking observation` — not the 9-field schema.

Use when: **security** (secrets, auth, injection); **data-loss** risk; **CI-breaking** change the task can't fix; **plan-invalidating** false precondition.

If unsure, treat as blocking.

## Process: Session Start

## Session handshake (read-receipt)

When you have read this file at the start of a session, open your first reply with the following:

```text
Session handshake vAGENTS_MD_VERSION

| Field | Value |
|---|---|
| Agent | <copilot | claude | codex | cursor | gemini | other: name | unknown> |
| Role | <OP | architect | devops | docs | qa | judge | critic | analyst | pm | other> |
| Model | <exact model if exposed by runtime; otherwise `unknown — not exposed by runtime`> |
| AGENTS.md version | <version number> |
| Session type | <parent/default agent | dispatched subagent | other> |
| Dispatch mode | <plan-gate | diff-gate | n/a> |
| Read profile | <profile-name | full | none> |
| Receipt boundary | <fresh | post-compaction | on-demand-replay> |
```

Replace `AGENTS_MD_VERSION` with the version number specified in the HTML comment at the top of `AGENTS.md`.

The session handshake should be on its own line before any other content.

## Session context receipt

follow the session handshake with this section. Dispatched subagents emit it as `## Subagent context receipt` after `## Subagent session handshake`.

```text
## Session context receipt

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `AGENTS.md` | Read | yes | Startup contract | Loaded handshake, truth hierarchy, rule catalog pointer |
| `.context/rules/README.md` | Read | yes | Rule catalog | Selected read profile and triggered rules |
| `<path>` | <Read / Skipped> | <yes / no / partial> | <reason> | <decision, gate, or output affected> |
```

Use one row per file that was required, triggered, explicitly dispatched, or intentionally skipped.

### Load vs In context

| Column | Values | Meaning |
|---|---|---|
| **Load** | `Read`, `Skipped` | `Read` = full file loaded from disk **this receipt boundary**. `Skipped` = intentionally not loaded. |
| **In context** | `yes`, `no`, `partial` | Whether the **full** file text is **currently** in working prompt context. |

Rules:

- `Load: Read` requires a disk/current-source read **this boundary** only.
- `In context: yes` requires verbatim full file in current prompt — not memory, summary, transcript, or grep.
- `In context: partial` for search hits, excerpts, or conversation summaries that mention the file.
- After compaction or when re-displaying a prior receipt without re-read: set `In context: no` for affected rows even if `Load: Read` at an earlier boundary.
- Do not claim `In context: yes` for a file you cannot cite by line without re-reading.

### Showing the receipt mid-session

When the user asks to see the session context receipt:

1. Treat it as a **freshness check**, not a history request.
2. If mandatory profile files were not re-read **this turn**, either re-read them first (`Receipt boundary: fresh`) or emit `## Session context receipt (stale)` with every row `In context: no` and a one-line note that re-read is required before line-accurate citations.
3. **Never** copy a prior receipt table from transcript, tool output, or conversation summary as if it reflects current context.

### Stale receipt heading

Use `## Session context receipt (stale)` when `Receipt boundary` is `post-compaction` or `on-demand-replay` and profile files were not re-read this turn. Include:

```text
Prior boundary: <profile-name or unknown>. File contents not retained in context. Re-read required before compliance claims or line-accurate citations.
```

## Prompt-context read credit

If the full contents of a referenced rule file are already present verbatim in the current prompt context, you may record `Load: Skipped` and `In context: yes` for orientation and avoid re-reading it from disk.

A pointer, filename, path, heading, excerpt, search result, or summary alone does **not** count as read credit and must be `In context: partial` at best.

You must still read the on-disk file when any of the following apply:

- freshness matters;
- the rule's cadence requires a read or re-read;
- a dispatch packet explicitly names the file;
- line-accurate citations are needed;
- compliance evidence requires a disk/current-source read;
- the prompt content may be stale, partial, or transformed;
- the file is the object being edited or reviewed.

## Load / In context / legacy Reviewed definitions

Use these exact meanings in the session context receipt.

### `Load: Read`

Use `Load: Read` when you loaded the current full contents of the file from the repo or another authoritative current source during **this receipt boundary**.

`Load: Read` is required when the file is:

- part of the startup-required set;
- explicitly named by a dispatch packet;
- required by the selected read profile;
- required by a triggered rule before the affected decision;
- being edited, reviewed, cited by line, or used as compliance evidence.

Examples:

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `.context/rules/process_work_style.md` | Read | yes | PR readiness surfaces | PR checklist and review response |
| `docs/decisions/adr-019-per-role-model-tiering.md` | Read | yes | Model routing policy edit | ADR-019 amendment recommendation |
| `docs/decisions/adr-016-pre-merge-verification-gate.md` | Read | yes | Workflow-risk change | Sandbox verification requirement |

### `In context: yes` / `no` / `partial`

- `yes` — full verbatim file is in current prompt context right now.
- `no` — file was loaded earlier or named in a summary, but full text is not available now (compaction, new turn without re-read, transcript replay).
- `partial` — only an excerpt, grep hit, or summary is available.

### `Load: Skipped`

Use `Load: Skipped` when the file was considered but intentionally not loaded because its trigger did not apply, the chosen profile did not require it, or the task was blocked before the file could be read.

Every `Load: Skipped` row must explain why. Do not use `Skipped` for startup-required files unless work is blocked and no repo-changing action is being taken.

Examples:

| File | Load | In context | Why it was read | Decision affected |
|---|---|---|---|---|
| `.context/rules/domain_code_quality.md` | Skipped | no | Docs-only change; no code/refactor trigger | No code-quality gate applied |
| `docs/guides/subagent-bootstrap-reference.md` | Skipped | no | No subagents dispatched or evaluated | No subagent compliance needed |
| `.github/prompts/repo-onboarding.md` | Skipped | no | Existing repo mode already known; not onboarding a new clone | No Mode A/B decision |

### Invalid status claims

Do not claim:

- `Load: Read` from a filename, pointer, heading, excerpt, search result, or summary.
- `In context: yes` for stale prompt context, transcript replay, or post-compaction memory.
- `In context: yes` when you cannot cite the file by line without re-reading.
- `Load: Skipped` for a required file while still performing the action that required it.
- `none` read profile for repo-changing work.
- A non-stale `## Session context receipt` heading when `Receipt boundary` is `post-compaction` or `on-demand-replay` and profile files were not re-read this turn.

If a required read is impossible, mark the task blocked, explain the missing source, and stop before repo-changing work.

## Context compaction / resumed-session behavior

If context was compacted, summarized, resumed, or transferred, treat the next reply as a task boundary unless the active context still contains:

1. the current `AGENTS_MD_VERSION`;
2. the prior session handshake with current `Receipt boundary`;
3. the selected read profile;
4. the session context receipt with accurate `In context` values for every row you may cite.

If any are missing, load the mandatory files for the current read profile and re-emit the session handshake with `Receipt boundary: post-compaction`. Set `In context: no` on every row until each file is re-read this boundary.
