# `agent-state:v1` comment template

Copy this template into a GitHub issue or PR comment. Keep one latest
comment current for the work item; update it instead of scattering live
state across multiple repo-local files.

Header fields: use `issue:NNN` for the linked issue. Use `pr:MMM` once a
PR exists, `pr:pending` before PR creation, or `pr:none` for issue-only
work with no planned PR.

For `Status`, use exactly one value from the template's enum. Do not
invent synonyms or add new values without updating ADR-025 and the
associated checks/docs.

```markdown
<!-- agent-state:v1 issue:NNN pr:pending branch:feature/example role:devops -->

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

## Optional `opportunity_notes` YAML block (v1.2)

The `agent-state:v1` comment may optionally embed a structured YAML block
carrying `opportunity_notes` per ADR-027 and the
[`process_opportunity_feedback.md`](../rules/process_opportunity_feedback.md)
rule. When present, it sits inside a fenced ```yaml block within the
comment body and is parsed/validated by
`scripts/lib/compliance_schema.py::validate_state`. Each entry must
include all 9 required fields (title, evidence, impact, recommendation,
scope, suggested_next_action, confidence, role_relevance, duplicate_check).
Cap: ≤3 per session per agent. PMs may apply the `agent-suggested` label
to items they file as follow-up issues from this channel. See
`docs/compliance_schemas.md` § "agent-state:v1" for the canonical schema
and a worked example.
