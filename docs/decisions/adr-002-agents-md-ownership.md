# ADR-002: AGENTS.md is owned by the Architect role

## Status

Accepted

## Date

2026-04-13

## Context

`AGENTS.md` is the root-level canonical agent-instruction file in this template. It contains the truth hierarchy, role selection, onboarding procedure, testing requirements, and review guidelines — the process rules that bind every role. Tools that auto-read `AGENTS.md` from the repo root (Claude Code, Copilot, Cursor, Gemini) depend on it being both stable and authoritative.

Across Rounds 1–5 of the multi-agent template evolution, `AGENTS.md`'s role-ownership assignment drifted:

- **Round 1**: placed in the Shared/Contested table under "Coordinated by: PM" — the heuristic was *"rules that bind everyone → PM arbitrates."*
- **Rounds 2–5**: every substantive edit to `AGENTS.md` (adding the Critic role, adding the role-selection block, adding the template-detection guard for `CLAUDE.md`) was authored by whichever session implemented the round. PM never dispatched or arbitrated a single edit.
- **Subsequent review commits**: the ownership row was promoted from Shared/Contested into PM's main owned-paths row, making nominal ownership formal.

The promotion surfaced the latent question: *should* PM own `AGENTS.md`, or should a different role? PM's nominal ownership did not match who actually edits the file, and the template repo is a starting point for downstream forks, so the assignment needs to teach the right mental model.

## Decision

**`AGENTS.md` is owned by the Architect role.**

- Added to `.github/agents/architect.agent.md` `owned_paths`.
- Added to the Architect row of the main Ownership Table in `.context/rules/agent_ownership.md`.
- Removed from the PM row of the Ownership Table.
- Removed from the Shared/Contested table (Architect owns it outright; cross-role edits go through the standard cross-role protocol via PM).
- `CLAUDE.md` and `AGENT.md` remain Docs-owned because they are ~12-line redirect pointers containing no rules — they route readers at `AGENTS.md` but don't duplicate its content.

Structural changes to `AGENTS.md` (new role, new gate, new review step, new testing requirement) originate from the Architect directly, consistent with Architect's existing ownership of `docs/decisions/**`, `.context/roadmap.md`, `.context/vision/architecture/**`, and `.context/rules/**`.

## Options Considered

### Option 1: PM owns (status quo before this ADR)
- **Pros**: "coordination-role owns coordination-rules file" is an appealing one-liner; PM already owns `agent_ownership.md`, which is adjacent.
- **Cons**: PM's role is *dispatching work and claiming locks*, not *authoring stable rules*. In practice no PM dispatch ever preceded an edit to `AGENTS.md`. Keeps one rules file under a non-Architect role for reasons that don't generalize. Downstream forks would inherit a confusing exception.

### Option 2: Docs owns
- **Pros**: Groups all top-level `.md` files (`README.md`, `AI_REPO_GUIDE.md`, `CLAUDE.md`, `AGENT.md`, `AGENTS.md`) under one role. Eliminates the pointer/target split where CLAUDE.md and AGENT.md are Docs-owned but their target is not.
- **Cons**: Puts Docs in the position of authoring process rules, which is Architect work (new roles, new review gates, new state transitions). Contradicts the existing pattern where every other rules file (`.context/rules/**`, `docs/decisions/**`, `.context/roadmap.md`) is Architect-owned. Creates the opposite inconsistency — one rules file split off from the others.

### Option 3: Architect owns (chosen)
- **Pros**: Matches the semantic category — `AGENTS.md` is process rules, Architect owns process rules. Consistent with `.context/rules/**`, `docs/decisions/**`, and `.context/roadmap.md` all being Architect-owned. Downstream forks see a clean three-way split: Architect → rules/decisions/roadmap; Docs → human-facing prose and pointer files; PM → live state and the ownership map.
- **Cons**: Creates a minor pointer/target split — `CLAUDE.md` and `AGENT.md` pointers are Docs-owned but their target `AGENTS.md` is Architect-owned. Mitigated by the fact that the pointers contain zero rules and rarely need coordinated updates (the pointers change only when `AGENTS.md`'s top-level section layout shifts, which is rare).

## Consequences

### Positive

- **Consistent mental model**: All rules files live under one role. New agents and downstream forks learn one pattern instead of memorizing an exception.
- **Author-owner alignment**: The role that actually edits `AGENTS.md` (Architect, when adding roles or process rules) also formally owns it.
- **ADR discoverability**: Structural changes to `AGENTS.md` now naturally flow through the ADR process Architect already uses for other rules files.
- **Plan-only constraint preserved**: Architect's "no implementation code" rule applies to source code, not rules files. Architect already writes `.context/rules/**` and ADRs directly; `AGENTS.md` fits the same pattern.

### Negative

- **Pointer/target split**: `CLAUDE.md` and `AGENT.md` (Docs-owned) point at `AGENTS.md` (Architect-owned). Updates that ripple from the target to the pointers require a cross-role claim. In practice, pointer files change only when `AGENTS.md`'s top-level headers change, which is infrequent.
- **One-time churn**: This ADR, `architect.agent.md`, and `agent_ownership.md` must be updated in lockstep. Subsequent drift will be caught by `./test.sh` file-existence checks but not by ownership-map consistency checks.

### Neutral

- PM retains ownership of `.context/state/**` and `.context/rules/agent_ownership.md`. PM's coordination duties are unchanged — they still arbitrate cross-role conflicts, including ones involving `AGENTS.md`.
- Docs retains ownership of `CLAUDE.md`, `AGENT.md`, `README.md`, `AI_REPO_GUIDE.md`, and `docs/**`. The pointer files remain Docs-owned because they are routing artifacts, not rules.

## Implementation

- [x] Add `AGENTS.md` to `.github/agents/architect.agent.md` `owned_paths`
- [x] Add `AGENTS.md` to the Architect row of the Ownership Table in `.context/rules/agent_ownership.md`
- [x] Remove `AGENTS.md` from the PM row of the Ownership Table
- [x] Remove `AGENTS.md` from the Shared/Contested table
- [x] Record this ADR as the durable rationale
- [x] Verify `./test.sh` still passes

## References

- `.context/rules/agent_ownership.md` — Ownership Table and Shared/Contested tables updated by this ADR
- `.github/agents/architect.agent.md` — Architect's `owned_paths` frontmatter updated by this ADR
- `.github/agents/pm.agent.md` — unchanged; PM's `owned_paths` frontmatter never included `AGENTS.md`
- ADR-001 — context pack structure precedent for Architect-owned rules files
