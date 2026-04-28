# ADR-014: Extend Analyst Pre-Flight Gate to Ad-Hoc Deliverable Issues

## Status

Accepted

## Date

2026-04-28

## Context

ADR-005 introduced an Analyst Pre-Flight gate that catches a specific
failure mode: prompts that describe deliverables (pages, components,
files) without specifying the user outcome those deliverables are
intended to produce. The gate was scoped narrowly to issues that
reference a numbered project prompt under `.github/prompts/NN-*.md`.

In practice, the same failure mode occurs on issues that do **not**
reference a prompt file:

- **Ad-hoc feature issues** opened directly in the GitHub UI ("Add a
  Snowflake admin dashboard" with a bullet list of pages and no stated
  user outcome).
- **Chat-originated issues** entered via an agent conversation, which
  capture deliverables faster than they capture outcomes.
- **ADRs proposing new agent surfaces** (a new role, a new webhook, a
  new automation mode) — the deliverable is the ADR document itself,
  but the operational outcome it implies is frequently left implicit
  and only surfaces during PR review or after the surface ships.

These bypass ADR-005's gate today. The implementer reads a deliverable
list, executes it competently, and ships an artifact that may not match
the underlying goal. Automated review catches code quality; it does not
catch "shipped the wrong artifact."

This is a scope gap in the original gate, not a new failure mode. The
15-minute test, Pre-Flight Report template, and Judge PLAN-GATE BLOCK
mechanism from ADR-005 all apply unchanged — only the trigger criteria
need to broaden.

## Decision

Extend the Analyst Pre-Flight gate to fire on any issue proposing a
novel user-facing deliverable, regardless of whether a numbered prompt
file is referenced.

### Trigger criteria (any one signal is sufficient)

The gate fires when the issue meets any of these:

1. Issue uses `feature_request.md` template **and** carries the
   `enhancement` label.
2. Issue is an ADR proposing a new agent surface — a new role, a new
   webhook, a new external interface, a new automation mode, or any
   other surface that other agents/users will interact with.
3. Issue body contains action verbs (build, implement, ship, create)
   combined with a user-facing noun (UI, dashboard, page, service,
   pipeline, dataset, demo, integration).

The original ADR-005 trigger (issue references a `.github/prompts/NN-*.md`
project prompt) is preserved as a fourth signal.

### Opt-out

The gate can be opted out of by:

- Adding the `outcome-validated` label to the issue, **and**
- Including an inline outcome paragraph in the issue body (one paragraph
  describing what a user will be able to *do* when this is shipped, not
  just what files will exist).

This pattern (label + inline content) prevents the label from being
applied as a rubber stamp. Reviewers can verify the inline outcome
when the label is present.

### Exemptions (gate does NOT fire, no opt-out needed)

- `bug` label — bug reports define the outcome implicitly (the bug
  stops happening).
- `docs` label with no new behavior.
- `dependencies` label (Renovate, Dependabot).
- Reverts.
- `chore:*` labels (including the existing `chore:no-plan`).
- Internal refactors with no user-facing change.

### Procedure

Identical to ADR-005:

1. Author or implementer checks the issue for an existing Pre-Flight
   Report comment with verdict PASS.
