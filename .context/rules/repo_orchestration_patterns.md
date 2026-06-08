# Repo Orchestration Patterns

> **Purpose**: Shared vocabulary for orchestration-layer review. Critic and Judge cite entries by ID (`P1`–`P9`, `AP1`–`AP9`) when reviewing `AGENTS.md`, `.context/rules/**`, `.agents/**`, `.github/agents/**`, `.github/workflows/**`, `scripts/**`.
>
> **Scope**: Orchestration layer of this template. Code-layer patterns live in [`docs/guides/design-patterns.md`](../../docs/guides/design-patterns.md). Long-form "where it appears," remediation, and history: [`docs/guides/repo-orchestration-patterns-reference.md`](../../docs/guides/repo-orchestration-patterns-reference.md).

This file is **descriptive, not prescriptive** — reviewers get concrete language; authors scan for consistency. Pattern naming borrows from GoF where useful; don't litigate analog fit.

### Citation convention

`Where it appears` lists cite **file paths** (not `:line`) because these are whole-file concerns and line numbers on long-lived files create `AP1` drift. Inline canary references (e.g. `AGENTS.md:3`) use `path:line` when precision matters.

## How to use this file

- **Authors**: scan `P1`–`P9` for consistency; scan `AP1`–`AP9` before opening a PR.
- **Critic**: cite anti-pattern IDs. `MAJOR CONCERNS` for block-able APs (`AP1`, `AP2`, `AP3`, `AP6`, `AP7`, `AP9`) and advisory APs when per-entry block triggers fire; else `CRAFT NOTES`.
- **Judge**: cite at diff-gate. Block-able when triggered without justification: `AP1`, `AP2`, `AP3`, `AP6`, `AP7`, `AP9`. Advisory unless per-entry trigger fires: `AP4` (missing/inverted user outcome), `AP5` (canonical read list extended without ADR), `AP8` (postmortem-caused YAML logic or material extension without extraction). `AP9` is block-able only on its per-entry trigger (deprecated compatibility surface extended after replacement accepted).
- **Architect**: reference interacting patterns/anti-patterns in ADRs.

---

## Patterns currently used

### P1 — Strategy (role specialization)

