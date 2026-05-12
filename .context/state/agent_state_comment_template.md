# `agent-state:v1` comment template

Copy this template into a GitHub issue or PR comment. Keep one latest
comment current for the work item; update it instead of scattering live
state across multiple repo-local files.

```markdown
<!-- agent-state:v1 issue:NNN pr:MMM branch:feature/example role:devops -->

**Status:** in_progress | awaiting_user_input | blocked | awaiting_review | handoff_needed | done
**Updated:** YYYY-MM-DDTHH:MM:SSZ

## Since last update
- ...

## Blockers / awaiting
- None

## Next 1–3 actions
1. ...

## Handoff
**To:** self / next session / analyst / architect / judge / critic / pm / frontend / backend / qa / devops / docs

<Only fill when pausing, transferring ownership, or leaving work. One or two sentences max.>
```

Do not add long decision history, full file lists, verification matrices,
or durable retrospective lessons here. Use plan comments, PR bodies, ADRs,
CI, `.context/sessions/latest_summary.md`, and session archives for those.
