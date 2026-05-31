# ai-repo-template Roadmap

> **Purpose**: Record the template repo's shipped phases, the current hardening track, and the next process gaps to close.

## Roadmap Principles

1. Dogfood the workflow in the template repo before asking downstream repos to trust it.
2. Prefer thin canonical contracts plus focused companion files over monolithic guidance.
3. Treat GitHub issues, PRs, comments, and labels as live state; keep repo-local state reference-only.
4. Pair every process claim with executable or sandbox verification.
5. Keep phases reversible: small rules, small prompts, small workflow changes.

## Current Phase

**Phase 7 - Template dogfooding, overlay extension, and process hardening**

The repo has already shipped the core multi-agent kit. Current work is about making the template prove its own rules in practice, tightening the review/merge loop, and reducing the remaining compatibility surfaces that can confuse downstream repos.

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
- `.context/**` is the canonical truth layer for repo rules and planning.
- The template has a durable ADR trail for process decisions.

---

## Phase 2: Problem Validation and Planning Gates

**Status**: Complete

**Objective**: Make planning explicit before implementation begins.

### Shipped Highlights
- Analyst became a required upstream validation role.
- Pre-flight and plan-as-comment gates were added.
- Workflow preconditions became explicit instead of tribal knowledge.

### Key Decisions
- ADR-004
- ADR-005
- ADR-011
- ADR-012
- ADR-014

### Acceptance Criteria Met
- Non-exempt implementation work starts from an issue-backed plan.
- Problem framing and solution framing are separate stages.

---

## Phase 3: Review Automation and Merge Controls

**Status**: Complete

**Objective**: Add safe automation around review resolution, verification, and merge behavior.

### Shipped Highlights
- Auto-merge stayed opt-in.
- Review-thread automation evolved from ADR-007 to ADR-008.
- Pre-merge verification and template-local pre-commit enforcement landed.

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
- Auto-rebase on merge handles soft overlaps.
- Owner-keyed live-state thinking evolved from repo-local files to GitHub-first coordination.

### Key Decisions
- ADR-009
- ADR-010
- ADR-018
- ADR-025

### Acceptance Criteria Met
- Roles have explicit ownership boundaries.
- Normal live coordination happens in GitHub issues, PRs, comments, and labels.

---

## Phase 5: Role Surfaces, Model Tiering, and Contract Hardening

**Status**: Complete

**Objective**: Make the role layer easier to maintain across tools and easier to audit.

### Shipped Highlights
- Per-role model tiering landed across supported platforms.
- `AGENTS.md` was decomposed into focused process rules.
- Top-level markdown scope split and canonical role bodies plus thin overlays shipped.
- ADR-026 added formal compliance evidence contracts.

### Key Decisions
- ADR-019
- ADR-021
- ADR-022
- ADR-023
- ADR-026

### Acceptance Criteria Met
- Canonical role bodies live in one place.
- Parent/subagent compliance evidence has a stable schema.

---

## Phase 6: Feedback, Patterns, and Higher-Order Planning

**Status**: Complete

**Objective**: Improve how the template learns from work and how it evaluates complex planning.

### Shipped Highlights
- Postmortem capture/mirror workflow landed.
- The orchestration patterns reference became part of Critic/Judge review vocabulary.
- Multi-model consensus planning shipped as an opt-in path.
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

**Status**: In Progress

**Objective**: Close the gap between what the template prescribes and what the template itself demonstrates.

### Active Track
- Dogfood `.context/**` in the template repo itself so agents stop reading placeholder context in normal template work.
- Finish the multi-platform overlay extension and associated cleanup under issue #327.
- Harden the `pr-resolve-all` / merge loop under issue #321.
- Continue draining repo-local compatibility references that can make ADR-025 look optional.

### Current Deliverables
- Populate `.context/00_INDEX.md`, `.context/roadmap.md`, and `.context/vision/README.md` with real template content.
- Add architecture diagrams for multi-agent flow and live-state surfaces.
- Keep Mode B onboarding explicit by restoring those files from a canonical stub source in `.github/prompts/repo-onboarding.md`.
- Keep the reset rule explicit in `.context/rules/process_template_detection.md` after the live template files lose their bootstrap placeholder markers.

### Exit Criteria
- The template repo demonstrates its own lazy-load context pattern.
- A fresh derived repo still resets to generic stubs during Mode B onboarding.
- The review/merge loop remains explicit, verifiable, and human-auditable.

---

## Watchlist After Phase 7

- Issue #279 - extract more machine-readable manifests and move logic out of workflow YAML where appropriate.
- Issue #322 - add a clearer new-project playbook and parent/phase issue templates.
- Continue pruning documentation or reference surfaces that still imply repo-local live state.

## How to Update This Roadmap

1. Advance a phase only when the linked ADRs or issue slices are actually merged.
2. Keep active work tied to concrete issue numbers rather than generic intentions.
3. When a phase changes coordination rules, update the relevant `.context/vision/architecture/*.md` diagram in the same PR.
