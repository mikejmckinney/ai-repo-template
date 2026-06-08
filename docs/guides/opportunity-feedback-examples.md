# Opportunity Feedback — Examples and Rationale

> **Purpose**: Worked examples and schema rationale for the opportunity feedback channel. The normative contract lives in [`.context/rules/process_opportunity_feedback.md`](../../.context/rules/process_opportunity_feedback.md).

## Schema-size rationale (9 vs. 3)

The minimum useful note is roughly `title + evidence + recommendation`. The six added fields reduce OP triage cost:

| Field | Triage cost moved |
|---|---|
| `scope`, `suggested_next_action`, `role_relevance` | Answers "what kind," "what next," "who owns" |
| `duplicate_check` | Prevents re-surfacing filed items |
| `confidence` | Lets OP defer low-confidence notes |
| `impact` | Separates thoughts from actionable opportunities |

**Day 30 falsifiability**: if fewer than 50% of fields beyond the minimum three are non-empty across surfaced notes, shrink the schema.

## Worked security-style example (blocking path)

The following routes to **`## Blocking observation`**, not opportunity notes:

```markdown
## Blocking observation

While editing `config/docker-compose.yml.template` to wire the new
service, I noticed line 47 contains `POSTGRES_PASSWORD=hunter2` as a
hardcoded literal in a template that gets copy-rendered into user
clones. Anyone who installs the template inherits a known
credential. This is a security defect, not a style nit: it cannot be
deferred behind a triage cadence because each install hour increases
exposure. Halting current work. Recommend OP file a
security-labeled issue and route to Backend/DevOps for a
`${POSTGRES_PASSWORD:?required}` substitution and a CI check that
greps templates for `=hunter2`-class literals. I have not committed
any change that touches this line.
```

Not opportunity-class because: halt-on-discovery is correct; failure mode is security; weekly triage is unacceptable for credential exposure.

## Good and bad worked examples

### Passing example

```yaml
- title: "Task-boundary rereads still use one flat profile"
  evidence: "AGENTS.md and .context/rules/process_session_state.md still require the same top-level reread pattern even when only one concern changed."
  impact: "Each task boundary pays repeated context cost and the handoff story stays harder to explain than necessary."
  recommendation: "File a follow-up to define named read profiles or a narrower task-boundary receipt keyed to the concern being edited."
  scope: process
  suggested_next_action: file-issue
  confidence: medium
  role_relevance: [architect, pm]
  duplicate_check: "Searched issue titles for 'read profile' and 'task-boundary reread' before surfacing this note."
```

### Failing example

```yaml
- title: "scripts could be better"
  evidence: "felt slow"
  impact: "developer experience"
  recommendation: "refactor"
  scope: script
  suggested_next_action: discuss
  confidence: low
  role_relevance: []
  duplicate_check: none
```

Fails: no specific file, no measured signal, no concrete recommendation, no owner, no duplicate check.

## Cross-references

- ADR-005 — Analyst pre-flight gate
- ADR-014 — Pre-flight extended to ad-hoc deliverables
- ADR-025 — `agent-state:v1` surfacing slot
- ADR-027 — Opportunity feedback channel ratification
