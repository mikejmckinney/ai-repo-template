# Opportunity feedback channel

> Structured channel for agents to surface improvement opportunities noticed during in-scope work without expanding scope. Read when an out-of-scope idea, toil pattern, doc gap, or deferrable risk surfaces.

## Purpose

Adjacent improvements (brittle script, stale doc, automation gap) historically caused scope creep or got dropped. The `opportunity_notes` channel gives OP a capped, evaluable triage queue. Worked examples and schema rationale: [`docs/guides/opportunity-feedback-examples.md`](../../docs/guides/opportunity-feedback-examples.md).

## When this rule fires

- Out-of-scope observation during in-scope work.
- Recommendation benefiting future sessions but not needed now.
- Duplicate, contradictory, or stale convention noticed while reading.

## What counts as an opportunity note

- Outside current task scope but inside repo improvement surface.
- Deferrable — current task can complete without it.
- Concrete — names a file, behavior, or symptom.
- NOT urgent for correctness, security, or in-flight work (use escalation below).

## Required fields (9 total)

Same shape in `agent-state:v1` `opportunity_notes` and `subagent_compliance.opportunity_notes`. Empty list permitted; partially-filled entries are not.

| Field | Type | Description |
|---|---|---|
| `title` | string | One-line headline. ≤80 chars. |
| `evidence` | string | What you observed. File path, command output, or behavior. |
| `impact` | string | Who/what is affected and how. |
| `recommendation` | string | Concrete enough to file. |
| `scope` | enum | `rule`, `script`, `doc`, `workflow`, `code`, `test`, `process`. |
| `suggested_next_action` | enum | `file-issue`, `fold-into-<n>`, `discuss`, `defer`. |
| `confidence` | enum | `high`, `medium`, `low`. |
| `role_relevance` | list[string] | Owner role(s) per `agent_ownership.md`. |
| `duplicate_check` | string | Search/issue compared. `none` if not checked. |

## Cap

Maximum **3 opportunity notes per session per agent** (self-discipline, not tooling). Pick highest impact × confidence, or escalate the pattern as one note.

## When agents may implement directly

MAY implement without a note ONLY when ALL FOUR hold:

1. Inside agent's `owned_paths` per `agent_ownership.md`.
2. **≤ ~20 LOC**, single file.
3. **Directly necessary** for in-scope task (not "while I'm here").
4. Does **not** touch role-sensitive surfaces (ADRs, ownership map, AGENTS.md canary, gate semantics, schemas).

When in doubt, surface the note.

## Escalation (blocking observations)

For items that **halt current work**, use `## Blocking observation` — not the 9-field schema. OP handles immediately.

Use when: **security** (secrets, auth, injection); **data-loss** risk; **CI-breaking** change the task can't fix; **plan-invalidating** false precondition.

If unsure, treat as blocking; OP can downgrade.

## Triage cadence and ownership

**Cadence**: weekly OR within 14 days, whichever first. **Owner**: OP.

Terminal outcomes: **File** (`agent-suggested` label), **Fold into** existing issue, or **Close** with one-sentence reason.

**Threshold**: >20 unresolved `agent-suggested` for 14+ days → OP files cadence review issue.

## Opportunity-note vs. blocking-observation contrast

| Aspect | Opportunity note | Blocking observation |
|---|---|---|
| Section | `## Opportunity notes` | `## Blocking observation` |
| Behavior | Defer; task continues | Halt; wait for OP |
| Triage | File / fold / close | Immediate OP routing |
| Examples | Toil, doc gap, naming | Security, data-loss, CI-break, plan-invalid |

## Surfacing locations

| Location | Purpose |
|---|---|
| PR body — `## Opportunity notes` | Notes from work producing the PR. |
| Plan comment — `## Opportunity notes` | Notes from planning. |
| `agent-state:v1` — `opportunity_notes` | Live coordination (ADR-025). |
| `subagent_compliance` — `opportunity_notes` | Per-dispatch evidence (substantive subagents MUST include; read-only MAY omit). |

## What NOT to do

- No scope creep — surface, don't silently fold into diff.
- No silent task expansion — that's plan revision.
- No out-of-band channels (Slack/DM/unrelated issues).
- No drive-by ADRs — file an opportunity note instead.
- No partial notes — all 9 fields or no note.

## Cross-references

- ADR-005, ADR-014, ADR-025, ADR-027
- Examples: [`docs/guides/opportunity-feedback-examples.md`](../../docs/guides/opportunity-feedback-examples.md)
