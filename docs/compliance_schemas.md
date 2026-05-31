# Compliance schemas

This document defines v1 structured evidence blocks for agent compliance in
this repository. The schemas are review contracts first and automation inputs
second: they make process compliance visible without claiming that CI can prove
what a model actually read or intended.

ADR: [`ADR-026`](decisions/adr-026-compliance-contracts.md)

## Principles

- Evidence is trigger-scoped. Do not list every process file for every task.
  List resources that applied and the decision each affected.
- Parsed object fields are canonical. Raw copied text may be retained for
  provenance, but validators read parsed YAML objects.
- Parent/default-agent compliance is versioned by `AGENTS_MD_VERSION`.
- Subagent compliance is versioned by canonical role-file
  `role_contract_version`, not platform overlay metadata.
- Missing subagent compliance makes subagent output unusable as gate evidence.
  It does not prove a runtime dispatch failure.

## Schema versioning

All examples below are schema v1. Schema updates follow this policy:

- Additive optional fields may be introduced as v1.x and accepted alongside
  v1 for at least one release cycle.
- Required fields, renamed fields, removed fields, and type changes require a
  new major schema version and an ADR update.
- Breaking schema changes may be **one-shot** (without the one-cycle
  backward-compat window) when accompanied by an ADR that justifies the
  override. The default remains one-cycle backward compat. The Phase C
  swap of `exemption_reason` → `gate_status` and the removal of the
  per-block `schema_version` field are recorded one-shot transitions —
  see ADR-029.
- v1.2 (current for `agent-state:v1`) adds the optional
  `opportunity_notes` field to support the opportunity-feedback channel
  defined in `.context/rules/process_opportunity_feedback.md`. v1.2 is
  fully backward-compatible with v1.1 and v1 readers: the field is
  optional, absence is the default, and unknown-field tolerance applies
  for any earlier-minor reader. For **bare `agent-state:v1`** YAML blocks,
  the top-level dispatch heuristic in
  `scripts/lib/compliance_schema.py` (`validate_loaded_block`) only routes
  blocks whose `schema_version` is numerically exactly `1.2` through the
  agent-state validator; bare blocks declaring `1` or `1.1` keep their
  pre-PR-#344 behavior and fall through to the generic `unknown top-level
  keys` path. Authors emitting a new bare `agent-state:v1` block
  (including any with `opportunity_notes`) must declare
  `schema_version: 1.2`.

> **Note on `<N>` placeholders.** Examples below use the literal token
> `<N>` in place of a pinned `AGENTS_MD_VERSION`. Real compliance blocks
> must carry the live integer that matches the `AGENTS_MD_VERSION`
> marker at the top of `AGENTS.md`. The live value is resolved at runtime
> by `compliance_schema.current_agents_md_version()` (validator) and by
> `scripts/tests/helpers/compliance_fixture_factory.py` (test factory).
> Hardcoding a numeric value in examples couples the docs to AGENTS.md's
> version bump cadence and was a recurring source of stale-example drift
> (issue #349).

## `plan_compliance` v1

Emitted in implementation plans before substantive implementation begins.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `applicable_roles` | list of strings | yes | Roles whose ownership applies to the planned work. Empty only for trivial/exempt work. |
| `instruction_resources` | list of objects | yes | Each object has `resource`, `why_applicable`, `evidence`, and `decision_affected`. |
| `role_dispatch` | object | yes | `decision`, `planned_subagents`, and `monolithic_justification`. |
| `plan_gate` | object | yes | `status`, `link`, and `gate_status` (`{triggered, applied}`). |
| `adr_required` | object | yes | `required`, `link`, and `supersession_notes`. |
| `doc_sync` | object | yes | `triggered`, `companions`, and `no_change_justifications`. |
| `verification` | list of strings | yes | Exact commands or manual checks planned. |

### Example — filled `plan_compliance`

```yaml
plan_compliance:
  applicable_roles:
    - architect
    - docs
    - devops
  instruction_resources:
    - resource: AGENTS.md
      why_applicable: Canonical startup and truth-hierarchy contract.
      evidence: AGENTS_MD_VERSION <N>; Session handshake v<N> emitted.
      decision_affected: Kept parent handshake versioning tied to AGENTS.md.
    - resource: .context/rules/process_doc_maintenance.md
      why_applicable: Plan changes ADRs, role files, docs, and checks.
      evidence: Trigger table reviewed for ADR and role-file rows.
      decision_affected: Added ADR supersession matrix and companion file list.
  role_dispatch:
    decision: staged-dispatch
    planned_subagents:
      - architect
      - docs
      - devops
      - qa
    monolithic_justification: null
  plan_gate:
    status: linked
    link: https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4436040309
    gate_status:
      triggered: true
      applied: true
  adr_required:
    required: true
    link: docs/decisions/adr-026-compliance-contracts.md
    supersession_notes:
      - ADR-011 superseded in part.
      - ADR-023 superseded in part.
  doc_sync:
    triggered: true
    companions:
      - docs/decisions/README.md
      - .agents/README.md
      - AI_REPO_GUIDE.md
    no_change_justifications: []
  verification:
    - bash test.sh
    - git diff --check
