# ADR-NNN: [Title]

<!-- 
Architecture Decision Record Template
Copy this file and rename to adr-NNN-short-title.md

Numbering: Use sequential numbers (adr-001, adr-002, etc.)
Title: Short, descriptive title of the decision
-->

## When to write a new ADR

Write a new ADR (don't edit an existing one in place) whenever:

- A previously documented decision changes — even partially. Mark the old ADR `Status: Superseded by ADR-NNN` and add a new ADR explaining what changed and why.
- A decision is deprecated (we no longer want to do it this way, but no replacement exists yet). Set the old ADR's `Status: Deprecated` and explain in the body.
- The scope of an existing decision expands enough that the rationale no longer fits the original "Context" section.
- A new constraint or trade-off appears that the original ADR didn't consider.

Don't write a new ADR for: typo fixes, prose tightening of an existing ADR, or expanding a verification block in place. Edit the existing file.

Supersession discipline (Judge enforces this at diff-gate — see `.context/rules/process_doc_maintenance.md`):

- The new ADR's `Status` line reads `Accepted` (or `Proposed` initially) and includes a `Supersedes ADR-XXX` reference somewhere in the body (typically in Context or References).
- The old ADR's `Status` line is updated to `Superseded by ADR-NNN` in the **same PR**. Never leave the supersession dangling in a follow-up.

## Status

<!-- One of: Proposed | Accepted | Deprecated | Superseded by ADR-XXX -->

Proposed

## Date

<!-- Date the decision was made or last updated -->

YYYY-MM-DD

## Context

<!-- 
What is the issue that we're seeing that is motivating this decision or change?
What are the constraints and forces at play?
-->

[Describe the context and problem statement here]

## Decision

<!-- 
What is the change that we're proposing and/or doing?
Be specific and actionable.
-->

We will [describe the decision here].

## Options Considered

<!-- 
What alternatives were considered? 
List at least 2-3 options with brief pros/cons.
-->

### Option 1: [Name]
- **Pros**: 
- **Cons**: 

### Option 2: [Name]
- **Pros**: 
- **Cons**: 

### Option 3: [Name]
- **Pros**: 
- **Cons**: 

## Consequences

<!-- 
What becomes easier or more difficult to do because of this change?
Include both positive and negative consequences.
-->

### Positive

- [Positive consequence 1]
- [Positive consequence 2]

### Negative

- [Negative consequence 1]
- [Negative consequence 2]

### Neutral

- [Neutral observation]

## Implementation

<!-- 
Optional: How will this decision be implemented?
What are the next steps?
-->

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## References

<!-- 
Optional: Links to relevant documentation, discussions, or external resources
-->

- [Link 1]
- [Link 2]
