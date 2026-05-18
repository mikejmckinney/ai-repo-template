# ADR-027: Opportunity feedback channel for in-scope agent observations

## Status

Accepted

## Date

2026-05-18

## Context

Agents working in this repo routinely notice adjacent improvements while
doing in-scope work: a brittle script, a stale doc, a missing test, a
confusing convention, an automation gap. Before this ADR there was no
structured surface for those observations:

- Folding them silently into the current diff produced scope creep and
  made review harder.
- Dropping them on the floor lost the signal entirely.
- "By the way…" notes at the end of a session got buried in long
  transcripts or in compacted handoffs and never reached triage.

Three prior decisions changed the failure shape and made a dedicated
channel necessary:

- **ADR-005** (Analyst pre-flight gate) — agents now spend bounded time
  reading the repo before implementation, which surfaces observations
  faster than the prior implement-first flow did.
- **ADR-014** (extend pre-flight to ad-hoc deliverables) — the same
  evaluable-bar discipline reaches non-code tasks, broadening the
  surface area where observations arise.
- **ADR-026** (compliance contracts) — every dispatched subagent now
  returns a structured `subagent_compliance` block. That block is the
  natural carrier for per-dispatch observations, but ADR-026 deferred
  defining the observation payload.

Without a dedicated channel, agents are stuck choosing between scope
creep and information loss. The repo needs a low-friction, capped,
evaluable way to surface these items so the Parent Orchestrator (OP)
can triage them on a cadence rather than mid-stream.

## Decision

We will introduce the structured `opportunity_notes` channel defined in
[`.context/rules/process_opportunity_feedback.md`](../../.context/rules/process_opportunity_feedback.md).
The rule is the canonical source of truth; this ADR records the design
choices behind it.

Key choices:

1. **9-field shape per note**: `title`, `evidence`, `impact`,
   `recommendation`, `scope`, `suggested_next_action`, `confidence`,
   `role_relevance`, `duplicate_check`. The minimum useful payload is
   ~3 fields (`title` + `evidence` + `recommendation`); the additional
   six fields each earn their friction by collapsing questions OP
   would otherwise ask manually, shifting triage cost from
   linear-in-OP-time to linear-in-author-time.
2. **Cap of ≤3 notes per session per agent**, enforced by
   self-discipline. The cap exists because OP triage is the
   bottleneck; six low-signal notes per session across N agents
   floods the queue and degrades the channel for everyone. If an
   agent has more than three, they pick the top three by
   impact × confidence or escalate the pattern itself as one note.
3. **Read-only carve-out for the substantive-output contract**:
   substantive-output subagents MUST include the
   `opportunity_notes` field in `subagent_compliance` (empty list
   permitted); read-only subagents MAY omit it. This keeps the
   compliance contract honest without forcing inspection-only roles
   to manufacture observations.
4. **`agent-suggested` label** as the GitHub surfacing convention when
   OP files a note as a new issue. The label makes the queue grep-able
   and supports the threshold trigger described below.
5. **v1.2 additive schema bump** of the compliance contract rather
   than a v2 break. The field is optional-by-default-with-required-
   inclusion-for-substantive-output, which is additive over v1.1; no
   existing compliance evidence becomes invalid.
6. **Triage cadence: weekly OR within 14 days of surfacing**, whichever
   comes first. **Owner: OP**, with PM as documented fallback when OP
   is unavailable. Three terminal outcomes per note: file as new
   issue with `agent-suggested`, fold into an existing issue, or
   close with a one-sentence reason. A threshold trigger fires if
   more than 20 `agent-suggested` items remain unresolved for 14+
   days — that self-correcting loop prevents the queue from becoming
   a write-only dumping ground.
7. **Explicit contrast with `## Blocking observation`**: the
   opportunity channel is for **deferrable** items only. Items that
   should halt current work pending resolution (security findings,
   data-loss risks, CI-breaking changes, plan-invalidating
   preconditions) route through the `## Blocking observation`
   escalation path instead. When in doubt, agents treat the item as
   blocking and let OP downgrade — false positives on blocking are
   cheap; false negatives can ship a bug.

## Options Considered

### Option 1: Structured `opportunity_notes` channel (chosen)

- **Pros**: Captures repo-improvement signal that otherwise dies;
  structures it so triage is bounded and evaluable; additive over the
  existing compliance contract; explicit contrast with blocking
  escalation prevents the channel from being misused for halt-class
  items.
- **Cons**: Adds OP triage toil; the cap may suppress signal in
  high-noise sessions; the 9-field shape is more ceremony than a
  free-form note. Mitigated by the Day 30 schema-size falsifiability
  trip in the rule file.

### Option 2: Free-form "by the way…" in `agent-state:v1` comments

- **Pros**: Zero new schema; reuses an existing surface.
- **Cons**: Too unstructured for triage. OP would have to manually
  extract `who/what/where/why` for each note, which is exactly the
  cost the 9-field shape collapses. Also indistinguishable from
  ongoing-task chatter, so notes get lost in transcripts.

### Option 3: Agents file issues directly when they notice things