```

## `parent_compliance` v1

Emitted in PR bodies by the parent/default agent before review.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `handshake_token` | string | yes | Exact parent token, format `Session handshake v<N>`. |
| `agents_md_version` | integer | yes | Version declared in `AGENTS.md`. |
| `runtime_pointer` | object | yes | Runtime instruction file evidence; see subfields below. |
| `applicable_roles` | list of strings | yes | Roles whose ownership applied to the final diff. |
| `subagents_dispatched` | list of objects | yes | Parsed `subagent_compliance` objects. Empty list requires `monolithic_justification`. |
| `monolithic_justification` | string or null | yes | Required if no subagents ran or if dispatched roles are a strict subset of applicable roles. |
| `plan_gate` | object | yes | `status`, `link`, `gate_status` (`{triggered, applied}`). |
| `diff_gate` | object | yes | `status`, `link`, `gate_status` (`{triggered, applied}`). |
| `adr_required` | object | yes | `required`, `link`. |
| `deviations` | list of objects | yes | Planned-vs-actual deviations; empty list allowed. |
| `verification_results` | list of objects | yes | Command/result pairs matching the plan. |

#### `runtime_pointer` subfields

| Field | Type | Required | Description |
|---|---|---:|---|
| `path` | string or null | yes | Runtime-specific instruction pointer loaded by the parent agent, such as `.github/copilot-instructions.md`. Use `null` only when no runtime pointer applies. |
| `loaded` | boolean | yes | Whether the parent agent reports loading that pointer. Use `false` when `path: null`. |
| `decision_affected` | string or null | yes | Specific parent decision affected by the pointer. Use `null` only when the PR is exempt or the pointer did not affect a decision. |
| `reason` | string | only when `path: null` | Why no runtime pointer path applies, for example `Non-Copilot runtime; root AGENTS.md loaded directly.` |

When `path` is a string, `loaded` must be `true` and `reason` is omitted.
When `path: null`, `loaded` must be `false`, `decision_affected` must explain
the exemption or be `null`, and `reason` must be a non-empty string.
Represent the no-pointer case with these explicit subfields in the same object;
do not encode the null-path reason in surrounding prose or in
`decision_affected` alone.

### Example — no-subagent `parent_compliance`

```yaml
parent_compliance:
  handshake_token: Session handshake v<N>
  agents_md_version: <N>
  runtime_pointer:
    path: .github/copilot-instructions.md
    loaded: true
    decision_affected: Removed Copilot-only repository browsing tools from PM overlay.
  applicable_roles:
    - architect
  subagents_dispatched: []
  monolithic_justification: Single overlay-tool change requested by maintainer; no role output used as gate evidence.
  plan_gate:
    status: linked
    link: https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4436040309
    gate_status:
      triggered: true
      applied: true
  diff_gate:
    status: pending
    link: null
    gate_status:
      triggered: true
      applied: false
  adr_required:
    required: false
    link: null
  deviations: []
  verification_results:
    - command: bash test.sh
      result: pass
      evidence: Local run passed with warnings only.
