---
name: Feature Request
about: Suggest a new feature or improvement
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Problem Statement

<!-- What problem does this feature solve? Why is it needed? -->

## Proposed Solution

<!-- Describe what you want to happen -->

## Alternatives Considered

<!-- What alternatives have you considered? -->

## User Story

<!-- Optional: Describe the feature from a user's perspective -->
As a [type of user], I want [goal] so that [benefit].

## User outcome (15-minute test)

<!--
Optional but recommended. If you can answer this clearly here, add the
`outcome-validated` label to record that the user outcome is explicit.

The test: "If a user spent 15 minutes with the final deliverable,
would they EXPERIENCE the outcome, or would they READ ABOUT it?"

For a working feature, the answer should be "experience." Describe in
one paragraph what a user will be able to DO when this ships — focus on
user actions, not files created. Example:

> A reviewer will be able to open a PR, see the Plan comment was posted
> before the first code commit, and confirm required checks catch a missing plan.
-->

## Acceptance Criteria

<!-- How will we know when this feature is complete? -->
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Design / Mockups

<!-- Optional: Include any designs, mockups, or wireframes -->

## Technical Considerations

<!-- Optional: Any technical constraints or implementation notes -->

## Priority

<!-- How important is this feature? -->
- [ ] Critical - Blocking other work
- [ ] High - Needed soon
- [ ] Medium - Would be nice to have
- [ ] Low - Future consideration

## Additional Context

<!-- Any other relevant information -->

<!-- Live agent coordination status belongs in the latest `agent-state:v1` issue/PR comment, not in the issue body. Keep this body focused on the durable feature/task contract. -->

<!-- implementation-plan:v2:begin -->

## Implementation Plan

### Outcome

### Approach

### Files to change

- [`README.md`](../blob/main/README.md) — <one phrase: what change>
- [`scripts/tests/`](../tree/main/scripts/tests) — <one phrase: what change>

<!-- Replace the examples with every expected file or directory. Existing files
and directories must be clickable: use ../blob/main/<path> for a file and
../tree/main/<path> for a directory. For a planned new path, link its nearest
existing parent and label the new path in the description. For a glob, link its
containing directory and keep the glob in the link text or description. -->

### User outcome validation plan — PRIMARY

For each material claim, plan one auditable record:

```text
Material claim:
Environment:
Why representative:
Implementation SHA:
Action performed:
Expected result:
Observed result:
Artifact:
Artifact type:
Redaction:
Retention:
Evidence reuse: <none, or Paths: <later path analysis>; Conditions: <load-bearing condition analysis>>
Result: pass | fail | blocked
```

Choose the most representative practical environment; cost and speed may
distinguish equally representative options but cannot replace the affected
user's action or required result. Paid or destructive actions require explicit
approval and remain blocked until performed. Mixed changes may require more
than one record. External-state and runtime claims cannot be prose-only.
See `docs/guides/outcome-validation.md`.

### Supporting verification

**Change class**: <code-or-docs | pull_request-triggered workflow | default-branch-only workflow | mixed>

The classifier owns workflow-trigger facts. Select outcome environments from
the user journey; use the sibling sandbox adapter only when GitHub default-branch
state is load-bearing.

### Risks / out-of-scope

### Opportunity notes

### Revision history

- Not yet planned.

<!-- implementation-plan:v2:end -->