- **Pros**: Lowest friction at surfacing time; uses GitHub's
  native triage tooling.
- **Cons**: Floods the backlog with low-confidence observations and
  duplicates; no `duplicate_check` discipline; no cap; concentrates
  triage on whoever is on backlog rotation rather than OP, who has
  full session context. Also conflates "noticed during work" with
  "this is a tracked issue," which makes the issue queue noisier
  for human contributors.

### Option 4: PM-only intake — agents tell PM, PM files everything

- **Pros**: Centralizes the surface; preserves PM's coordination role.
- **Cons**: Concentrates a single bottleneck. PM already owns
  cross-role coordination state; routing every observation through
  PM either slows PM or forces PM to rubber-stamp without
  inspection. The triage decision belongs with OP, who has the
  fullest cross-session context.

### Option 5: Schema v2 break instead of v1.2 additive bump

- **Pros**: Cleaner conceptual boundary if the channel turns out to
  be a fundamental change to the contract.
- **Cons**: Overkill for an additive optional field. Forces every
  existing fixture, example, and validator to update in lockstep
  even though no existing evidence shape becomes invalid. Reserved
  for a future change that actually invalidates v1 evidence.

## Consequences

### Positive

- Repo-improvement signal that would have died now reaches a triage
  queue with bounded latency (≤14 days).
- The 9-field shape makes notes evaluable: OP can file, fold, or
  close without re-reading session transcripts.
- Backward-compatible with v1.1 compliance evidence; no existing
  PRs or plans become invalid.
- Explicit `## Blocking observation` contrast keeps the channel out
  of the security/data-loss/CI-breaking path, where mis-routing
  would be expensive.
- Cadence + threshold trigger build in a self-correcting loop: the
  queue surfaces its own health.

### Negative

- Adds OP triage toil — every surfaced note eventually consumes OP
  attention. Mitigation: cap and confidence field let OP defer
  low-signal notes cheaply.
- The cap may suppress signal in high-noise sessions where an agent
  legitimately notices >3 items. Mitigation: rule explicitly
  permits escalating the pattern itself as one of the three notes.
- The channel could become a noise dump if cap discipline slips.
  Mitigation: Day 30 schema-size falsifiability trip in the rule
  file (if <50% of fields beyond the minimum three are non-empty
  across surfaced notes, schema shrinks); the >20-unresolved
  threshold trigger forces a cadence revisit.

### Neutral

- ADR-005, ADR-014, ADR-025, ADR-026 status all unchanged. This ADR
  extends the surface area of `subagent_compliance` without
  replacing any prior decision.
- The `agent-suggested` label is a GitHub convention, not a workflow
  trigger; no CI behavior changes on label apply.

## Implementation

- [x] Add `.context/rules/process_opportunity_feedback.md` (Stage 1).
- [x] Update plan/PR templates, role-onboarding docs, and the rule
  link table in `AGENTS.md` (Stage 2).
- [x] Add validator support, `agent-suggested` label definition, and
  schema fixtures (Stage 3).
- [x] Add this ADR and its README index row (Stage 4, this PR).
- [x] Add postmortem-004 capturing the 4-stage delivery (Stage 4,
  this PR).
- [ ] Day 14 / Day 30 / Day 90 channel-flow checkpoints (tracking
  issue [#343](https://github.com/mikejmckinney/ai-repo-template/issues/343)
  filed in Phase 6a).

## Verification

- `bash test.sh` — template integrity and parity checks pass; new
  ADR is picked up by the ADR-index parity check.
- `grep -n 'adr-027' docs/decisions/README.md` — index row present.
- `ls docs/postmortems/postmortem-004-*.md` — postmortem present.
- `grep -c '^##' docs/decisions/adr-027-opportunity-feedback-channel.md`
  — ≥5 top-level sections (Status, Context, Decision, Options
  Considered, Consequences, Implementation, Verification,
  References).
- `grep -c 'issues/337\|issue #337\|#337' docs/decisions/adr-027-opportunity-feedback-channel.md`
  — ≥1 reference to the originating issue.

## References

- [ADR-005](./adr-005-analyst-preflight-gate.md) — Analyst pre-flight
  gate; the quality gate this channel complements.
- [ADR-014](./adr-014-extend-preflight-to-adhoc-deliverables.md) —
  pre-flight extended to ad-hoc deliverables; same evaluable-bar
  principle applied at task entry.
- [ADR-025](./adr-025-github-issues-pr-comments-as-live-state.md) —
  defines the `agent-state:v1` surfacing slot used by the channel.
- [ADR-026](./adr-026-compliance-contracts.md) — defines the
  `subagent_compliance` surfacing slot extended by the channel.
- [`.context/rules/process_opportunity_feedback.md`](../../.context/rules/process_opportunity_feedback.md)
  — canonical rule.
- Issue [#337](https://github.com/mikejmckinney/ai-repo-template/issues/337)
  — originating opportunity (the pattern of dropped agent observations).
- Plan v4 comment: https://github.com/mikejmckinney/ai-repo-template/issues/337#issuecomment-4473070761
