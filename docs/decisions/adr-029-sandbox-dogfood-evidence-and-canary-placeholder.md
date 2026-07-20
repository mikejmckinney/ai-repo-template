# ADR-029: Sandbox dogfood evidence requirement + canary placeholder convention

## Status

Accepted

Narrows ADR-021 §"Per-file cadence bump" scope.
Overrides `docs/compliance_schemas.md` §"Schema versioning" one-cycle
backward-compat default for the Phase C migrations recorded in this ADR.

## Date

2026-05-20

## 2026-07-20 Current-State Amendment

The sandbox outcome requirement and canonical `Sandbox issue:` / `Sandbox PR:`
labels remain active. ADR-026 retired structured compliance contracts, and
ADR-031 retired the Judge role and role pipeline. The former check 157 drift
detector and Judge checklist no longer exist; current enforcement is the PR
template, `AGENTS.md` outcome contract, live review, and the sandbox playbook.
Sections 2-6 and the original verification record below describe the historical
implementation rather than active mirror-maintenance instructions.

## Context

Issue #349 surfaced two related failure modes:

1. **Self-exemption of pre-implementation gates.** The previous
   `exemption_reason` field on `plan_gate`/`diff_gate` allowed an agent to
   declare a gate satisfied by writing free-form prose into its own
   compliance block — a textual self-attestation with no external anchor.
    An earlier `external_anchor` exemption-predicate design
    (label-applied / approver-quorum / etc.) added complexity without
    closing the underlying loophole: the schema still let the *author*
    assert satisfaction of the predicate.
2. **AGENTS.md canary drift in example YAMLs.** Eight code blocks in
   `docs/compliance_schemas.md` and ~45 lines across
   `scripts/tests/fixtures/compliance/**/*.yml` hardcoded the numeric
   `AGENTS_MD_VERSION` and matching `Session handshake v<N>` token. Every
   AGENTS.md bump required mechanical sed updates in unrelated files and
   was a recurring source of stale examples.

Phases B–D of #349's plan removed the exemption-predicate approach,
replaced `exemption_reason` with a descriptive
`gate_status: {triggered, applied}` sub-block, dropped the unused per-block
`schema_version: 1` field, and replaced ~21 hand-rolled invalid YAML
fixtures with a programmatic
`compliance_fixture_factory.py`. This ADR records the remaining decisions
that bind those mechanical changes together: the *behavioral* gate that
replaces self-exemption (mandatory sandbox dogfood evidence on every PR),
the canary placeholder convention, and the supersessions and transition
policy that ship with them.

## Decision

### 1. Sandbox dogfood evidence requirement

Every PR opened against this repo's default branch MUST include a
`## Sandbox dogfood evidence` section with two fields populated:
`Sandbox issue:` and `Sandbox PR:`. Each value MUST be a permalink to an
issue or PR in a sandbox sibling repo where the change was actually
exercised before being proposed here.

**Batch fix PR exception (§1.1):** daily/weekly retro fix draft PRs may
use `n/a` for one or both labels when the fix job logged
`sandbox: skipped — no workflow regression scope` and all implemented
findings passed local pre/post reproduction. See §1.1.

This ADR is repo-agnostic. Derived repositories using this template will
have their own sandbox sibling (the convention is `<repo>-sandbox`,
but nothing in this ADR pins the sandbox to a specific URL). The
example sandbox used by ai-repo-template is `ai-repo-template-sandbox`;
derived repos will substitute their own as specified in the
[sandbox verification playbook](/docs/guides/sandbox-verification.md)
which details the process for using sandbox and which sandbox instance to use.

The enforcement boundary is the PR-level evidence section. If a change
cannot be exercised through a sandbox, the change is out of scope for
the default branch. The `gate_status: {triggered, applied}` sub-block on
`plan_gate`/`diff_gate` is descriptive only — it records *whether* a
gate fired and *whether* the parent claims it was applied; it is not the
audit channel. The audit channel is the sandbox evidence section.

### 1.1 Batch fix PR verification (daily / weekly fix jobs)

When repository variable `FIX_JOB_SANDBOX_VERIFY=true` on the **upstream**
repo (default `false`), the fix job in `agent-postmerge-retro.yml` /
`agent-weekly-review.yml` MUST:

1. **Reporting agent** — each `follow_up_issues` row that becomes a fix
   finding includes non-empty `repro_steps[]` (how to reproduce the bug).
2. **Fix agent** — for each `findings[]` row by `dedupe_key`:
   - Run `repro_steps` **before** implementing (pre-repro). If the bug
     cannot be reproduced on the current branch, record
     `verify.pre: cant_reproduce` and **skip implementation for that
     finding only** (other findings continue).
   - After implementing, run `repro_steps` again (post-repro). Record
     `verify.post: fixed` only when `verify.pre` was `reproduced` or
     `skipped_collateral`.
   - Write `retro/fix-verify-<RUN_DATE>.json` or
     `weekly/fix-verify-<RUN_WEEK>.json` on the fix branch and render
     `## Fix verification` on the draft PR body from that file.
3. **End of job** — after all findings are addressed, run `./test.sh`
   when scripts/workflows/checks changed.
