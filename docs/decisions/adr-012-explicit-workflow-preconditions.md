# ADR-012: Explicit workflow preconditions (branch-and-commit, cadence sharpening)

## Status

Accepted

## Date

2026-04-25

## Context

A real downstream incident in `mikejmckinney/cmmc-level2-aws-enclave-reference2` (a project bootstrapped from this template) had a single agent perform six full roadmap phases (Phases 2–7) directly on `main` with **zero commits, zero branches, zero issues, zero PRs**. The complete deliverables sat in the working tree. A Codespace restart, an accidental `git clean -fdx`, or any branch reset would have destroyed the work — and `terraform init` had left ~90 MB of provider binaries that *would* have been committed had the agent ever run `git add -A`.

Source: [postmortem-001-workflow-bypass.md](../postmortems/postmortem-001-workflow-bypass.md). Read that first; this ADR is the corrective decision it triggers.

The postmortem's diagnosis names two distinct root causes that both trace back to **implicit preconditions in `AGENTS.md`**:

1. **Branch precondition was inferred, not stated.** AGENTS.md described the workflow as "claim → implement → review → merge" but never said "you must be on a branch and commit before declaring a unit of work done." The word "branch" appeared four times, none as a precondition. Role files (`.github/agents/backend.agent.md`, `frontend.agent.md`) named their *branch naming convention* but didn't position branching as a gate.

2. **Session-state cadence rule was actively rationalized away.** The agent later explained *how* it skipped `_active.md` / `latest_summary.md` / handoff updates. Each rationalization mapped to a weakly-worded rule:
   - **Boundary collapse**: "rewrite at every task boundary" was read as "this whole multi-prompt session is one task." Fix: name `.github/prompts/NN-*.md` as the boundary unit.
   - **Scratch-surface substitution**: the agent used the LLM tool's in-conversation todo list and `/memories/session/plan.md` as working state. Both invisible to other sessions. Fix: explicitly mark scratch surfaces as "not substitutes for `.context/state/`."
   - **"Post-merge" deferral**: `latest_summary.md` close-out was tagged "post-merge," and the agent read this as "not my job until merge happens." Fix: replace with "session end OR task close-out, whichever comes first."
   - **Auto-summarization signal ignored**: the LLM runtime auto-summarized the conversation mid-flight (the loudest possible signal that the ~30-turn handoff threshold was exceeded), and the agent treated it as routine. Fix: name auto-summarization as an explicit handoff trigger.

The deeper pattern is shared across both root causes: **rules that depend on inferred convention will sometimes fail to fire**. The template's whole premise is that rules in files survive context shifts; expectations in heads do not.

This is also the first concrete pilot of the feedback-loop scenario described in #150 (downstream postmortem → template improvement).

## Decision

We will sharpen `AGENTS.md` to make the previously implicit preconditions explicit and cite-able, in two sections:

1. **§"Work style"** gains an explicit branch-and-commit precondition as the first bullet, with imperative phrasing ("you MUST"), a reference to the role-file branch-naming conventions, and a one-line "why explicit" pointer to the postmortem and this ADR.

2. **§"Session-state cadence"** is rewritten with all four sharpenings:
   - A preamble naming `.context/state/` as the only non-scratch surface for working state.
   - The `_active.md` bullet gains a sub-bullet defining `.github/prompts/NN-*.md` as a task boundary (so a multi-prompt session is multiple boundaries, not one).
   - The handoff-trigger bullet adds LLM auto-summarization as an explicit trigger alongside the ~30-turn and role-handoff triggers.
   - The close-out bullet replaces "post-merge" with "session end OR task close-out, whichever comes first" and explains the spirit of the rule (leave the next session a baton).

We do NOT add a `.context/rules/` companion file. The directory does hold universal process rules — `process_doc_maintenance.md` and `agent_ownership.md` are both precedents for "rule that applies to all work, lives in `.context/rules/`" — so categorical fit is not the reason. The reason is **size and load semantics**: this rule is one bullet, semantically inseparable from the surrounding §Work style guidance in AGENTS.md, and AGENTS.md is auto-loaded by every agent runtime (Copilot via `.github/copilot-instructions.md`, Claude Code via `CLAUDE.md`, etc.) while `.context/rules/` is lazy-loaded via `.context/00_INDEX.md`. For a rule that *must* fire on the first edit of a session, the auto-loaded surface is the right home, and a single bullet doesn't earn a separate file. Promote to `.context/rules/process_workflow_preconditions.md` (or merge into `process_doc_maintenance.md`) if this rule grows past ~5 bullets or accumulates exceptions worth tabulating.

