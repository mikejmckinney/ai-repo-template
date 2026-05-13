# ADR-026: Agent compliance contracts and role receipt evidence

## Status

Accepted

## Date

2026-05-13

## Context

Recent agent sessions exposed two related failures in this repository's
process discipline:

1. The parent/default agent can have `AGENTS.md` in context and still skip
   the required `Session handshake v<N>` canary.
2. Dispatched subagents can return role output without observable evidence
   that they received enough context, loaded their canonical role contract,
   or followed the required process rules.

ADR-021 deliberately decomposed `AGENTS.md` into a thin contract plus
per-concern process files. ADR-023 deliberately moved role bodies into
canonical `.agents/<role>.md` files and left vendor folders as thin
registration overlays. Those decisions are still sound, but they leave a
reviewability gap: availability of instruction bytes is not proof that an
agent followed them, and parent summaries of subagent behavior are not
sufficient audit evidence.

Issue #307 and its consensus plan define the user outcome: future agents and
human reviewers should be able to inspect the issue plan, PR body, subagent
evidence, Judge/Critic outputs, and static-check results to determine
whether startup compliance, pointer loading, role-dispatch decisions,
subagent bootstrapping, required gates, and process deviations were actually
disclosed before implementation or review proceeds.

This ADR supersedes ADR-011 and ADR-023 in part:

- **ADR-011 in part** — plan/PR artifacts now gain structured compliance
  evidence and later deterministic validation. The plan-as-comment rule,
  PR-link rule, and exemptions remain.
- **ADR-023 in part** — canonical role bodies now also carry the
  versioned role contract that subagent compliance evidence reports. The
  canonical/overlay split remains.

## Decision

We will add a repository-level compliance contract with three schema blocks
and one role-contract versioning rule.

### Parent compliance

The parent/default agent remains governed by `AGENTS.md` and its
`AGENTS_MD_VERSION` marker. Its first substantive user-facing response must
continue to begin with `Session handshake v<N>`, where `N` matches the
loaded `AGENTS_MD_VERSION`.

Plans and PRs will record parent compliance evidence in structured YAML. The
fields are defined in `docs/compliance_schemas.md` and include the parent
handshake token, `AGENTS.md` version, runtime pointer evidence, applicable
roles, plan/diff gate state, ADR state, and deviations.

### Plan compliance

Implementation plans will include a `plan_compliance` block. The block
captures the pre-implementation role-dispatch decision, applicable process
resources, required gates, ADR requirement, and evidence that loaded
resources affected decisions. This extends ADR-011's plan artifact without
removing ADR-011's plan-as-comment requirement.

### Subagent compliance

Every dispatched subagent must return a `subagent_compliance` block. Parent
agents copy parsed subagent compliance objects into
`parent_compliance.subagents_dispatched` in the PR body. A raw verbatim block
may also be preserved as a block scalar for provenance, but validators read
parsed object fields, not nested raw YAML text.

Subagent compliance records:

- role name,
- `role_contract_version`,
- parent `agents_md_version`,
- receipt evidence,
- context/process files used,
- skipped pointers with reasons,
- task scope,
- files modified,
- gates invoked.

Missing subagent compliance makes that subagent output unusable as gate
evidence. It is not proof that the runtime dispatch failed; it is proof that
the PR lacks usable compliance evidence.

### Role contract versioning

Use `role_contract_version`, not `overlay_version`, in v1.

- `role_contract_version` is owned only by canonical role files under
  `.agents/<role>.md`.
- Platform overlays under `.github/agents/` and `.claude/agents/` continue
  to own only platform registration fields such as `name`, `description`,
  `tools`, `model`, and Copilot `handoffs`.
- `scripts/checks/050-agent-mirror.sh` may validate canonical
  `role_contract_version` presence/format, but it must not require platform
  overlays to carry that value.
- Bump `role_contract_version` only when a canonical role's bootstrap,
  output format, handoff behavior, or compliance return contract changes.

### Exact-output role coexistence

Some roles have exact first-line output contracts. Judge responses begin
with `DECISION:`. Critic responses begin with `CRITIC DECISION:`. Compliance
receipts must not break those contracts.

Therefore:

- The parent/default-agent first substantive line remains
  `Session handshake v<N>`.
- Exact-output roles satisfy receipt evidence through their trailing
  `subagent_compliance` block, or through structured parent-captured receipt
  evidence if the runtime later supports it.
- Non-exact roles may emit `Role receipt v<N> — <role>` as a first line, but
  the authoritative audit field is still `subagent_compliance.receipt`.

### Enforcement sequencing

Compliance enforcement rolls out in stages:

1. Define ADR-026, `docs/compliance_schemas.md`, and `.agents/_TEMPLATE.md`.
2. Add startup/bootstrap contracts and migrate canonical role files.
3. Add plan/PR template evidence fields.
4. Add Judge/Critic review rules and static presence checks.
5. Add validator scripts and PR-body compliance reporting in warning mode.
6. Promote deterministic schema/version mismatches to hard-fail only after a
   real PR passes cleanly, malformed synthetic fixtures fail as expected, and
   Judge re-approves the promotion criteria.

Existing hard-gate severities remain unchanged. Missing required Analyst
Pre-Flight PASS, ADR supersession failures, required doc-trigger omissions,
false verification, PR-link hard-gate failures, and unsafe ownership/gate
bypass remain `BLOCK`. New missing or malformed compliance evidence starts as
`REQUEST_CHANGES` until ADR-026's hard-fail promotion criteria are met.

CI must never claim to prove Copilot runtime dispatch or handoff execution.
It validates declared evidence shape, schema conformance, version currency,
and file references only.

