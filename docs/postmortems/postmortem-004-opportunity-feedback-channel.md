---
postmortem_number: 004
date: 2026-05-18
source_repo: mikejmckinney/ai-repo-template
source_commit: 4ad09c38edddaae4b1284458ea52acb19038bcd6
stacks: []
generalizes: Yes
follow_up_artifact: ADR-027
mirror_status: original
---

# Postmortem-004: Delivering the opportunity feedback channel (issue #337)

## Status

Final

## Date

2026-05-18

## Author(s)

Architect subagent (dispatched by Parent Orchestrator) on behalf of the
4-stage delivery for issue #337.

## Trigger

Issue [#337](https://github.com/mikejmckinney/ai-repo-template/issues/337)
surfaced the pattern that agent observations made during in-scope work
were routinely dropped: either folded silently into the current diff
(scope creep) or buried in session transcripts and lost on compaction.
The repo had no structured channel for "I noticed something adjacent
but I shouldn't fix it as part of this task."

## Context

After ADR-005 (Analyst pre-flight), ADR-014 (extend pre-flight to ad-hoc
deliverables), and ADR-026 (compliance contracts), agents spend
meaningful bounded time reading the repo before implementation and
return structured per-dispatch evidence. Both shifts increase the rate
at which agents notice adjacent improvements, but neither defined
where those observations land. Issue #337 proposed a structured
channel; plan v4 broke delivery into four stages:

1. **Stage 1**: `.context/rules/process_opportunity_feedback.md` — the
   canonical rule defining the 9-field shape, cap, carve-out, cadence,
   and contrast with blocking-observation escalation.
2. **Stage 2**: doc/template wiring — AGENTS.md link table, plan/PR
   templates, role-onboarding docs.
3. **Stage 3**: validator support, `agent-suggested` label definition,
   compliance-schema bump to v1.2, fixtures.
4. **Stage 4**: ADR-027 and this postmortem.

## What happened

1. **Analyst pre-flight** — first run returned **HOLD** with four
   channel-flow concerns (cap rationale unclear, blocking-vs-defer
   boundary fuzzy, triage owner under-specified, schema-size
   falsifiability missing). Plan was revised; round-2 re-flight
   returned **PASS**.
2. **Judge plan-gate** — first run returned **REQUEST_CHANGES** on the
   plan v3 draft: verification commands were vague ("check the rule
   reads well") and the staged-rollout ordering put the validator
   ahead of the rule it would validate. Plan v4 sharpened the
   verification block (named commands with expected output) and
   re-ordered stages so the rule landed first. Round-2 returned
   **APPROVE**.
3. **Stages 1–3** dispatched in sequence to the canonical owner role
   (process rule to Architect, doc/template wiring to Docs, validators
   to DevOps + QA). Each stage's subagent returned a
   `subagent_compliance` block; OP captured them into the PR body.
4. **Stage 4** (this dispatch) authored ADR-027, the README index
   update, and this postmortem.

## Expected vs. Actual

### Expected

A 4-stage linear delivery with one round of pre-flight and one round
of plan-gate, each `PASS`/`APPROVE` on first attempt; subagent
dispatches return clean compliance blocks; no rework on
`docs/compliance_schemas.md` patches.

### Actual

Pre-flight needed two rounds (HOLD → PASS). Plan-gate needed two
rounds (REQUEST_CHANGES → APPROVE). Stage 3 surfaced two structural
issues at dispatch time: (a) the dispatch packet specified an
`agents_md_version` field-shape variant that did not match the rule;
the dispatched subagent caught the mismatch by reading
`.context/rules/process_subagent_bootstrap.md` authoritatively and
returned the correct shape. (b) Four `apply_replay` patches against
`docs/compliance_schemas.md` had `parent_compliance` indentation that
did not match the file's actual indentation; they failed anchor match
and had to be re-composed with corrected anchors before re-application.

### Gap

The dispatch-packet detail level was wrong twice: too much
structural detail (the `agents_md_version` field-shape) and not
enough verification (the `compliance_schemas.md` indentation). Both
failure modes had the same root: composing dispatch artifacts from
memory instead of from the current file bytes.

## Root cause

Dispatch packets were treated as authoritative specifications when
they should be authoritative *contexts*. The canonical sources
(`.context/rules/*`, `docs/compliance_schemas.md`) hold the
structural truth; the dispatch packet's job is to point the subagent
at them, not to re-derive their structure. When the packet re-derived,
it drifted, and either the subagent caught the drift (good outcome)
or the apply step failed at anchor match (cheap but noisy outcome).

## Contributing factors

- Plan v3's verification block was vague enough that the staged-rollout
  ordering bug wasn't caught at plan-gate r1 by the verification
  commands alone; Judge had to read the staging itself to notice.
- `docs/compliance_schemas.md` has multiple `parent_compliance` blocks
  in close proximity (one per example), which made grep-style anchor
  selection fragile.

## What worked

- **The structured plan template caught the vague-verification bug at
  plan-gate** rather than at implementation time. The cost of a
  REQUEST_CHANGES round at plan-gate is dramatically lower than the
  cost of discovering vague verification after Stage 3 already shipped.
- **Pre-flight HOLD surfaced four channel-flow concerns** that became
  the Day 30 review triggers in the rule file. The HOLD round did
  the design work that would otherwise have surfaced as production
  channel drift at Day 30.
- **The Docs subagent caught the dispatch-packet field-shape mismatch**
  by following the canonical rule file rather than the packet. This
  validates the truth hierarchy: when the packet and the canonical
  rule disagreed, the subagent followed the higher-priority source
  and reported the conflict. Exactly the ADR-defined behavior.

## What didn't

- Dispatch packet for Stage 3 specified an `agents_md_version`
  field-shape variant that didn't match the rule — caught by subagent,
  but should have been caught at packet composition.
- Four `apply_replay` patches against `docs/compliance_schemas.md`
  had `parent_compliance` indentation that didn't match the file's
  actual content; all four required re-composition with corrected
  anchors before they applied. ~30 minutes of avoidable rework.

## What generalizes

**Yes** — broadly. Two patterns applicable to any agent-dispatched
multi-stage delivery in this repo (and to forks/derived repos that
adopt the OP + subagent dispatch model):

1. **Keep dispatch packets thin; let subagents authoritatively read
   canonical sources for structural detail.** The packet specifies
   *role, scope, owned paths, expected output, blocking constraints,
   and pointers to canonical files*. It does not re-derive structural
   details (field shapes, schema versions, exact indentation). The
   subagent reads those from the canonical source. This shifts drift
   risk from packet-composition time (one author, no review) to
   subagent-execution time (load the rule, follow it).
2. **Verify anchors against actual file bytes before composing batch
   `apply_replay` patches.** When a file has many near-identical
   blocks (examples, fixtures, repeated schema instances), grep-style
   anchor selection fails silently. Read the surrounding context first
   and compose anchors from the actual bytes, not from memory of the
   file's structure.

**Status**: `Yes`

## Action items

- [x] **ADR-027** — opportunity feedback channel design decision
  (this postmortem's follow-up artifact). Ships in the same PR.
- [x] **`docs/decisions/README.md`** — index row for ADR-027.
  Same PR.
- [x] **Day 14 / Day 30 / Day 90 channel-flow checkpoints** — tracking
  issue [#343](https://github.com/mikejmckinney/ai-repo-template/issues/343)
  filed during Phase 6a; ADR-027's Implementation checklist updated to
  reference it (replacing the prior `#TBD` placeholder).
- [ ] **Optional follow-up**: consider a lint helper that pre-validates
  `apply_replay` anchors against current file bytes before dispatch.
  Surfaced as opportunity-note candidate, not a hard requirement.

## References

- [ADR-027](../decisions/adr-027-opportunity-feedback-channel.md) —
  the design decision this postmortem documents the delivery of.
- [ADR-005](../decisions/adr-005-analyst-preflight-gate.md) — the
  pre-flight gate that surfaced HOLD round 1.
- [ADR-014](../decisions/adr-014-extend-preflight-to-adhoc-deliverables.md)
  — pre-flight extended to ad-hoc deliverables.
- [ADR-025](../decisions/adr-025-github-issues-pr-comments-as-live-state.md)
  — live-state model used to surface plan v4 and gate results.
- [ADR-026](../decisions/adr-026-compliance-contracts.md) — the
  compliance contract the channel extends in v1.2.
- [`.context/rules/process_opportunity_feedback.md`](../../.context/rules/process_opportunity_feedback.md)
  — canonical rule.
- Issue [#337](https://github.com/mikejmckinney/ai-repo-template/issues/337)
  — originating issue.
- Plan v4: https://github.com/mikejmckinney/ai-repo-template/issues/337#issuecomment-4473070761
- Analyst Pre-Flight PASS (round 2) and Judge plan-gate APPROVE (round 2):
  see issue #337 comment thread.