```

### Example — multi-subagent `parent_compliance`

```yaml
parent_compliance:
  handshake_token: Session handshake v<N>
  agents_md_version: <N>
  runtime_pointer:
    path: .github/copilot-instructions.md
    loaded: true
    decision_affected: Used Copilot-specific subagent dispatch guidance.
  applicable_roles:
    - architect
    - docs
    - devops
  subagents_dispatched:
    - role: docs
      role_contract_version: 1
      agents_md_version: <N>
      receipt:
        mode: visible-line
        value: Role receipt v1 — docs
      context_files_used:
        - AGENTS.md
        - .agents/docs.md
        - .context/rules/process_doc_maintenance.md
      pointers_skipped: []
      task_scope: Update human-facing guide links for compliance schema docs.
      files_modified:
        - AI_REPO_GUIDE.md
        - docs/guides/multi-agent-coordination.md
      gates_invoked:
        - doc-trigger-check
      run_status: SUCCESS
    - role: devops
      role_contract_version: 1
      agents_md_version: <N>
      receipt:
        mode: visible-line
        value: Role receipt v1 — devops
      context_files_used:
        - AGENTS.md
        - .agents/devops.md
        - .context/rules/process_work_style.md
      pointers_skipped: []
      task_scope: Add warning-mode compliance validator wiring.
      files_modified:
        - scripts/validate-compliance-fixtures.py
        - scripts/tests/compliance-contracts.bats
      gates_invoked:
        - verification
      run_status: SUCCESS
  monolithic_justification: Architect-owned planning stayed with the parent; docs and devops subagents covered the dispatched implementation slices.
  plan_gate:
    status: linked
    link: https://github.com/mikejmckinney/ai-repo-template/issues/307#issuecomment-4436040309
    gate_status:
      triggered: true
      applied: true
  diff_gate:
    status: pending
    link: null
    gate_status:
      triggered: true
      applied: false
  adr_required:
    required: true
    link: docs/decisions/adr-026-compliance-contracts.md
  deviations: []
  verification_results:
    - command: bash test.sh
      result: pass
      evidence: Local run passed.
```

## `subagent_compliance` v1

Emitted by every dispatched subagent at the end of its response. Exact-output
roles such as Judge and Critic keep their required first line and provide
receipt evidence in this block.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `role` | string | yes | Canonical role name matching `.agents/<role>.md`. |
| `role_contract_version` | integer | yes | Version declared by the canonical role contract. |
| `agents_md_version` | integer | yes | Parent `AGENTS.md` version used by the subagent. |
| `receipt` | object | yes | `mode` and `value`; exact-output roles may use `trailing-block`. |
| `context_files_used` | list of strings | yes | Files actually used for role output. |
| `pointers_skipped` | list of objects | yes | `{path, reason}` entries; empty list means none skipped. |
| `task_scope` | string | yes | Parent-assigned task in one paragraph. |
| `files_modified` | list of strings | yes | Files the subagent actually modified and verified post-edit; empty for review-only agents or for runs where edits did not land. Aspirational edits do not belong here. |
| `gates_invoked` | list of strings | yes | Gate names invoked or attested to; empty list allowed. |
| `run_status` | string | no (v1.1; default `SUCCESS`) | One of `SUCCESS`, `PARTIAL`, `BLOCKED_ON_RUNTIME`, `NEEDS_CONTEXT`. Optional at v1 to preserve backward compat per the versioning policy; absence implies `SUCCESS`. The silent-failure escape hatch (parent omits field on a failed dispatch) is addressed at the Judge diff-gate (`.agents/judge.md` item 19), not at the schema layer. See `.context/rules/process_subagent_bootstrap.md` § "Edit verification and pass-back contract". |
| `apply_replays` | list of objects | no (v1.1) | Byte-anchored patches the parent can replay when `run_status != SUCCESS`. Each entry: `{path, anchor, replacement}` where `anchor` is a unique literal substring in the target file and `replacement` is the literal substitute. Required (non-empty) when `run_status` ∈ `{PARTIAL, BLOCKED_ON_RUNTIME}` and any role-owned edit did not land. |
| `opportunity_notes` | list of objects | no (v1.2) | Per-dispatch opportunity-feedback notes. Each entry uses the 9-field shape defined in `.context/rules/process_opportunity_feedback.md` § "Required fields (9 total)": `title`, `evidence`, `impact`, `recommendation`, `scope`, `suggested_next_action`, `confidence`, `role_relevance`, `duplicate_check`. Capped at ≤3 entries per session per agent. Substantive-output subagents MUST include the field (empty list permitted); read-only subagents MAY omit. v1.2 is additive and fully backward-compatible with v1.1 readers (unknown field tolerated; absence is the default). |

### Example — Judge exact-output compliance

```yaml
subagent_compliance:
  role: judge
  role_contract_version: 1
  agents_md_version: <N>
  receipt:
    mode: trailing-block
    value: Judge exact-output preserved; DECISION remained first line.
  context_files_used:
    - AGENTS.md
    - .agents/judge.md
    - .context/rules/process_doc_maintenance.md
    - .context/rules/repo_orchestration_patterns.md
  pointers_skipped: []
  task_scope: Review the revised canonical plan for issue #307 in PLAN-GATE mode.
  files_modified: []
  gates_invoked:
    - plan-gate
  run_status: SUCCESS
