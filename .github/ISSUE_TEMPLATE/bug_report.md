---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

<!-- A clear and concise description of the bug -->

## Steps to Reproduce

1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

## Expected Behavior

<!-- What you expected to happen -->

## Actual Behavior

<!-- What actually happened -->

## Screenshots

<!-- If applicable, add screenshots to help explain your problem -->

## Environment

- **OS**: [e.g., macOS 14.0, Windows 11, Ubuntu 22.04]
- **Browser**: [e.g., Chrome 120, Firefox 121]
- **Version/Commit**: [e.g., v1.2.3 or commit hash]

## Additional Context

<!-- Any other relevant information -->

## Possible Solution

<!-- Optional: If you have ideas on how to fix this -->

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
Evidence reuse:
Result: pass | fail | blocked
```

Use the least costly outcome-equivalent environment. Mixed changes may require
more than one record. External-state and runtime claims cannot be prose-only.
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