2. If none exists and the gate applies (per trigger above, no opt-out),
   the Analyst is dispatched (or the implementer runs the analysis
   inline per `.github/agents/analyst.agent.md` → "Pre-Flight
   Validation").
3. Implementation does not begin until verdict PASS is recorded.
4. Judge BLOCKs at PLAN-GATE if the report is missing or has verdict
   FAIL/HOLD.

### Enforcement

v1 remains self-applied + Judge BLOCK at PLAN-GATE. No new CI workflow.
Automated enforcement is deferred to issue #155, which already tracks
plan-as-comment automation and will subsume pre-flight automation in
the same effort.

## Options Considered

### Option 1: Extend the trigger (chosen)

- **Pros**: Closes the scope gap with the same mechanism that already
  works. No new infrastructure. Self-applied + Judge BLOCK matches the
  existing model. Authors can opt out cleanly with `outcome-validated`
  + inline outcome paragraph.
- **Cons**: Heuristic trigger criteria require the implementer (or
  Judge) to recognize when the gate applies. False positives possible
  on small features with self-evident outcomes — mitigated by opt-out.

### Option 2: Auto-apply to every `enhancement` issue, no opt-out

- **Pros**: Mechanically simple. No judgment required.
- **Cons**: High false-positive rate on small features with self-evident
  outcomes. `postmortem-001-workflow-bypass.md` documents the pattern
  where over-applied gates start being silently bypassed; a no-opt-out
  rule would reproduce that failure here.

### Option 3: Heuristic-based bot detection (CI parses issue bodies)

- **Pros**: Removes the judgment step from implementers.
- **Cons**: Adds CI complexity for v1; the Analyst's role IS exactly
  this kind of judgment. Defer to #155 alongside other gate automation.

### Option 4: Require explicit `needs-preflight` opt-in label

- **Pros**: No false positives — only issues marked as such trigger.
- **Cons**: Opt-in labels get forgotten. Defaulting to "gate fires" +
  opt-out is the safer behavior; an unforgotten opt-in label is
  worth less than a defaulted-on gate.

### Option 5: Exclude ADRs from scope

- **Pros**: ADRs already get PR review.
- **Cons**: ADR review is exactly where outcome questions get lost —
  the deliverable (the ADR document) is approved before the operational
  outcome it implies is validated. The gate is cheapest on ADRs because
  there is no implementation to undo yet.

### Option 6: New ADR-014 vs. amending ADR-005 in place

Chose new ADR. Preserves audit trail; follows the precedent of ADR-008
amending ADR-007. ADR-005 gets `Status: Superseded in part by ADR-014`
in the same PR.

## Consequences

### Positive

- Scope gap closed. Ad-hoc feature issues and ADRs proposing new agent
  surfaces no longer bypass the gate.
- Mechanism is identical to ADR-005 — no new infrastructure, no new
  roles, no new CI workflow.
- Opt-out is explicit (`outcome-validated` label + inline outcome
  paragraph), so authors who genuinely have a clear user outcome are
  not blocked by ceremony.
- ADRs proposing new agent surfaces get the same outcome scrutiny that
  project-prompt issues get today, catching scope mismatch before the
  surface ships.

### Negative

- Heuristic trigger requires implementer judgment ("does my issue
  qualify?"). Mitigated by clear exemption labels and the inline
  outcome section in the issue templates.
- Risk of over-application friction. Mitigated by the opt-out pattern
  and bug/docs/chore exemptions. If >50% of feature issues need
  explicit opt-out in the first 10 issues post-merge, narrow the
  trigger via follow-up ADR.
- Two trigger surfaces (this ADR + ADR-005's NN-*.md) until they
  converge in a unified gate per #155.

### Neutral

- Existing project-prompt workflow (ADR-005's original trigger) is
  unaffected. The gate continues to fire on `.github/prompts/NN-*.md`
  references with the existing behavior.
- Bug fixes, doc edits, dependency bumps remain exempt as before.
- The Analyst's existing research responsibilities (needs analysis,
  competitive research, impact scoring) are unchanged.

## Implementation

- [x] Create this ADR.
- [x] Update `docs/decisions/adr-005-analyst-preflight-gate.md`
  `Status` line to `Superseded in part by ADR-014`.
- [x] Register ADR-014 in `docs/decisions/README.md`.
- [x] Update `.github/agents/analyst.agent.md` — rename "Prompt
  Pre-Flight Validation" section to "Pre-Flight Validation" and
  broaden the "When required" / "When NOT required" lists.
- [x] Update `.github/agents/judge.agent.md` — extend the PLAN-GATE
  trigger bullet so the gate also fires on ad-hoc deliverable
  issues lacking the `outcome-validated` label.
- [x] Update `AGENTS.md` "Analyst pre-flight gate" section to reflect
  the broadened scope.
- [x] Update `.github/copilot-instructions.md` to mirror the
  `AGENTS.md` change.
- [x] Update `.github/ISSUE_TEMPLATE/feature_request.md` — add a
  "User outcome (15-minute test)" section so authors can pre-empt
  the gate inline.
- [x] Update `.github/ISSUE_TEMPLATE/agent_init.md` — same section.
- [x] Create the `outcome-validated` GitHub label in the repo.
- [x] Verify `bash test.sh` passes (current baseline 210/0/1).

## References

- **Supersedes ADR-005 in part** — broadens the trigger criteria; the
  15-minute test, report template, and Judge PLAN-GATE BLOCK mechanism
  from ADR-005 remain in force unchanged.
- ADR-005 — Analyst Pre-Flight Gate for Project Prompts (the original
  gate this ADR extends).
- ADR-011 — Plan-as-comment requirement (universal complement to
  pre-flight; same v1 enforcement model).
- ADR-008 — Phase 4 default (precedent for an ADR amending a prior ADR
  rather than rewriting it in place).
- ADR-003 — Claude Code subagent registration (mirror invariant for
  role file updates).
- `docs/postmortems/postmortem-001-workflow-bypass.md` — over-applied
  gates failure mode that motivates the opt-out design.
- Issue #155 — Pre-flight + plan-as-comment automation (deferred CI
  enforcement).
- Issue #201 — This decision.