We do NOT install a pre-commit hook by default in this ADR. That decision is sequenced as PR-B in #180 with its own ADR (ADR-013), because it requires a separate trade-off discussion (friction vs. blast-radius reduction) and shouldn't gate the rule-text fix.

## Options Considered

### Option 1: Status quo + better onboarding example

- **Pros**: zero file changes; banks on agents reading the multi-agent-coordination guide.
- **Cons**: the postmortem's evidence is exactly that the prior wording wasn't enough. "Read more carefully next time" is not a fix; it's a hope.

### Option 2: Add explicit precondition to AGENTS.md (chosen)

- **Pros**: lands in the file every agent reads first; cite-able from PR review and from agent self-correction; survives context shifts; addresses both root causes in one diff.
- **Cons**: makes AGENTS.md slightly longer (~15 lines added across two sections); the new wording must not contradict role-file branch-naming conventions (verified: it points at them rather than re-defining them).

### Option 3: Pre-commit hook + script-level enforcement (no rule-text change)

- **Pros**: mechanical, can't be argued away by the agent.
- **Cons**: doesn't address the postmortem's actual finding (the agent rationalized rules away even when explicit). Hook also doesn't help with cadence rules — `_active.md` updates aren't gateable mechanically. Hook is a useful *complement* but a poor *substitute*. Sequenced as PR-B / ADR-013.

### Option 4: Move the rule into role files instead of AGENTS.md

- **Pros**: closer to the role-specific ownership model.
- **Cons**: agents not in a named role (e.g., a fresh exploratory session) wouldn't read role files at all. AGENTS.md is the universal surface; the rule is universal.

## Consequences

### Positive

- Every repo bootstrapped from this template inherits the explicit rule. The downstream cmmc-level2-aws-enclave-reference2 incident scenario becomes mechanically harder to repeat.
- PR reviewers gain a cite-able rule to point at when an agent skips branching or session-state updates. "Per AGENTS.md §Work style bullet 1" is shorter than re-explaining why.
- The cadence sharpenings turn four separate "I rationalized this" failures into four pre-rejected reasonings. An agent reading the new text cannot reasonably collapse multiple prompts into one task or defer `latest_summary.md` until merge.
- The new wording plus the postmortem produce a working example of the #150 feedback loop: downstream incident → template improvement, in one cycle.

### Negative

- AGENTS.md grows by ~15 lines. The cadence section in particular is denser. Agents with shorter context budgets will spend slightly more onboarding tokens on rules.
- The "you MUST" phrasing is more prescriptive than the rest of AGENTS.md, which uses softer language. This is intentional (these are preconditions, not guidelines) but creates a small style inconsistency.
- Rule explicitness alone doesn't catch agents who skip onboarding entirely or who edit the file without updating downstream copies. Mitigation: PR-B (`.gitignore` + pre-commit hook) closes part of that gap; PR-C (`test.sh` + contributor docs) closes more.
- This ADR doesn't address the "agent never read AGENTS.md to begin with" failure mode. That requires either runtime gates (out of scope) or trust in the agent's onboarding discipline (current state).

### Verification

- `grep -n "MUST be on a non-default branch" AGENTS.md` returns one hit under §"Work style".
- `grep -n "prompts/NN-\*\.md" AGENTS.md` returns at least one hit under §"Session-state cadence".
- `grep -n "auto-summariz" AGENTS.md` returns at least one hit naming it as a handoff trigger.
- `grep -n "post-merge" AGENTS.md` returns no hits in the cadence section after this PR (the wording is fully replaced).
- `bash test.sh` passes with no regressions.
- `docs/postmortems/postmortem-001-workflow-bypass.md` exists and the README index has a row for it.

## References

- [postmortem-001-workflow-bypass.md](../postmortems/postmortem-001-workflow-bypass.md) — the trigger
- Source postmortem (downstream): https://github.com/mikejmckinney/cmmc-level2-aws-enclave-reference2/blob/recovery/phases-1-7-uncommitted-work/docs/postmortems/postmortem-001-workflow-bypass.md
- Issue #180 — tracking issue for this work (PR-A is this ADR + AGENTS.md edits + postmortem copy; PR-B and PR-C handle the remaining action items)
- Issue #150 — parent feedback-loop framework (this ADR is its first concrete instance)
- ADR-011 — plan-as-comment requirement (sets the precedent for "explicit beats inferred")
- ADR-005 — Analyst pre-flight gate (another "explicit precondition" ADR; same pattern)
- `AGENTS.md` §"Work style" — where the new branch precondition lands
- `AGENTS.md` §"Session-state cadence" — where the four sharpenings land
- `.github/agents/backend.agent.md`, `frontend.agent.md` — branch-naming conventions the new rule defers to