Ten `.agents/*.md` role files are interchangeable strategies; dispatchers pick by `description:` with platform overlays (ADR-023, #330).

### P2 — Chain of Responsibility (pipeline)

Fixed sequence: Analyst → Architect → Judge/Critic (plan) → PM → implementers → QA → Critic/Judge (diff). Block decisions short-circuit.

### P3 — Mediator (PM coordinates implementers)

Implementers escalate to PM for cross-role work; `agent-state:v1` is the mediation surface (ADR-025).

### P4 — Adapter (multi-registry)

Canonical `.agents/<role>.md` + thin overlays per platform; `050-agent-mirror.sh` enforces parity.

### P5 — Template Method (skeletal artifacts)

Fixed skeletons: plan/issue/PR/ADR templates, role overlay frontmatter.

### P6 — Facade (tool-specific entry points)

`CLAUDE.md`, `AGENT.md`, `AI_REPO_GUIDE.md`, `.github/copilot-instructions.md` — thin pointers to canonical contract.

### P7 — Owner-Keyed Concurrent State

Shared live-state keyed by owner (branch, role, issue/PR, comment marker); inverse of `AP6`. Canonical: `agent-state:v1` (ADR-025).

### P8 — Canonical Manifest with Generated Surfaces

Single canonical source; generated per-tool surfaces; CI stale-output checks. Shipped for roles (ADR-023); candidates for labels/budget vars.

### P9 — Multi-Model Plan Consensus

N independent candidate plans merged to one consensus plan; Judge plan-gate next (ADR-024). v1 vocabulary; no block-able `AP` companion yet.

---

## Anti-patterns to watch for

### AP1 — God Object

**Description**: one file accumulates many unrelated reasons to change; re-read cost and staleness grow with size.

**Detection signals** (any one flags; two warrants blocking): >5 distinct top-level concerns; >5 unrelated substantive edits in 90 days; version-canary in active use; end-to-end read >5 minutes.

**Block condition**: PR adds a new concern to an already-flagged God Object (currently `AGENTS.md`) without ADR justification.

---

### AP2 — Mirror Duplication

**Description**: same content in 2+ files kept identical by tests instead of generated from one source.

**Detection signals**: byte-identity tests between files; new instance requires manual copy; paired diffs routinely missed.

**Block condition**: PR adds a third mirror instead of factoring canonical source. Extensions to existing mirror sets need #248 reference in PR description.

---

### AP3 — Implicit Contract

**Description**: load-bearing precondition exists only in heads, not rules/types/tests (PM-001 generalized).

**Detection signals**: "everyone knows X first" with no encoded rule; implicit workflow ordering; new sessions fail same precondition; ADR names tribal knowledge without location.

**Block condition**: PR introduces behavior depending on unstated precondition.

---

### AP4 — Goal Substitution

**Description**: deliverable list satisfied but user outcome missed (PM-002 generalized).

**Detection signals**: user outcome describes files not actions; verification asserts existence not behavior; plan is build-list without observable end state.

**Advisory only**: Judge blocks when user outcome missing or clearly inverted.

---

### AP5 — Sequential Coupling

**Description**: procedure requires reading many files in order; agents skip steps in practice.

**Detection signals**: onboarding >~5 files before first edit; read list grows without removals; re-read cadence honored only on first task.

**Advisory only**: Judge blocks when PR materially extends canonical read list without ADR.

---

### AP6 — Single-Writer Shared State

**Description**: parallel agents write a single-writer schema with no owner partition (PM-003; inverse of `P7`).

**Detection signals**: new shared-state file without owner key; parallel workflow references single-writer file; conflict guidance lacks owner.

**Block condition**: PR adds/modifies concurrent-write surface with single-writer schema without ADR justification.

---

### AP7 — Magic String Sprawl

**Description**: labels/variables duplicated across files with no canonical manifest (`P8` is the structural fix).

**Detection signals** (any one flags; two warrants blocking): same ID in 3+ files without manifest; new label in one file without consumer updates; rename without paired updates; CI failure from string mismatch.

**Block condition**: PR introduces/removes/renames identifier without updating all consumers (tightens to manifest requirement once manifest exists).

---

### AP8 — Workflow-as-Application

**Description**: heavy logic embedded in workflow YAML — hard to test, reuse, or reason about.

**Detection signals**: workflow >~150 lines; 3+ substantive `if:` branches; hardcoded magic strings; postmortem traceable to YAML logic; review needs 2+ external context files.

**Advisory only**: Judge blocks on postmortem-caused YAML logic or material extension of flagged workflow without extraction.

---

### AP9 — Compatibility Surface Entrenchment

**Description**: replacement model accepted but deprecated compatibility surfaces remain active in normal work (ADR-025 tail before #368).

**Detection signals**: docs/workflows still route through deprecated surface; `legacy` surface has active automation; dual operational truths; new PRs extend deprecated surface.

**Block-able**: Judge blocks when PR retains/adds/extends deprecated compatibility surface as live normal-work dependency after replacement accepted. Historical ADR/postmortem refs are not the target.

---

## How to extend

New `P<n>` (structural choice → ADR) or `AP<n>` (always ADR for block conditions). Downstream projects may add domain-specific pattern files. Do not delete postmortem-derived entries without ADR.

Detail: [`docs/guides/repo-orchestration-patterns-reference.md`](../../docs/guides/repo-orchestration-patterns-reference.md).

## See also

- [`docs/guides/design-patterns.md`](../../docs/guides/design-patterns.md) — code-layer complement
- [`docs/decisions/adr-020-orchestration-patterns-reference.md`](../../docs/decisions/adr-020-orchestration-patterns-reference.md) — ratification ADR
- `.agents/critic.md`, `.agents/judge.md` — roles that cite this file
- `.context/rules/domain_code_quality.md` — `H*` / `S*` code-layer rules
