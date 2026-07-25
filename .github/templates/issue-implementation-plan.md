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