## Options Considered

### Option 1: Structured compliance schemas with staged enforcement (chosen)

- **Pros**: Gives reviewers and automation a concrete artifact to inspect;
  preserves existing startup, plan, and role architecture; avoids immediate
  false failures through warning-first CI; keeps runtime-proof claims out of
  CI.
- **Cons**: Adds process fields and fixtures that can become ceremony if
  Judge/Critic do not review evidence quality.

### Option 2: Template-only prose fields

- **Pros**: Low implementation cost and easy for humans to read.
- **Cons**: Too weak for deterministic validation and too easy to cargo-cult.
  It does not solve the observed failure where agents claimed instructions
  were read without evidence of decision impact.

### Option 3: Per-platform `overlay_version`

- **Pros**: Names the platform overlay as the versioned artifact and mirrors
  the term used in some candidate plans.
- **Cons**: Ambiguous under ADR-023 because platform overlays are registration
  shims, not canonical role contracts. It would also require platform overlays
  to duplicate a role-contract version they do not own. Rejected in favor of
  canonical `role_contract_version`.

### Option 4: Immediate hard-fail PR-body CI

- **Pros**: Strong enforcement from day one.
- **Cons**: High false-positive risk before templates, role contracts,
  examples, and validators exist. Rejected for v1 rollout; hard-fail can be
  promoted later after validation.

### Option 5: Runtime `runSubagent` wrapping

- **Pros**: Strongest possible enforcement because it can inject dispatch
  packets and validate returns at the tool boundary.
- **Cons**: Not an in-repo change for this template. Track as a follow-up;
  do not make ADR-026 depend on platform behavior the repo cannot control.

## Consequences

### Positive

- Reviewers gain structured evidence for parent startup, role-dispatch, gate,
  and subagent compliance decisions.
- Static checks can preserve guardrail fields and prevent future refactors
  from silently removing process evidence.
- Schema examples and fixtures give future phases a mechanical baseline.
- The canonical/overlay split remains intact: role contract metadata lives in
  `.agents/<role>.md`, while platform-specific registration stays in vendor
  folders.

### Negative

- Plans and PRs become longer. Mitigation: fields are trigger-scoped and
  allow explicit `N/A — <reason>` paths for trivial or exempt work.
- Schema blocks can become checkbox theater. Mitigation: require decision
  impact evidence and teach Judge/Critic to flag generic claims.
- Role contract versioning introduces another version number. Mitigation:
  bump only when a canonical role's compliance/output contract changes.

### Neutral

- ADR-021's `AGENTS.md` decomposition remains in force.
- ADR-023's canonical role body / thin overlay design remains in force.
- ADR-025's GitHub-first live-state model remains in force; compliance blocks
  are PR review artifacts, not replacements for `agent-state:v1` comments.
- ADR-012's branch/commit preconditions remain in force and are referenced as
  related workflow-precondition context.

## Implementation

- [x] Add ADR-026.
- [x] Mark ADR-011 as accepted but superseded in part by ADR-026.
- [x] Mark ADR-023 as accepted but superseded in part by ADR-026.
- [x] Update `docs/decisions/README.md` with ADR-026 and status changes.
- [x] Add `docs/compliance_schemas.md` with v1 schema documentation and
  parseable examples.
- [x] Add `.agents/_TEMPLATE.md` with canonical role contract metadata and
  return-contract guidance.
- [x] Update `.agents/README.md` to document `role_contract_version`, explain
  that `overlay_version` is not used in v1, and describe exact-output role
  coexistence.
- [x] Update `scripts/checks/050-agent-mirror.sh` so `_TEMPLATE.md` is not
  treated as a canonical role file.
- [x] Move/strengthen `AGENTS.md` startup contract and add
  `process_subagent_bootstrap.md`.
- [x] Migrate all existing role files to include `role_contract_version` and
  compliance return guidance.
- [x] Add Judge/Critic review checks for ADR-026 compliance evidence.
- [x] Add plan/PR template blocks, validators, fixtures, warning-mode static
  checks, and smoke prompts.
- [ ] Later phase: promote deterministic schema/version mismatches to hard
  failure after a real PR passes cleanly, malformed fixtures fail as expected,
  and Judge re-approves the promotion criteria.

## Verification

- `bash test.sh` — template integrity and parity checks pass.
- `python3 - <<'PY' ...` one-off YAML extraction/parse check — all YAML
  examples in `docs/compliance_schemas.md` parse successfully.
- `python3 scripts/validate-compliance-examples.py` — schema examples validate
  against ADR-026 v1.
- `python3 scripts/validate-compliance-fixtures.py` — valid fixtures pass and
  malformed fixtures fail as expected.
- `bats --tap scripts/tests/compliance-contracts.bats` — validator examples,
  fixture split, and invalid-single checks pass.
- `git diff --check` — no whitespace errors.

Future validation phases can promote deterministic schema/version mismatches
from warning-mode review evidence to hard-fail only after the promotion
criteria above are met.

## References

- Issue #307 — Enforce startup, pointer, and subagent compliance.
- Issue #305 — Add instruction compliance evidence to plan and PR templates.
- Issue #306 — Parent-agent handshake/dispatch + subagent return contract.
- Analyst Pre-Flight PASS: https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4435991348
- Judge plan-gate APPROVE: https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4436040309
- ADR-011 — superseded in part by this ADR.
- ADR-012 — related workflow-precondition rule.
- ADR-021 — extended by this ADR; status unchanged.
- ADR-023 — superseded in part by this ADR.
- ADR-025 — live state remains GitHub-first; status unchanged.
