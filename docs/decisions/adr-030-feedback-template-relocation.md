# ADR-030: Relocate feedback template to `.context/sessions/`

## Status

Accepted

Supersedes ADR-004 in part.

## Date

2026-05-24

## Context

ADR-004 introduced the stakeholder feedback template at `.context/state/feedback_template.md` when the template still treated `.context/state/` as the working area for task-state artifacts. ADR-025 later moved live coordination to GitHub issues, PRs, comments, and labels, while `.context/sessions/` became the in-tree home for durable lessons and retrospective material. The template itself is not live coordination state; leaving it under `.context/state/` now misclassifies it and creates onboarding drift across the context pack.

This ADR only changes the canonical location of the feedback template. It does not change the Analyst role, the optional feedback loop from ADR-004, or the ADR-025 live-state split.

## Decision

Move the canonical feedback template from `.context/state/feedback_template.md` to `.context/sessions/feedback_template.md`.

Treat copied stakeholder-feedback records as durable session artifacts, not live-state compatibility files. Update the path references, ADR status/index metadata, and any structure checks that enumerate the canonical location in the same change set.

## Options Considered

### Option 1: Keep the template under `.context/state/`

- **Pros**: No file move or follow-on path updates.
- **Cons**: Keeps a durable feedback template in the live-state compatibility directory and preserves the current doc drift.

### Option 2: Move the template to `.context/sessions/` (chosen)

- **Pros**: Aligns the template with durable feedback/session material and the ADR-025 split between live coordination and in-tree history.
- **Cons**: Requires coordinated updates to path references and inventory checks.

### Option 3: Move the template to `docs/` or `docs/research/`

- **Pros**: Keeps the template in a human-docs area.
- **Cons**: Separates the template from the context-pack/session workflow it supports and blurs whether copied feedback records are operational notes or reference docs.

## Consequences

### Positive

- The template location matches its purpose: durable feedback capture rather than live coordination.
- Onboarding and context-pack rules can point at one sessions-based path without explaining a state-directory exception.
- ADR-004's feedback-loop decision stays intact while the stale path moves out of the compatibility surface.

### Negative

- Any docs, rules, install/bootstrap steps, or inventory checks that still reference the old path must be updated in lockstep.
- Historical references in ADR-004 need an explicit partial-supersession note so readers do not mistake the original path for the current one.

### Neutral

- The Analyst role, feedback-loop behavior, and ADR-025 live-state schema do not change.
- Existing copied feedback records can remain as historical artifacts; this ADR only redefines the canonical template path.

## Implementation

- [x] Add this ADR and mark ADR-004 as superseded in part by ADR-030.
- [x] Update `docs/decisions/README.md` with the new ADR row and ADR-004 status.
- [x] Update architect-owned rule and role text that still points at the old template location.

## References

- ADR-004 — Analyst role and feedback loop
- ADR-025 — GitHub Issues, PRs, comments, and labels as live agent state
- Issue #328 — docs accuracy cleanup for stale feedback-template references