```

### Example — Critic exact-output compliance

```yaml
subagent_compliance:
  role: critic
  role_contract_version: 1
  agents_md_version: <N>
  receipt:
    mode: trailing-block
    value: Critic exact-output preserved; CRITIC DECISION remained first line.
  context_files_used:
    - AGENTS.md
    - .agents/critic.md
    - .context/rules/repo_orchestration_patterns.md
  pointers_skipped:
    - path: docs/guides/design-patterns-post-gof.md
      reason: Not relevant to process-compliance review scope.
  task_scope: Review the compliance schema plan for checklist theater and hidden assumptions.
  files_modified: []
  gates_invoked:
    - critic-review
  run_status: SUCCESS
```

## `agent-state:v1`

The `agent-state:v1` GitHub-comment schema is defined by
`.context/state/agent_state_comment_template.md` (ADR-025). The
structured surfacing contract is mirrored here so validators and
reviewers have a single reference alongside the other v1 schemas.

### Versioning

Current schema is `1.2`. v1.2 adds the optional `opportunity_notes`
array to the comment body and is fully backward-compatible with v1.1
and v1 readers (unknown field tolerated; absence is the default).

### `opportunity_notes` field (v1.2, optional)

`opportunity_notes` is an optional array of objects, capped at ≤3
entries per session per agent. Each entry uses the 9-field shape
defined in `.context/rules/process_opportunity_feedback.md` §
"Required fields (9 total)": `title`, `evidence`, `impact`,
`recommendation`, `scope`, `suggested_next_action`, `confidence`,
`role_relevance`, `duplicate_check`. Empty list permitted;
partially-filled entries are not — all 9 fields are required per
entry per the rule.

### Example — `agent-state:v1` with `opportunity_notes`

```yaml
schema_version: 1.2
opportunity_notes:
  - title: "Pipeline label metadata lives in both setup and docs"
    evidence: "scripts/setup/40-ensure-labels.sh defines `_PIPELINE_LABEL_SPECS` inline, and docs/guides/agent-pipeline.md documents the same label set in its setup table."
    impact: "Setup guidance can drift from the labels the repo actually creates, which leaves operators with stale pipeline instructions."
    recommendation: "Consider a single manifest or a drift check that compares the setup label list against the documentation table."
    scope: script
    suggested_next_action: file-issue
    confidence: high
    role_relevance: [devops, docs]
    duplicate_check: "Search open issues for an existing label-manifest or doc-drift follow-up before filing a new one."
```

## CI-MUST validation rules for v1

When deterministic validation is enabled, validators fail on:

1. Missing required fields or wrong scalar/list/object types.
2. `schema_version` not equal to `1`.
3. Parent `handshake_token` not matching `Session handshake v<agents_md_version>`.
4. `agents_md_version` not matching the current `AGENTS_MD_VERSION` canary in `AGENTS.md`.
5. Use of `overlay_version` in any v1 block.
6. Unknown top-level sibling keys beside the single compliance block.
7. Missing `monolithic_justification` when `subagents_dispatched` is empty or when dispatched roles are a strict subset of `applicable_roles`.
8. `subagent_compliance.role` without a matching canonical `.agents/<role>.md` file.
9. `role_contract_version` mismatch with the canonical role file.
10. File paths in `files_modified` that are impossible for the PR diff.
11. Raw YAML-in-YAML under `subagents_dispatched` without parsed object fields.

## Judge-SHOULD review rules for v1

Judge should challenge:

1. Generic evidence such as `read all docs` without a decision impact.
2. Empty `applicable_roles` on non-trivial or role-owned diffs.
3. Monolithic default-agent work without a specific justification.
4. Skipped pointers with generic reasons such as `not relevant`.
5. Compliance blocks that claim runtime dispatch proof beyond what the repo can
   actually verify.

Critic should separately flag checklist theater, unsupported compliance claims,
and `bytes in context` reasoning used as a substitute for observable evidence.