4. **Sandbox batch (end only)** — push once to sandbox branch
   `test/fix-retro-<RUN_DATE>` or `test/fix-weekly-<RUN_WEEK>` when any
   changed path is on the runtime path of a default-branch-only workflow
   that local verification cannot exercise. Otherwise log
   `sandbox: skipped — no workflow regression scope` and set sandbox
   evidence labels to `n/a` on the upstream draft PR.
5. **Workflow YAML on upstream** — fix job tokens still cannot push
   `.github/workflows/**` on upstream; workflow fixes are proved on
   sandbox; upstream PR may ship script/lib changes only.

**Recursion guard:** jobs running on a `*-sandbox` repository OR with
`SKIP_SANDBOX_FIX_VERIFY=true` skip automated sandbox sync.

**Failure semantics:** sandbox verify failure marks umbrella Meta
`sandbox verify: failed` and leaves the upstream PR **draft**; the draft
PR is still created/updated.

**Ephemeral artifact:** `fix-verify.json` on the fix branch is a review
artifact; remove manually before undraft/merge. The PR body's
`## Fix verification` section is the durable record on GitHub.

### 2. Canonical field labels

The PR template (`.github/pull_request_template.md`) and `.agents/judge.md`
diff-gate checklist (item 20) consume exactly two labels. The section
header is the literal `## Sandbox dogfood evidence`.

```text
Sandbox issue: <URL>
Sandbox PR: <URL>
```

Both values must be present, non-empty, and point at distinct URLs in a
sandbox repo (issue link and PR link are inherently distinct by GitHub's
`/issues/` vs `/pull/` path discriminator). Missing label, missing value,
or absence of the section header itself = malformed. Values of `n/a` are
permitted only under §1.1 batch-fix local-verify exception.

### 3. Structural vs semantic

Label/URL presence is a structural check the drift detector and judge
checklist can enforce mechanically. Content checks — that the sandbox
issue actually describes the change, that the sandbox PR actually
exercises it should also be reviewed by judge and if needed critic.

### 4. Historical plan-gate ordering convention (Δ14)

The former role pipeline dispatched Critic before Judge so the final gate
received all review evidence. ADR-031 retired that pipeline; this section is
retained only as historical rationale and is not an operational instruction.

### 5. Canary placeholder convention

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

### 6. Schema versioning override (Phase C migrations)

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

### 7. ADR-021 §"Per-file cadence bump" narrowing

ADR-021 originally implied the `AGENTS_MD_VERSION` canary covers
`AGENTS.md` *and* its decomposed per-concern files under
`.context/rules/process_*.md`. The narrowing recorded here (already
reflected in the AGENTS.md inline comment "per-concern files in
.context/rules/ evolve through their own PRs and aren't gated by this
token") makes the scope explicit: the canary covers `AGENTS.md` content
only. Per-concern files evolve through their own PRs without bumping the
canary.

### 8. Transition policy for in-flight PRs

Every PR open at this ADR's adoption time that touches the surfaces
listed in §1 MUST either retrofit a real `## Sandbox dogfood evidence`
section with the two valid permalinks, or be closed/descoped. There is no
owner-override and no grandfathering. PRs that the maintainer chooses to
close without merging are not retrofit candidates — the transition policy
applies only to PRs that will be merged.

## Consequences

### Positive

- One enforcement boundary (PR-level evidence section) instead of two
  (schema field + behavioral rule). Less rationalization surface.
- Canary placeholder convention eliminates ~45 lines of mechanical
  AGENTS.md-bump churn across fixtures and docs.
- Phase C migrations land cleanly without dual-schema acceptance.

### Negative

- In-flight PRs that touch the surfaces in §1 must retrofit or descope at
  adoption time. No grandfathering. PRs the maintainer chooses to close
  without merging are exempt by definition. This is intentional but
  creates one-time author work.
- Sandbox repo write access becomes a hard prerequisite for landing PRs
  on those surfaces. Documented in `docs/guides/sandbox-verification.md`.

### Drift detection

`scripts/checks/157-sandbox-evidence-labels.sh` asserts the two canonical
labels appear verbatim in:

- `.github/pull_request_template.md`
- `.agents/judge.md`

Drift = the label set extracted from any of those files differs from the
list in §2 of this ADR. CI fails with a diff hint.

## Verification

- `bash test.sh` — full suite green, including the 157 drift detector and
  the `compliance-contracts.bats` suite (wired via
  `scripts/checks/158-compliance-contracts.sh`)
- `python3 scripts/validate-compliance-examples.py` — examples parse with
  `<N>` substitution
- `python3 scripts/validate-compliance-fixtures.py` — fixture validator
  green
- Sandbox dogfood for #351 itself: see PR body §"Sandbox dogfood
  evidence" for the two permalinks

## References

- Issue #349 — original need: close analyst self-exemption + require
  dogfood evidence
- PR #351 — this implementation
- ADR-021 — per-file cadence bump (narrowed by §7 above)
- ADR-016 — pre-merge verification gate (companion structural rule)
- ADR-026 — compliance contracts (the schema this ADR's gate_status sits
  inside)
- `docs/guides/sandbox-verification.md` — sandbox bootstrap
- `.github/pull_request_template.md` and `.agents/judge.md` — consuming
  surfaces for the §2 labels (enforced by
  `scripts/checks/157-sandbox-evidence-labels.sh`)
