# ai-repo-template Roadmap

> **Purpose**: Record the template repo's shipped phases and the issue-backed
> process gaps that remain after the initial hardening program.

## Roadmap Principles

1. Dogfood the workflow in the template repo before asking downstream repos to trust it.
2. Prefer thin canonical contracts plus focused companion files over monolithic guidance.
3. Treat GitHub issues, PRs, comments, and labels as live state; keep repo-local state reference-only.
4. Pair every process claim with executable or sandbox verification.
5. Keep phases reversible: small rules, small prompts, small workflow changes.

## Program Status

**Phases 1-7 complete.**

The template now dogfoods its context, onboarding, monolithic implementation,
parallel advisory review, recurring retro, and GitHub-backed live-state model.
Further work is tracked by concrete GitHub issues rather than an open-ended
phase label.

---

## Phase 1: Context Pack and Core Contract Foundation

**Status**: Complete

**Objective**: Establish the base repo shape and the canonical context/rule surfaces.

### Shipped Highlights
- `.context/**` structure and lazy-load pattern established.
- `AGENTS.md` became the root agent contract.
- ADR discipline and template repo governance patterns were set up.

### Key Decisions
- ADR-001
- ADR-002

### Acceptance Criteria Met
- `.context/**` established canonical project direction and planning beneath
  the always-loaded `AGENTS.md` operating contract.
- The template has a durable ADR trail for process decisions.

---

## Phase 2: Problem Validation and Planning Gates

**Status**: Complete

**Objective**: Make planning explicit before implementation begins.

### Shipped Highlights
- Analyst and pre-flight roles established the historical validation model,
  later replaced by the risk-based problem-framing gate in ADR-031.
- Issue-backed plans and explicit planning gates were added.
- Workflow preconditions became explicit instead of tribal knowledge.

### Key Decisions
- ADR-004
- ADR-005
- ADR-011
- ADR-012
- ADR-014

### Acceptance Criteria Met
- Non-exempt implementation work starts from an issue-backed plan.
- Problem framing remains distinct from implementation when risk or ambiguity
  warrants it; mandatory role handoffs are retired.

---

## Phase 3: Review Automation and Merge Controls

**Status**: Complete

**Objective**: Add safe automation around review resolution, verification, and merge behavior.

### Shipped Highlights
- Auto-merge stayed opt-in.
- Review-thread automation evolved from ADR-007 to ADR-008.
- Pre-merge verification and explicit local formatting commands landed; CI
  remains the blocking lint surface.

### Key Decisions
- ADR-006
- ADR-007
- ADR-008
- ADR-016
- ADR-017

### Acceptance Criteria Met
- Review automation is label-gated and explicit.
- The template repo verifies shell/workflow hygiene locally and in CI.

---

## Phase 4: Parallel Multi-Agent Coordination

**Status**: Complete

**Objective**: Make parallel agent work safe enough to use on real issues.

### Shipped Highlights
- Parallel-dispatch patterns and overlap reporting landed.
- Auto-rebase was trialed and later retired; branch owners now update their own
  branches.
- Owner-keyed live-state thinking evolved from repo-local files to GitHub-first coordination.

### Key Decisions
- ADR-009
- ADR-010
- ADR-018
- ADR-025

### Acceptance Criteria Met
- Historical role ownership informed the current single-implementer model.
- Normal live coordination happens in GitHub issues, PRs, comments, and labels.

---

## Phase 5: Role Surfaces, Model Tiering, and Contract Hardening

**Status**: Complete

**Objective**: Make the role layer easier to maintain across tools and easier to audit.

### Shipped Highlights
- Per-role model tiering and role registries landed, then were retired by
  ADR-031 after the ROI benchmark favored one implementing agent.
- `AGENTS.md` was decomposed into focused process rules, then reassembled as
  the always-loaded contract when ADR-031 retired mandatory role surfaces.
- Top-level markdown scope split and canonical role bodies plus thin overlays shipped.
- ADR-026 added formal compliance evidence contracts, later retired in favor of
  simpler native evidence.

### Key Decisions
- ADR-019
- ADR-021
- ADR-022
- ADR-023
- ADR-026

### Acceptance Criteria Met
- The historical role and compliance experiments have durable decision records.
- Active guidance no longer depends on retired registries or compliance schemas.

---

## Phase 6: Feedback, Patterns, and Higher-Order Planning

**Status**: Complete

**Objective**: Improve how the template learns from work and how it evaluates complex planning.

### Shipped Highlights
- Postmortem capture/mirror workflow landed.
- The orchestration patterns reference became shared review vocabulary that
  remains available without retired Critic/Judge roles.
- Multi-model consensus evolved into the current explicit OpenCode skill.
- Opportunity feedback and sandbox dogfood evidence were added.

### Key Decisions
- ADR-015
- ADR-020
- ADR-024
- ADR-027
- ADR-029

### Acceptance Criteria Met
- The template records durable lessons without widening in-scope work.
- High-risk planning and user-outcome claims have stronger evidence paths.

---

## Phase 7: Template Dogfooding and Process Hardening

**Status**: Complete

**Objective**: Close the gap between what the template prescribes and what the template itself demonstrates.

### Shipped Highlights
- Populated `.context/00_INDEX.md`, this roadmap, and
  `.context/vision/README.md` with template-specific evidence.
- Replaced repo-local live task state with GitHub issue/PR coordination and a
  reference-only `.context/state/` surface.
- Retired role-pipeline compatibility under issue #474 and ADR-031.
- Added explicit `template-seed` lifecycle state and evidence-based onboarding
  without forced marker replacement.
- Made rolling advisory review normal, non-blocking agent practice.
- Removed unused operational scaffolding and made product design context
  conditional on verified UI work.

### Exit Criteria
- The template repo demonstrates its own lazy-load context pattern.
- A fresh derived repo receives `template-seed` state and adapts resources from evidence.
- The review/merge loop remains explicit, verifiable, and human-auditable.

---

## Issue-Backed Future Work

- Issue #163 - automate derived-repository credential and variable bootstrap.
- Issue #299 - define session archive retention and downstream reset policy.
- Issue #316 - document sandbox-local verification for default-branch workflow changes.
- Issue #322 - add an optional cross-repository project bootstrap skill.

## How to Update This Roadmap

1. Add another phase only when multiple accepted issues share one measurable
   outcome; otherwise keep work issue-backed.
2. Keep active work tied to concrete issue numbers rather than generic intentions.
3. When work changes coordination rules, update the relevant
   `.context/vision/architecture/*.md` diagram in the same PR.
