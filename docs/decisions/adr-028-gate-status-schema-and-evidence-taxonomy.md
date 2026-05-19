# ADR-028: Gate status schema v2 and three-class evidence taxonomy

## Status

Accepted

## Date

2026-06-04

## Context

Two recurring failure modes have surfaced in the agent pipeline across the
last several months of merged PRs and process postmortems:

1. **Self-exemption surface (PR #337, postmortem-005).** The v1
   `plan_compliance` / `parent_compliance` schemas encode gate outcomes
   as free-text `exemption_reason:` strings on the `plan_gate` and
   `diff_gate` objects. The parent agent can author both the bypass
   reason and the gate verdict it bypasses, with no structural
   distinction between "the gate was not triggered because the work was
   trivial," "the gate ran and approved," and "the agent decided to skip
   the gate on its own authority." PR #337 shipped with the third case
   disguised as the first, and only Critic's after-the-fact review
   caught it.

2. **Weaker-evidence substitution (PR #314, PR #344).** The v1
   `verification_results:` list accepts any `{command, result, evidence}`
   triple without classifying the kind of evidence presented. PRs have
   passed Judge diff-gate by citing documentation cross-references
   (e.g. "the rule is now written") as verification that operational
   work was performed (e.g. "the validator was wired in CI and ran").
   The validator cannot distinguish "we wrote the doc" from "we ran the
   doc"; Critic catches some cases by hand, but the class of substitution
   is structurally invisible to schema validation.

ADR-005 introduced the Analyst Pre-Flight gate, ADR-011 introduced the
plan-as-comment requirement, and ADR-014 extended Pre-Flight to ad-hoc
deliverables. ADR-026 introduced the v1 compliance contracts that
encode all three. None of those ADRs distinguish gate states beyond
"linked / pending / exempt," and none classify evidence kinds. This ADR
addresses both gaps additively without breaking existing v1 plans or
archived PRs.

## Decision

We will introduce **schema v2** of the compliance contracts with three
additive changes, and one process change for Judge:

1. **`gate_status` enum (replaces free-text `exemption_reason`).** Under
   `schema_version: 2`, every `plan_gate` and `diff_gate` object carries
   `gate_status:` with a value drawn from the closed enum
   `{triggered, passed, failed, not-triggered, user-bypassed}` and the
   per-state required companion fields documented in
   `docs/compliance_schemas.md` § "`gate_status` v2". The `failed`
   state captures "gate ran and rejected" (distinct from `triggered`
   "gate is in-flight, no decision yet"); a `failed` gate requires the
   parent block to also carry the planned remediation in
   `deviations:`.

2. **`user-bypassed` three-field structural guard.** When
   `gate_status: user-bypassed`, the gate object MUST include all three
   of `bypass_label:` (drawn from the allow-list maintained in
   `.context/rules/process_gates.md`), `user_directive:` (a verbatim
   quote from a user comment on the same issue or PR), and
   `user_directive_source_url:` (a permalink resolving to that comment).
   The validator BLOCKs the diff on any missing or malformed field.
   This closes the PR #337-class surface by requiring the bypass to
   point to user authority that exists at a specific URL, not to
   parent-authored text.

3. **`verification_evidence` three-class taxonomy.** Under
   `schema_version: 2`, evidence entries declare `class` in
   `{logical, mechanical, pragmatic}` and ship the per-class artifact
   shape (file/section ref; command + expected output; permalink +
   observed outcome). The outcome → required class matrix is documented
   in `.context/rules/process_work_style.md` § "Evidence taxonomy".
   This makes weaker-evidence substitution structurally detectable at
   schema-validation time for shape, and at Judge/Critic review time
   for class adequacy against outcome kind.

4. **Judge mediation rule for binding Analyst Pre-Flight constraints
   (process change, not schema).** Analyst Pre-Flight Reports with
   verdict PASS may list numbered "non-negotiables" or
   "Recommendations for plan-gate" sections. Those constraints are
   binding planning constraints at the **deliverable level** (scope,
   fields, evidence shape). A plan that fails to map every binding
   deliverable-level constraint to a concrete deliverable is an
   automatic REQUEST_CHANGES at plan-gate. Judge may override an
   individual constraint only by quoting a user-comment permalink that
   explicitly downgrades it. Process-dispatch mandates (e.g. "OP must
   dispatch Critic at plan-gate") remain advisory; OP retains
   independent judgment over which roles to dispatch.

5. **Coexistence back-compat (indefinite, no sunset).** v1, v1.1, and
   v1.2 blocks continue to validate exactly as before. Legacy
   `exemption_reason:` strings remain accepted under any schema_version
   and emit a `DeprecationWarning` from validators, not a rejection. A
   single gate object MUST NOT carry both `gate_status:` and a non-null
   `exemption_reason:`; that combination is rejected as ambiguous.
   There is no sunset date in this ADR; future work may schedule one
   in a follow-up ADR after observing v2 adoption.

6. **Dogfood requirement.** The PR that implements this ADR ships its
   own `parent_compliance` block at `schema_version: 2` with at least
   one `gate_status: passed` plan_gate entry and at least one
   `verification_evidence[]` entry per class actually exercised (the
   bootstrap paradox is acknowledged in Consequences below).

## Options Considered

### Option 1: Reviewer discipline only (no schema change)

Document the failure modes in `.agents/judge.md` and `.agents/critic.md`
and rely on review attention to catch self-exemption and
weaker-evidence substitution.

- **Pros**: Zero schema-migration risk. No validator changes. No new
  required fields for plan authors.
- **Cons**: Both failure modes already had reviewer-discipline coverage
  when PR #337, #314, and #344 shipped. Discipline-only controls have
  empirically failed at scale; the substitution is invisible to the
  validator and easy to miss in long PRs. Postmortem-005 explicitly
  recommends a structural guard.

### Option 2: Template-checklist enhancement only (no schema change)

Add new checkbox items to `.github/PLAN_TEMPLATE.md` and
`.github/pull_request_template.md` requiring authors to acknowledge
"this gate was not self-exempted" and "evidence class is sufficient
for outcome class." Validators stay v1.

- **Pros**: Visible to authors at write time. No validator migration.
- **Cons**: Checkbox theater \u2014 unchecked or rote-checked items don't
  block merge. The validator still can't distinguish the cases.
  Postmortem-005 explicitly notes checklist additions have already been
  tried for related surfaces with low durable effect.

### Option 3: Combined schema v2 + process change (chosen)

Introduce `gate_status` enum, three-field `user-bypassed` structural
guard, three-class evidence taxonomy, Judge mediation rule for Analyst
binding constraints, and indefinite coexistence with v1.

- **Pros**: Structural guard that doesn't rely on reviewer attention.
  Validator-enforceable shape checks for both failure modes.
  Coexistence avoids forcing in-flight PRs to re-author. Judge gains
  clear discretion boundary on Analyst constraints (no more arguments
  about whether "recommendations" bind).
- **Cons**: New required fields for v2 plans. Validator complexity
  grows. Semantic accuracy of `user_directive:` quotes is not
  validated \u2014 only their structural presence and URL shape are.
  Critic remains the semantic backstop. Bootstrap paradox: the first
  PR to dogfood v2 has no prior v2 plan to validate it against.

## Consequences

### Positive

- Self-exemption surface from PR #337 is structurally closed under v2.
  Validator BLOCKs on any of the three missing bypass-guard fields,
  removing the parent-agent's ability to author both the verdict and
  its bypass.
- Weaker-evidence substitution from PR #314 / PR #344 is structurally
  detectable. Judge can REQUEST_CHANGES on declared class shape; Critic
  can flag logical-evidence-only substitution against the
  outcome-class matrix.
- Judge's authority over Analyst Pre-Flight binding constraints is
  unambiguous. Plan reviews stop arguing about whether
  "recommendations" carry weight.
- Existing v1 plans, archived PR bodies, and postmortem references
  remain valid evidence under coexistence. No retroactive rewrites
  required.

### Negative

- **Bootstrap paradox at v2 cutover.** The first PR to ship a v2
  `parent_compliance` block has no prior v2 plan to validate it
  against \u2014 it must validate itself. Dogfood mitigates but does not
  eliminate this: the v2 fixtures land in the same PR as the v2
  schema, so an author error in fixture authoring cannot be caught by
  the schema until the next PR.
- **Validator semantics \u2260 semantic accuracy.** The
  `user_directive_source_url:` field is checked for shape and same-repo
  identity. The validator does NOT click through to confirm the quoted
  text actually appears in context, nor that the quote (in context)
  authorizes the specific bypass claimed. Critic and Judge remain the
  semantic backstop; a sufficiently motivated author could fabricate a
  quote that passes structural validation. The three-class evidence
  taxonomy is similarly a shape gate: it cannot detect a fabricated
  `class: pragmatic` permalink, only that some URL is present.
- **Plan authors must learn a new field set.** v2 plans require
  understanding which gate states need which companion fields. The
  template additions and `process_gates.md` documentation reduce this
  cost, but it is non-zero.
- **Validator complexity grows.** Stage 2 of this ADR's implementation
  adds three new validator paths (`_validate_gate_status`,
  `_validate_verification_evidence`, `_validate_user_bypass_guard`) and
  a `DeprecationWarning` emitter for legacy `exemption_reason`. More
  code, more places for bugs.

### Neutral

- Coexistence is indefinite. Future work may schedule a v1 sunset in a
  follow-up ADR after observing v2 adoption, but this ADR does not.
- The `bypass_label` allow-list lives in `.context/rules/process_gates.md`
  rather than in this ADR so the list can evolve without ADR churn.
  Edits to the allow-list still require a PR and still get reviewed,
  but they do not require a new ADR.
- The outcome \u2192 evidence-class matrix lives in
  `.context/rules/process_work_style.md` for the same reason.

## Known limitations

These limitations are explicit and accepted; they are NOT intended to
be addressed in this ADR's implementation:

1. **`bypass_label` provenance is not validated.** The validator
   confirms the label appears on the allow-list but does NOT confirm
   the label has actually been applied to the PR via GitHub's label
   API. A future ADR may add a CI check that cross-references applied
   labels against declared `bypass_label:` values.
2. **`user_directive` semantic accuracy is not validated.** Only
   structural presence and source-URL shape are checked. Selective
   extraction (quoting "proceed" out of a comment that says "do not
   proceed without QA") would pass schema validation and be caught
   only by Critic's manual click-through. This is by design \u2014 the
   schema is a structural guard, not a semantic one \u2014 but it must not
   be confused with a complete defense against the PR #337 class.
3. **Evidence class is a shape gate, not a semantic gate.** A
   `class: pragmatic` entry whose `url:` resolves to an unrelated
   workflow run or comment will pass schema validation. Judge and
   Critic verify the URL is actually evidence for the claim.
4. **Sunset of `exemption_reason:` is out of scope.** The legacy field
   remains accepted indefinitely. Migrating archived plans is out of
   scope; only new plans authored after this ADR adopt v2.

## Implementation

Implementation lands in five staged commits within the PR that ships
this ADR:

- [x] Stage 1 \u2014 Architect-owned: this ADR, `docs/compliance_schemas.md`
      v2 sections (additive), `docs/decisions/README.md` index +
      status flips, `.agents/{analyst,judge,critic}.md` role-contract
      v2 with binding-constraint, gate-status BLOCK, and evidence-class
      review rules.
- [ ] Stage 2 \u2014 DevOps-owned: `scripts/lib/compliance_schema.py`
      v2 validator paths (`_validate_gate_status`,
      `_validate_verification_evidence`, `_validate_user_bypass_guard`,
      `DeprecationWarning` emitter); `scripts/validate-compliance-*.py`
      wiring; v2 fixtures under `scripts/tests/fixtures/compliance/`
      covering valid + anti-example cases per evidence class and per
      bypass-guard field.
- [ ] Stage 3 \u2014 Docs-owned: `.context/rules/process_work_style.md`
      "Evidence taxonomy" section; `.context/rules/process_gates.md`
      `gate_status` vocabulary + bypass-label allow-list +
      `user-bypassed` subsection; `.github/PLAN_TEMPLATE.md` and
      `.github/pull_request_template.md` v2 block additions;
      `AGENTS.md` version bump.
- [ ] Stage 4 \u2014 QA sandbox: six pragmatic sandbox exercises (one per
      gate_status state, plus one per evidence class) and seven
      mechanical greps validating cross-file references.
- [ ] Stage 5 \u2014 Judge diff-gate + Critic semantic review of the v2
      dogfood block on the PR.

## Verification

- **V1** (logical) \u2014 `docs/compliance_schemas.md` § "`gate_status` v2"
  documents the enum and per-state companion fields.
- **V2** (logical) \u2014 `docs/compliance_schemas.md` §
  "`verification_evidence` v2" documents the three classes and per-class
  artifact shape.
- **V3** (mechanical) \u2014 `bash test.sh` passes after Stage 1;
  `python scripts/validate-compliance-examples.py docs/compliance_schemas.md`
  validates the new v2 examples post-Stage-2.
- **V4** (mechanical) \u2014 anti-example fixtures under
  `scripts/tests/fixtures/compliance/gate-status/` are rejected by the
  validator with the expected error class (post-Stage-2).
- **V5** (pragmatic) \u2014 the PR shipping this ADR posts a
  `parent_compliance` block at `schema_version: 2` with at least one
  `gate_status: passed` entry and a `verification_evidence[]` block
  exercising all three classes; the comment URL appears in the PR body
  and in the Phase 6 closeout `agent-state:v1` cadence comment.

## Supersedes

- Partially supersedes [ADR-005](./adr-005-analyst-preflight-gate.md)
  \u2014 the "Pre-Flight recommendations are advisory" framing is replaced
  by the binding-deliverable-level constraint rule in Decision (4).
- Partially supersedes [ADR-011](./adr-011-plan-as-comment-requirement.md)
  \u2014 the v1 `exemption_reason:` free-text framing is replaced by the
  `gate_status:` enum and three-field bypass guard under v2. v1
  `exemption_reason:` remains valid indefinitely under coexistence.
- Partially supersedes [ADR-014](./adr-014-extend-preflight-to-adhoc-deliverables.md)
  \u2014 ad-hoc deliverable Pre-Flight reports under v2 use binding
  deliverable-level constraints with the same Judge mediation rule.

## References

- [ADR-005](./adr-005-analyst-preflight-gate.md) \u2014 Analyst Pre-Flight gate.
- [ADR-011](./adr-011-plan-as-comment-requirement.md) \u2014 Plan-as-comment requirement.
- [ADR-014](./adr-014-extend-preflight-to-adhoc-deliverables.md) \u2014 Extend Pre-Flight to ad-hoc deliverables.
- [ADR-026](./adr-026-compliance-contracts.md) \u2014 v1 compliance contracts.
- [ADR-027](./adr-027-opportunity-feedback-channel.md) \u2014 Opportunity feedback channel (v1.2 `opportunity_notes` field; coexists unchanged under v2).
- [`docs/compliance_schemas.md`](../compliance_schemas.md) \u2014 schema v1 + v2 reference.
- [`.context/rules/process_gates.md`](../../.context/rules/process_gates.md) \u2014 bypass-label allow-list and gate vocabulary (added in Stage 3).
- [`.context/rules/process_work_style.md`](../../.context/rules/process_work_style.md) \u2014 evidence taxonomy and outcome → required class matrix (added in Stage 3).
- Postmortem for PR #337 \u2014 self-exemption failure mode (postmortem-005).
- Postmortems for PR #314 and PR #344 \u2014 weaker-evidence substitution failure modes.
