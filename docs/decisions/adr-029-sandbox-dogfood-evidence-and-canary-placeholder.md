# ADR-029: Sandbox dogfood evidence requirement + canary placeholder convention

## Status

Accepted

Supersedes ADR-028 in full. Narrows ADR-021 §"Per-file cadence bump" scope.
Overrides `docs/compliance_schemas.md` §"Schema versioning" one-cycle
backward-compat default for the Phase C migrations recorded in this ADR.

## Date

2026-05-20

## Context

Issue #349 surfaced two related failure modes:

1. **Self-exemption of pre-implementation gates.** The previous
   `exemption_reason` field on `plan_gate`/`diff_gate` allowed an agent to
   declare a gate satisfied by writing free-form prose into its own
   compliance block — a textual self-attestation with no external anchor.
   ADR-028 attempted to repair this with an `external_anchor` exemption
   predicate (label-applied / approver-quorum / etc.). On reconsideration
   that predicate added complexity without closing the underlying loophole:
   the schema still let the *author* assert satisfaction of the predicate.
2. **AGENTS.md canary drift in example YAMLs.** Eight code blocks in
   `docs/compliance_schemas.md` and ~45 lines across
   `scripts/tests/fixtures/compliance/**/*.yml` hardcoded the numeric
   `AGENTS_MD_VERSION` and matching `Session handshake v<N>` token. Every
   AGENTS.md bump required mechanical sed updates in unrelated files and
   was a recurring source of stale examples.

Phases B–D of #349's plan removed ADR-028, replaced `exemption_reason` with
a descriptive `gate_status: {triggered, applied}` sub-block, dropped the
unused per-block `schema_version: 1` field, and replaced ~21 hand-rolled
invalid YAML fixtures with a programmatic
`compliance_fixture_factory.py`. This ADR records the remaining decisions
that bind those mechanical changes together: the *behavioral* gate that
replaces self-exemption (mandatory sandbox dogfood evidence on every PR),
the canary placeholder convention, and the supersessions and transition
policy that ship with them.

## Decision

### 1. Sandbox dogfood evidence requirement

Every PR opened against `mikejmckinney/ai-repo-template`'s default branch
MUST include a `## Sandbox dogfood evidence` section with all 5 fields
populated. Each field's value MUST be a permalink to a sandbox issue, PR,
or PR-comment on `mikejmckinney/ai-repo-template-sandbox`, satisfying the
per-field value regex below. All 5 values must be pairwise-distinct URLs.

There is no override field, no bypass token, and no "n/a" textual escape.
The enforcement boundary is the PR-level evidence section. If a change
cannot be exercised through the sandbox, the change is out of scope for
this repo's default branch. The `gate_status: {triggered, applied}`
sub-block on `plan_gate`/`diff_gate` is descriptive only — it records
*whether* a gate fired and *whether* the parent claims it was applied; it
is not the audit channel. The audit channel is the sandbox evidence
section.

### 2. Canonical 5 field labels + parser contract

The PR template, `.agents/judge.md` diff-gate checklist, and
`scripts/verify-pr.sh` consume exactly five labels. The section header is
the literal `## Sandbox dogfood evidence`.

```
Sandbox issue: <URL>
Sandbox PR: <URL>
Negative control: <URL>
Positive control: <URL>
Role-comment render: <URL>
```

Parser rule: for each label, extract the substring after `<label> ` (one
space) up to end-of-line, trim whitespace, apply the per-field value regex
below. Missing label, missing value, multiple values per label, any extra
label, or absence of the section header itself = malformed.

### 3. Per-field value regexes + test vectors

| Field | Value regex |
|---|---|
| `Sandbox issue` | `^https://github\.com/mikejmckinney/ai-repo-template-sandbox/issues/[0-9]+$` |
| `Sandbox PR` | `^https://github\.com/mikejmckinney/ai-repo-template-sandbox/pull/[0-9]+$` |
| `Negative control` | `^https://github\.com/mikejmckinney/ai-repo-template-sandbox/pull/[0-9]+#issuecomment-[0-9]+$` AND linked comment body must start with `DECISION: BLOCK` |
| `Positive control` | `^https://github\.com/mikejmckinney/ai-repo-template-sandbox/pull/[0-9]+#issuecomment-[0-9]+$` AND linked comment body must start with `DECISION: APPROVE` |
| `Role-comment render` | `^https://github\.com/mikejmckinney/ai-repo-template-sandbox/pull/[0-9]+#issuecomment-[0-9]+$` AND linked comment body must contain the literal `## Judge — DECISION` H2 header |

Inline test vectors (each regex has one positive and one negative):

| Regex | Positive vector | Negative vector |
|---|---|---|
| `Sandbox issue` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/42` | `https://github.com/mikejmckinney/ai-repo-template/issues/42` (wrong repo) |
| `Sandbox PR` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/7` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/` (missing number) |
| `Negative control` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/7#issuecomment-4500000000` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/7` (no comment anchor) |
| `Positive control` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/7#issuecomment-4500000001` | `https://user-images.githubusercontent.com/.../image.png` (image URL) |
| `Role-comment render` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/pull/7#issuecomment-4500000002` | `https://github.com/mikejmckinney/ai-repo-template-sandbox/issues/42#issuecomment-4500000002` (issue, not PR) |

### 4. Anti-collapse (pairwise distinctness)

All 5 values must be pairwise-distinct URLs. `verify-pr.sh` checks via
set-size after extracting all 5 values. Belt-and-suspenders against a
future regex relaxation that admits collapse.

### 5. Structural vs semantic

