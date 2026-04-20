# ADR-005: Analyst Pre-Flight Gate for Project Prompts

## Status

Accepted

## Date

2026-04-20

## Context

The template's multi-agent pipeline added an Analyst role in ADR-004 to
validate problems before solution design. However, a closely related failure
mode was not addressed: prompt files under `.github/prompts/` that describe
deliverables (pages, components, files) without specifying the user outcome
those deliverables are intended to produce.

Agents implement deliverable-focused prompts competently and can still ship
the wrong artifact. For example, a prompt that says "build 6 React pages
covering architecture, pipeline, and security" may be implemented correctly
as a static presentation, when the underlying goal was a live interactive
demo that clients could experience. Automated code review catches code
quality issues; it does not catch scope mismatch between deliverables and
intended user outcomes.

This failure mode is cheapest to catch before implementation begins, when
the only cost is the Analyst reading the prompt and posting a structured
report. Catching it post-implementation requires rework of potentially the
entire artifact.

Additionally, the existing role definition in `.github/agents/analyst.agent.md`
was updated to add this validation capability. Per `.context/rules/agent_ownership.md`
(Shared / Contested Files), changes to `.github/agents/**` are supposed to
be accompanied by an ADR. This record fulfils that requirement.

## Decision

We will add a mandatory "Analyst Pre-Flight" gate that applies to any issue
referencing a numbered project prompt file (matching the `NN-*.md` convention
under `.github/prompts/`, where `NN` is a two-digit number prefix such as
`01`, `05`).

### Scope of the gate

**In scope** (gate applies):
- Project prompt files whose basenames follow the `NN-*.md` convention
  (e.g., `01-init-project.md`, `05-portfolio-demo-app.md`).
- Prompts that describe a deliverable: a UI, a service, a pipeline, a
  dataset, anything interactive or operational.

**Out of scope** (gate does NOT apply):
- Shared procedural prompts (`pr-resolve-all.md`, `repo-onboarding.md`,
  `copilot-onboarding.md`, `expand-backlog-entry.md`) — these describe
  agent procedures, not project deliverables, and have their own
  verification.
- Prompt documentation (`README.md`) under `.github/prompts/`.
- Simple bug fixes, dependency bumps, typo corrections, doc edits, and
  ad-hoc issues with no referenced prompt file.

### The validation procedure (15-minute test)

The Analyst posts a **Pre-Flight Report** on the issue before Architect
starts work. The report answers one question:

> If the intended audience spent 15 minutes with the final deliverable,
> would they *experience* the outcome, or would they *read about* it?

The Analyst then assigns one of three verdicts:

- **PASS** — the prompt specifies a clear user outcome; hand off to
  Architect.
- **FAIL: scope mismatch** — the prompt describes deliverables but the
  implied outcome is operational; rewrite before implementation.
- **HOLD: clarification needed** — resolve named ambiguities before
  proceeding.

Implementation must not proceed without a PASS verdict.

### Changes to role definitions

The following role definition files are updated as part of this decision:

- `.github/agents/analyst.agent.md` — adds "Prompt Pre-Flight Validation"
  section with the 15-minute test, criteria, and report template.
- `.github/agents/judge.agent.md` — adds a PLAN-GATE hard requirement:
  BLOCK if a Pre-Flight Report is missing for a prompt-referenced issue.
- `.github/agents/critic.agent.md` — adds "Outcome mismatch" as a major
  concern for DIFF-GATE review.
- `.github/copilot-instructions.md` and `AGENTS.md` — updated to require
  Copilot and all agents to run (or check for) the pre-flight report before
  implementing from a project prompt.

Both canonical (`.github/agents/*.agent.md`) and mirror
(`.claude/agents/*.md`) files must be updated in lockstep per ADR-003.
The `description:` frontmatter must remain byte-identical between mirrors,
enforced by `test.sh`.

## Options Considered

### Option 1: Analyst Pre-Flight gate (chosen)

- **Pros**: Catches scope mismatch before any implementation work begins.
  Cheap — only the Analyst reads the prompt. Structured report creates an
  audit trail for Judge to verify. Gate is optional for procedural prompts,
  so it doesn't add friction to the most common task types.
- **Cons**: Adds a mandatory step for project-prompt issues. Analyst must
  be dispatched (or Copilot must run the analysis inline) before work
  begins — minor latency for project kicks-off.

### Option 2: No gate — rely on existing Judge diff-gate

- **Pros**: No process change.
- **Cons**: The diff-gate happens after implementation. Catching scope
  mismatch at that point requires reworking the entire artifact. Code review
  tools do not flag "correct implementation of the wrong thing."

### Option 3: Rewrite all project prompts to include outcome sections

- **Pros**: Bakes the outcome into the source material.
- **Cons**: Doesn't help prompts that already exist or prompts authored
  without the template. Requires author discipline, not a process gate.
  Doesn't prevent future scope-mismatched prompts from being written.

## Consequences

### Positive

- Scope mismatch is caught at the cheapest possible point — before
  implementation.
- The Pre-Flight Report creates a structured audit trail that Judge can
  verify during plan-gate and diff-gate.
- Authors of new project prompts receive early feedback if their prompt
  specifies deliverables without outcomes.
- The gate is scoped narrowly (numbered project prompts only), avoiding
  friction on procedural prompts and ad-hoc issues.

### Negative

- Adds a mandatory step to the project-prompt workflow. Teams must
  remember to dispatch Analyst (or let Copilot do it inline) before
  implementation can begin.
- Analyst (or Copilot acting as Analyst) must read the prompt and produce
  a report — small but non-zero overhead for every project kick-off.

### Neutral

- Existing workflows for procedural prompts, bug fixes, and ad-hoc issues
  are completely unaffected.
- The Analyst's existing research responsibilities (needs analysis,
  competitive research, impact scoring) are unchanged.

## Implementation

- [x] Update `.github/agents/analyst.agent.md` — add "Prompt Pre-Flight
  Validation" section with criteria, 15-minute test, and report template.
- [x] Update `.github/agents/judge.agent.md` — add Pre-Flight Report as a
  PLAN-GATE hard requirement; scope the gate to `NN-*.md` project prompts.
- [x] Update `.github/agents/critic.agent.md` — add "Outcome mismatch"
  concern for DIFF-GATE.
- [x] Update `.github/copilot-instructions.md` — add pre-flight procedure
  for Copilot agents.
- [x] Update `AGENTS.md` — add Analyst pre-flight gate section.
- [x] Create `.github/prompts/README.md` — document project vs. procedural
  prompt distinction.
- [x] Create this ADR.

## References

- ADR-004 — Add Analyst role and agile feedback loop
- ADR-003 — Claude Code subagent registration (pattern for role file updates)
- `.context/rules/agent_ownership.md` — Shared / Contested Files (`.github/agents/**`)
- `.github/agents/analyst.agent.md` → "Prompt Pre-Flight Validation"
