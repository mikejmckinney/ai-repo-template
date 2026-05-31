# Opportunity feedback channel

> Structured channel for agents to surface improvement opportunities they
> notice while doing in-scope work, without expanding scope or going out
> of band. Read when an out-of-scope idea, toil pattern, doc gap, or
> deferrable risk surfaces during in-scope execution.

## Purpose

While doing in-scope work, agents routinely notice adjacent improvements
the current task does not cover: a brittle script, a stale doc, a
missing test, a confusing convention, an automation gap. Historically
those observations either got absorbed into the current diff (scope
creep) or got dropped on the floor. This rule defines the structured
`opportunity_notes` channel: a low-friction, capped, evaluable way to
surface such items so OP can triage them on a cadence instead of
mid-stream.

## When this rule fires

- An agent doing in-scope work observes something worth changing that
  is outside the task scope.
- An agent has a recommendation that would benefit future sessions or
  other roles but does not need to happen now.
- An agent notices a duplicate, contradictory, or stale convention
  while reading the repo.

## What counts as an opportunity note

Items that are:

- **Outside the current task scope** but inside the repo's reasonable
  improvement surface.
- **Deferrable** — the current task can complete without them.
- **Concrete** — name a file, a behavior, or an observable symptom.
- Specifically NOT urgent in a way that would block correctness,
  security, or in-flight work. Those go through the escalation path
  below.

## Required fields (9 total)

Each opportunity note carries the following structured fields. The same
shape is used in the `agent-state:v1` `opportunity_notes` array and in
the `subagent_compliance.opportunity_notes` array. Empty list is
permitted; partially-filled entries are not — if you surface a note,
fill all 9.

| Field | Type | Description |
|---|---|---|
| `title` | string | One-line headline. ≤80 chars. |
| `evidence` | string | What you observed. File path, command output, or specific behavior. |
| `impact` | string | Who/what is affected and how. Toil, risk, correctness, clarity. |
| `recommendation` | string | What you propose changing. Concrete enough to file. |
| `scope` | enum | One of: `rule`, `script`, `doc`, `workflow`, `code`, `test`, `process`. |
| `suggested_next_action` | enum | One of: `file-issue`, `fold-into-<n>` (where `<n>` is an issue number, e.g. `fold-into-337`), `discuss`, `defer`. |
| `confidence` | enum | One of: `high`, `medium`, `low`. How sure you are this is real and worth doing. |
| `role_relevance` | list[string] | Role(s) that would own the work. Names from `agent_ownership.md`. |
| `duplicate_check` | string | Search you ran or issue/PR you compared against. `none` if you did not check. |

## Cap