Body-prefix checks (`DECISION: BLOCK` / `DECISION: APPROVE` / `## Judge —
DECISION`) are structural, not cryptographic; sandbox-repo write-access
controls and human diff-gate review are the security boundary.

### 6. Critic-before-Judge plan-gate ordering convention (Δ14)

`.github/prompts/op-issue-workflow.md` Phase 3 (plan-gate) dispatches
Critic *before* Judge, matching Phase 5 (diff-gate) ordering already
established. Critic surfaces hidden assumptions and AI clichés on the
plan; Judge then renders APPROVE / REQUEST_CHANGES / BLOCK with full
information. Reversing the order forces Judge to render twice when Critic
later catches issues. This convention applies to all OP-mediated
plan-gates, not only #349's.

### 7. Canary placeholder convention

Example YAML blocks in `docs/compliance_schemas.md` use the literal token
`<N>` in place of a pinned `AGENTS_MD_VERSION` value. The validator
(`compliance_schema.load_markdown_yaml_blocks`) substitutes the live
integer from `AGENTS.md` before YAML parsing. Real compliance blocks
(plan/parent/subagent in PRs, fixture YAMLs, factory output) MUST carry
the live numeric value. Hardcoding the integer in documentation examples
is forbidden — it couples docs to the AGENTS.md bump cadence and was a
recurring drift source (issue #349).

The fixture factory `scripts/tests/helpers/compliance_fixture_factory.py`
also resolves the live value at build time, so no fixture restamp is
required when AGENTS.md bumps.

### 8. Schema versioning override (Phase C migrations)

This ADR explicitly overrides
`docs/compliance_schemas.md` §"Schema versioning" one-cycle backward-compat
default for two breaking changes shipped together in #349 Phase C:

1. **`exemption_reason` → `gate_status` swap.** The old field accepted
   free-form strings, including `null`, and was used in practice as a
   self-exemption escape. The new `gate_status: {triggered, applied}`
   sub-block is descriptive only.
2. **Removal of the per-block `schema_version` field.** The field's only
   value was ever `1`. It was unused migration insurance for a
   backward-compat policy this ADR overrides.

Rationale: (a) `exemption_reason` was almost always `null` in practice, so
in-flight migration cost is negligible; (b) maintaining dual acceptance
creates two schemas to satisfy, defeats the simplification goal, and
creates a fresh rationalization surface (agents can choose which schema
to claim against); (c) in-flight PRs are few and can be updated by hand.

After this ADR lands, `docs/compliance_schemas.md` §"Schema versioning"
itself records: "Breaking schema changes may be one-shot when accompanied
by an ADR justifying the override; the default is one-cycle backward
compat."

### 9. ADR-021 §"Per-file cadence bump" narrowing

ADR-021 originally implied the `AGENTS_MD_VERSION` canary covers
`AGENTS.md` *and* its decomposed per-concern files under
`.context/rules/process_*.md`. The narrowing recorded here (already
reflected in the AGENTS.md inline comment "per-concern files in
.context/rules/ evolve through their own PRs and aren't gated by this
token") makes the scope explicit: the canary covers `AGENTS.md` content
only. Per-concern files evolve through their own PRs without bumping the
canary.

### 10. Transition policy for in-flight PRs

Every PR open at #351 merge time MUST either retrofit a real
`## Sandbox dogfood evidence` section with 5 valid permalinks, or be
closed and reopened against the new rule after the author has produced
the evidence. There is no owner-override and no grandfathering. The
enumeration template below is filled at Phase I after sandbox dogfood
clears Phase G.

```
| PR | Author | Disposition | Notes |
|---|---|---|---|
| #<N> | <login> | retrofit / descope | <permalink to evidence or close action> |
```

## Consequences

### Positive

- One enforcement boundary (PR-level evidence section) instead of two
  (schema field + behavioral rule). Less rationalization surface.
- Canary placeholder convention eliminates ~45 lines of mechanical
  AGENTS.md-bump churn across fixtures and docs.
- Phase C migrations land cleanly without dual-schema acceptance.

### Negative

- In-flight PRs at #351 merge time must retrofit or descope. No
  grandfathering. This is intentional but creates one-time author work.
- Sandbox repo write access becomes a hard prerequisite for landing PRs.
  Documented in `docs/guides/sandbox-verification.md`.

### Drift detection

`scripts/checks/` ships a label-drift detector that asserts the 5
canonical labels appear verbatim in:

- `.github/pull_request_template.md`
- `.agents/judge.md`
- `scripts/verify-pr.sh`

Drift = the label set extracted from any of those files differs from the
list in §2 of this ADR. CI fails with a diff hint.

## Verification

- `bash test.sh` — full suite green
- `python3 scripts/validate-compliance-examples.py` — examples parse with
  `<N>` substitution
- `python3 scripts/validate-compliance-fixtures.py` — fixture validator
  green
- `scripts/checks/<NNN>-sandbox-evidence-labels.sh` — drift detector green
- Phase G dogfood produces 5 pairwise-distinct sandbox permalinks
  satisfying §3 regexes + content checks; recorded in PR #351
  §"Sandbox dogfood evidence"

## References

- Issue #349 — original need: close analyst self-exemption + require
  dogfood evidence
- PR #351 — this implementation
- ADR-021 — per-file cadence bump (narrowed by §9 above)
- ADR-028 — superseded in full by this ADR
- ADR-016 — pre-merge verification gate (companion structural rule)
- ADR-026 — compliance contracts (the schema this ADR's gate_status sits
  inside)
- `docs/guides/sandbox-verification.md` — sandbox bootstrap
- `.context/rules/process_pr_completion.md` — §"Sandbox dogfood evidence
  requirement" consumes the labels above
