# Repo Orchestration Patterns — Reference Guide

> **Purpose**: Long-form reference for the orchestration-layer pattern catalog. The normative contract (IDs, detection signals, block/advisory designations) lives in [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md). Read that file at review time; use this guide for "where it appears," remediation detail, and historical context.
>
> **Scope**: Multi-agent workflow, role definitions, rule files, gates, and coordination state in this template. Code-layer patterns for downstream projects live in [`design-patterns.md`](./design-patterns.md).

## Framing

This catalog is **descriptive, not prescriptive**. Pattern names borrow from Gang of Four where the analog is useful shorthand; **pattern naming is not the point** — shared vocabulary is.

Postmortem-derived entries (`AP3`, `AP4`, `AP6`, `P7`) cross-link to code-layer analogs in [`design-patterns.md`](./design-patterns.md): [`CAP2`](./design-patterns.md#cap2--implicit-contract), [`CAP1`](./design-patterns.md#cap1--goal-substitution), [`CP1`](./design-patterns.md#cp1--owner-keyed-concurrent-state).

---

## Patterns — reference detail

### P1 — Strategy (role specialization)

**Where it appears**:

- `.agents/{analyst,architect,backend,critic,devops,docs,frontend,judge,pm,qa}.md` — canonical strategy bodies (ADR-023)
- `.github/agents/<role>.agent.md`, `.claude/agents/<role>.md`, `.cursor/agents/<role>.md`, `.codex/agents/<role>.toml` — registration overlays
- Role selection: [ADR-031](../decisions/adr-031-agent-model-roi-benchmark-policy.md) (monolithic default); historical multi-role detail in this guide and `.agents/<role>.md`

**What good usage looks like**: each role file has one focused responsibility (`H1`); roles don't reach into each other's owned paths; cross-role coordination goes through PM (`P3`).

---

### P2 — Chain of Responsibility (pipeline)

**Where it appears**:

- `docs/guides/multi-agent-coordination.md` — canonical sequence (historical multi-role reference)
- `.agents/analyst.md` — Analyst pre-flight; [`docs/guides/agent-pipeline.md`](./agent-pipeline.md) — workflow gates
- `.agents/judge.md`, `.agents/critic.md` — review-stage handlers

**What good usage looks like**: each handler has clear pass/block criteria traceable to a rule file or ADR; new handlers added via ADR, not drive-by pipeline edits.

---

### P3 — Mediator (PM coordinates implementers)

**Where it appears**:

- `.agents/pm.md`, GitHub `agent-state:v1` comments (ADR-025) → Live-state protocol
- Latest `agent-state:v1` issue/PR comments (ADR-025)

**What good usage looks like**: implementers escalate to PM; claims are explicit in GitHub live state; PM holds edit privilege over another role's live-state baton.

---

### P4 — Adapter (multi-registry)

**Where it appears**:

- `.agents/<role>.md` canonical + four overlay trees
- `scripts/checks/050-agent-mirror.sh` — N-way `description:` parity and model allowlists

**What good usage looks like**: a fifth tool adds one overlay per role + one row in `050-agent-mirror.sh`; canonical bodies are never duplicated.

---

### P5 — Template Method (skeletal artifacts)

**Where it appears**: `.github/PLAN_TEMPLATE.md`, issue templates, PR template, `docs/decisions/adr-template.md`, role overlay frontmatter.

**What good usage looks like**: fill all skeleton sections (`N/A — <reason>` when inapplicable); skeleton changes via ADR.

---

### P6 — Facade (tool-specific entry points)

**Where it appears**: `AGENT.md`, `AI_REPO_GUIDE.md`, `.github/copilot-instructions.md`.

**What good usage looks like**: facades stay thin pointers; update in lockstep with canonical (`process_doc_maintenance.md` trigger table).

---

### P7 — Owner-Keyed Concurrent State

**Where it appears**: `agent-state:v1` comments; legacy `.context/state/` boards (compatibility examples); inverse of `AP6`.

**What good usage looks like**: explicit owner key and version marker; merge semantics explicit (`agent-state:v1` after ADR-025).

---

### P8 — Canonical Manifest with Generated Surfaces

**Where it appears**:

- Shipped: ADR-023 role canonical + thin overlays (#248, #330)
- Candidates: pipeline labels, budget variables, doc-sync triggers, PR-label state machine
- Conceptual: role files under `.agents/` and GitHub live-state claims (historical ownership table removed per ADR-031; restore from `origin/backup-2026-06-15` if needed)

**What good usage looks like**: one canonical source; generators in `scripts/`; pre-commit + CI stale-output checks; new consumers = one generator template.

**Caveats**: earns its keep at 3+ surfaces with frequent change. Hand-maintained thin overlays + parity check may be cheaper for low-change frontmatter-only diffs (#248 rejected generator for roles).

---

### P9 — Multi-Model Plan Consensus

**Where it appears**:

- [`.github/prompts/multi-model-consensus-plan.md`](../../.github/prompts/multi-model-consensus-plan.md)
- [`multi-model-consensus.md`](./multi-model-consensus.md)
- [ADR-024](../decisions/adr-024-multi-model-consensus-planning.md)

**What good usage looks like**: architectural/high-risk only; ≤3 candidates; isolated until posted; provenance preserved; Judge plan-gate next — never PM dispatch.

**Caveats**: v1 vocabulary only; no `AP<n>` companion yet. Promotion deferred until five high-stakes uses produce misuse evidence. No `synthesizer` role in v1 (#296).

---

## Anti-patterns — reference detail

### AP1 — God Object

**Currently triggered by**: `AGENTS.md` (~330+ lines, version-canary, 18+ concerns). Tracked in sub-issue 2 of epic #251.

**Remediation**: decompose by concern; top-level becomes thin contract + link table; ADR documents decomposition; re-evaluate version-canary after split.

---

### AP2 — Mirror Duplication

**Currently triggered by**: `.agents/<role>.md` ↔ overlays — `description:` byte-identical via `050-agent-mirror.sh`. ADR-023 resolved duplicated *body* problem.

**Remediation**: factor canonical source; generate per-platform files; replace byte-identity tests with stale-output tests (#248).

---

### AP3 — Implicit Contract

**Historically triggered by**: pre-ADR-012 phase progression (PM-001), pre-ADR-018 active-state schema (PM-003).

**Remediation**: codify in closest rule file, role file, or workflow `if:`; add CI check when enforceable.

---

### AP4 — Goal Substitution

**Historically triggered by**: `cloud_migration_POC` Prompts 1–6 (PM-002).

**Remediation**: rewrite user outcome and verification in DO-language; escalate to Architect if outcome can't be expressed.

---

### AP5 — Sequential Coupling

**Currently flagged**: onboarding + session-state cadence together specify ~7 files per task boundary (epic #251 sub-issues 2–3).

**Remediation**: shorten canonical read list; task-specific rules in focused files; narrower per-boundary re-read scope.

---

### AP6 — Single-Writer Shared State

**Historically triggered by**: pre-ADR-018 repo-local active-state schema (PM-003).

**Remediation**: owner-keyed redesign; see `P7` and ADR-025 `agent-state:v1`.

---

### AP7 — Magic String Sprawl

**Currently triggered by**: pipeline labels and budget variables hardcoded across `setup.sh`, workflows, docs, rules.

**Remediation**: YAML manifest under `.config/`; validate consumers; see `P8`.

---

### AP8 — Workflow-as-Application

**Currently flagged**: `agent-fix-reviews.yml`, `agent-multi-dispatch.yml`, `agent-relay-reviews.yml`, `auto-rebase-on-merge.yml` (partial extraction to scripts).

**Remediation**: workflows = event wiring; logic in `scripts/workflows/` or composite actions with tests.

---

### AP9 — Compatibility Surface Entrenchment

**Historically triggered by**: ADR-025 migration tail before #368 — GitHub live state canonical but repo-local compatibility surfaces still operational.

**Remediation**: retire, archive, or demote to generated/history view; stop teaching as peer to canonical model.

---

## How to extend

Downstream projects:

1. May add project-specific patterns in a separate `.context/rules/` file.
2. Should not delete entries without an ADR (postmortem-derived entries are load-bearing).
3. May tighten advisory entries to block-on-sight with an ADR amending block conditions.

New entries: next `P<n>` or `AP<n>` ID; include description, where it appears, detection signals, remediation, block-or-advisory designation. Structural pattern choices need an ADR; anti-pattern block conditions always need an ADR.

## See also

- `docs/decisions/` — ADRs ratifying structural choices
- `docs/postmortems/` — originating postmortems for `AP3`, `AP4`, `AP6`, `P7`
- `.context/rules/domain_code_quality.md` — code-layer `H*` / `S*` rules
- [ADR-020](../decisions/adr-020-orchestration-patterns-reference.md) — ratification of the pattern catalog