Maximum **3 opportunity notes per session per agent**. The cap is
enforced by self-discipline, not tooling. If you have more than 3,
pick the 3 with the highest impact × confidence and drop the rest, OR
escalate the pattern itself as one of your 3 notes ("noticed >3
opportunities, suggests a larger refactor").

The cap exists because OP triage is the bottleneck. Six low-signal
notes per session across N agents floods the queue and degrades the
channel for everyone.

## When agents may implement directly

The opportunity channel is the default. Agents MAY implement directly
without surfacing a note ONLY when ALL FOUR of the following
conditions hold:

1. The change is **inside the agent's `owned_paths`** per
   `.context/rules/agent_ownership.md`.
2. The change is **≤ ~20 LOC** and confined to a single file.
3. The change is **directly necessary** for the in-scope task to
   land correctly (not a "while I'm here" cleanup).
4. The change does **not** touch role-sensitive surfaces (ADRs, the
   path ownership map, AGENTS.md canary, gate semantics, schema files).

If any condition fails, surface as an opportunity note instead. When
in doubt, surface the note — the friction is small and the upside is
OP gets to decide.

## Escalation (blocking observations)

The opportunity channel is for **deferrable** items. For items that
should **halt current work pending resolution**, use the
`## Blocking observation` section convention instead.

A blocking observation:

- Halts the current task. The agent stops, surfaces the observation,
  and waits for parent direction.
- Routes outside the triage cadence. OP handles immediately.
- Names the failure mode in plain prose, not the 9-field schema.

Use this path when the observation is one of:

- **Security**: discovered hardcoded secret, exposed credential,
  missing auth check, injection vector, supply-chain risk.
- **Data-loss**: discovered destructive operation without
  confirmation, missing backup, irreversible migration without
  rollback path.
- **CI-breaking**: the in-scope change will break main on merge in a
  way the current task cannot fix.
- **Plan-invalidating**: the in-scope task as specified cannot be
  done correctly because a precondition turned out false.

If you are not sure whether something is opportunity-class or
blocking-class, treat it as blocking and let OP downgrade it. False
positives on blocking are cheap; false negatives can ship a bug.

## Triage cadence and ownership

**Cadence**: weekly OR within 14 days of surfacing, whichever comes
first.

**Owner**: OP (the Parent Orchestrator). OP triages opportunity
notes; no individual role owns the triage queue.

**Three terminal outcomes** for each note:

1. **File** as a new issue with the `agent-suggested` label, citing
   the originating PR/issue/session.
2. **Fold into** an existing issue with a cross-reference comment
   citing the originating PR/issue/session.
3. **Close** with a one-sentence reason (e.g., "duplicate of #N",
   "out of scope for this repo", "intentional, see ADR-NNN").

**Threshold trigger**: if more than 20 `agent-suggested`-labeled
items remain unresolved for 14+ days, OP files a follow-up issue
revisiting the triage cadence or raising the surfacing bar. This is
the self-correcting feedback loop that prevents the queue from
becoming a write-only dumping ground.

## Opportunity-note vs. blocking-observation contrast

| Aspect | Opportunity note | Blocking observation |
|---|---|---|
| Surfacing section | `## Opportunity notes` | `## Blocking observation` |
| Behavior | Defer; current task continues | Halt; current task pauses pending resolution |
| Triage outcome | File new issue, fold into existing, or close with reason | Interrupt current work; OP routes immediately |
| Examples of trigger | Toil pattern, doc accuracy gap, missing test, naming inconsistency | Security finding, data-loss risk, CI-breaking change, plan-invalidating precondition |

## Worked security-style example

The following is an example of a discovery that routes to the
**blocking observation** path, not the opportunity-note path:

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

This is **not** opportunity-class because (a) halt-on-discovery is
the correct response, (b) the failure mode is security rather than
toil, and (c) the triage cadence ("weekly OR within 14 days") is an
unacceptable response time for credential exposure.

## Schema-size rationale (9 vs. 3)

The minimum useful opportunity note is roughly `title + evidence +
recommendation` — three fields. Why does this rule require nine?

The six added fields each earn their friction by reducing OP triage
cost. `scope`, `suggested_next_action`, and `role_relevance`
collapse the first three questions OP would otherwise ask manually
(what kind of change, what should happen next, who owns it).
`duplicate_check` attacks the dominant low-signal failure mode —
re-surfacing items already filed — without requiring OP to
re-search the issue tracker for every note. `confidence` lets OP
defer low-confidence notes without re-reading them in full.
`impact` makes the bar evaluable: a note with no concrete impact
statement is a thought, not an opportunity. Together the six added
fields move triage cost from linear-in-OP-time to
linear-in-author-time, which is the right tradeoff when there are
many authors and one OP. **Day 30** falsifiability trip: if fewer
than 50% of fields beyond the minimum three are non-empty across
surfaced notes, the schema is over-specified and should shrink.

## Surfacing locations

Opportunity notes surface in these locations, all carrying the same
9-field shape:

| Location | Purpose |
|---|---|
| PR body — `## Opportunity notes` section | Notes surfaced during the work that produced the PR. |
| Plan comment — `## Opportunity notes` section | Notes surfaced during planning (e.g., "this rule is adjacent and stale"). |
| `agent-state:v1` comment — `opportunity_notes` field | Live coordination state per ADR-025. |
| `subagent_compliance` block — `opportunity_notes` field | Per-dispatch evidence. Substantive-output subagents MUST include the field (empty list permitted). Read-only subagents MAY omit it. |

## Triage

See § "Triage cadence and ownership" above. This section exists so
issue/PR templates that link "Triage" can land on the canonical
text.

## What NOT to do

- **No scope creep.** Do not silently fold an opportunity into the
  current diff. Surface it as a note and let OP triage.
- **No silent expansion.** Do not enlarge the current task spec to
  include the opportunity. If the task spec needs to grow, that is
  a plan revision, not an opportunity note.
- **No out-of-band channels.** Do not Slack/DM/post in unrelated
  issues. The surfacing locations above are the only valid
  surfaces.
- **No drive-by ADRs.** An opportunity to write an ADR is itself an
  opportunity note, not an ADR PR.
- **No partial notes.** All 9 fields or no note. A half-filled note
  is worse than no note because it consumes triage time without
  giving OP enough to act.

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

This passes because: concrete file evidence, clear
impact, specific recommendation, plausible scope/owner, duplicate
check performed.

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

This fails because: no specific file/line, no measured signal, no
concrete recommendation, no owner, no duplicate check, low
confidence with no follow-up path. OP cannot file, fold, or close
this; it just sits. A note like this consumes triage time without
enabling action and is exactly the failure mode the 9-field
schema is designed to prevent.

## Cross-references

- ADR-005 — Analyst pre-flight gate (related quality gate this
  channel complements).
- ADR-014 — Pre-flight extended to ad-hoc deliverables (same
  "evaluable bar" principle applied at task entry).
- ADR-025 — GitHub issues / PR comments as live state (defines the
  `agent-state:v1` surfacing slot).
- ADR-026 — Compliance contracts (defines the `subagent_compliance`
  surfacing slot).
