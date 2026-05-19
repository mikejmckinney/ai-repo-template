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
- Validators must keep accepting the previous major version for one release
  cycle after a breaking change unless Judge approves a narrower migration.
- v1.2 (current for `subagent_compliance` and `agent-state:v1`) adds the
  optional `opportunity_notes` field to support the opportunity-feedback
  channel defined in `.context/rules/process_opportunity_feedback.md`.
  v1.2 is fully backward-compatible with v1.1 and v1 readers: the field
  is optional, absence is the default, and unknown-field tolerance applies
  for any earlier-minor reader. Stage 3 (DevOps) extends validators to
  accept `schema_version` values `1`, `1.1`, and `1.2` for
  `subagent_compliance` blocks. **Note:** for **bare `agent-state:v1`**
  YAML blocks, the top-level dispatch heuristic in
  `scripts/lib/compliance_schema.py` (`validate_loaded_block`) only
  routes blocks whose `schema_version` is numerically exactly `1.2`
  through the agent-state validator; bare blocks declaring `1` or `1.1`
  keep their pre-PR-#344 behavior and fall through to the generic
  `unknown top-level keys` path. Authors emitting a new bare
  `agent-state:v1` block (including any with `opportunity_notes`) must
  declare `schema_version: 1.2`.

### Schema v2 coexistence (ADR-028)

Schema v2 introduces two structured replacements for free-text
`exemption_reason:` strings on the `plan_gate` and `diff_gate` objects:

- `gate_status:` — a closed enum (`triggered | passed | not-triggered |
  user-bypassed`) with per-state required fields. See §"`gate_status` v2".
- `verification_evidence:` — a typed evidence array with three classes
  (`logical | mechanical | pragmatic`) and per-class required artifact
  shape. See §"`verification_evidence` v2".

v2 is an **additive** schema change with **indefinite coexistence**:

- Existing `plan_compliance` / `parent_compliance` / `subagent_compliance`
  blocks declaring `schema_version: 1`, `1.1`, or `1.2` continue to validate
  exactly as before. The legacy `exemption_reason:` field on `plan_gate` /
  `diff_gate` remains accepted indefinitely; validators emit a
  `DeprecationWarning` (not a rejection) when it is populated as a non-null
  string under any schema_version. There is no sunset date in this ADR.
- A block opts into v2 by declaring `schema_version: 2` and using
  `gate_status:` (with optional `verification_evidence:`) in place of
  `exemption_reason:`. Mixing is permitted on a per-block basis but a
  single gate object MUST NOT carry both `gate_status:` and a non-null
  `exemption_reason:` — validators reject that combination as ambiguous.
- v2 readers MUST accept v1/1.1/1.2 blocks unchanged. v1 readers ignoring
  unknown fields will tolerate v2 blocks but will not enforce the new
  guards; only the v2 validator enforces `user-bypassed` three-field
  structural guard and evidence-class artifact shape.

The coexistence model exists so PRs in flight at the v2 cutover do not
need to be rewritten, and so legacy plan archives remain valid evidence
for postmortems and ADR back-references.

## `plan_compliance` v1

Emitted in implementation plans before substantive implementation begins.

### Fields

| Field | Type | Required | Description |
|---|---|---:|---|
| `schema_version` | integer | yes | Must be `1` for this schema. |
| `applicable_roles` | list of strings | yes | Roles whose ownership applies to the planned work. Empty only for trivial/exempt work. |
| `instruction_resources` | list of objects | yes | Each object has `resource`, `why_applicable`, `evidence`, and `decision_affected`. |
| `role_dispatch` | object | yes | `decision`, `planned_subagents`, and `monolithic_justification`. |
| `plan_gate` | object | yes | `status`, `link`, and `exemption_reason`. |
| `adr_required` | object | yes | `required`, `link`, and `supersession_notes`. |
| `doc_sync` | object | yes | `triggered`, `companions`, and `no_change_justifications`. |
| `verification` | list of strings | yes | Exact commands or manual checks planned. |

### Example — filled `plan_compliance`

```yaml
plan_compliance:
  schema_version: 1
  applicable_roles:
    - architect
    - docs
    - devops
  instruction_resources:
    - resource: AGENTS.md
      why_applicable: Canonical startup and truth-hierarchy contract.
      evidence: AGENTS_MD_VERSION 20; Session handshake v20 emitted.
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
    exemption_reason: null
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
| `schema_version` | integer | yes | Must be `1`. |
| `handshake_token` | string | yes | Exact parent token, format `Session handshake v<N>`. |
| `agents_md_version` | integer | yes | Version declared in `AGENTS.md`. |
| `runtime_pointer` | object | yes | Runtime instruction file evidence; see subfields below. |
| `applicable_roles` | list of strings | yes | Roles whose ownership applied to the final diff. |
| `subagents_dispatched` | list of objects | yes | Parsed `subagent_compliance` objects. Empty list requires `monolithic_justification`. |
| `monolithic_justification` | string or null | yes | Required if no subagents ran or if dispatched roles are a strict subset of applicable roles. |
| `plan_gate` | object | yes | `status`, `link`, `exemption_reason`. |
| `diff_gate` | object | yes | `status`, `link`, `exemption_reason`. |
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
  schema_version: 1
  handshake_token: Session handshake v20
  agents_md_version: 20
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
    exemption_reason: null
  diff_gate:
    status: pending
    link: null
    exemption_reason: null
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
  schema_version: 1
  handshake_token: Session handshake v20
  agents_md_version: 20
  runtime_pointer:
    path: .github/copilot-instructions.md
    loaded: true
    decision_affected: Used Copilot-specific subagent dispatch guidance.
  applicable_roles:
    - architect
    - docs
    - devops
  subagents_dispatched:
    - schema_version: 1.2
      role: docs
      role_contract_version: 1
      agents_md_version: 20
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
    - schema_version: 1.2
      role: devops
      role_contract_version: 1
      agents_md_version: 20
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
    exemption_reason: null
  diff_gate:
    status: pending
    link: null
    exemption_reason: null
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
| `schema_version` | number | yes | Numeric (int or float) literal. Current schema is `1.2`; readers must accept `1`, `1.1`, and `1.2` per the additive versioning policy above. Quoted-string forms (e.g. `"1.2"`) are rejected by `_require_schema_version_v12` — emit unquoted. |
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
  schema_version: 1.2
  role: judge
  role_contract_version: 2
  agents_md_version: 20
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
  schema_version: 1.2
  role: critic
  role_contract_version: 2
  agents_md_version: 20
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
  - title: "scripts/closeout.sh re-reads agent_ownership.md on every call"
    evidence: "scripts/closeout.sh:142-168 parses the ownership table per role iteration."
    impact: "Closeout takes 8-12s instead of ~1s; toil at every PR merge."
    recommendation: "Hoist the parse call out of the loop and cache the parsed table."
    scope: script
    suggested_next_action: file-issue
    confidence: high
    role_relevance: [devops]
    duplicate_check: "Searched issues for 'closeout perf' — no open or recent items."
```

## `gate_status` v2

The `gate_status` enum replaces free-text `exemption_reason` strings on
the `plan_gate` and `diff_gate` objects under `schema_version: 2`. Its
purpose is to make gate outcomes machine-checkable and to close the
self-exemption surface documented in postmortem-005 (PR #337).

### Enum values

| Value | Meaning | Required companion fields on the gate object |
|---|---|---|
| `triggered` | Gate was invoked but has not yet returned a decision (in-flight). | `link:` (URL to the in-flight gate artifact, e.g. dispatched subagent issue/PR comment). |
| `passed` | Gate ran and approved. | `link:` (URL to the approval comment/decision). |
| `failed` | Gate ran and rejected. | `link:` (URL to the rejection); the parent block MUST also include the planned remediation in `deviations:`. |
| `not-triggered` | Gate was not invoked because the work matched a published exemption in `.context/rules/process_gates.md`. | `not_triggered_reason:` (short string referencing the exemption clause, e.g. `"trivial single-file copy edit per process_gates.md§Exemptions"`). |
| `user-bypassed` | A user explicitly authorized skipping this gate. | Three-field bypass guard — see below. |

### `user-bypassed` three-field structural guard

When `gate_status: user-bypassed`, the gate object MUST include all
three fields below. The validator BLOCKs the diff if any one is missing,
empty, or syntactically malformed; this is a structural guard, not a
semantic one (see "Known limitations" in ADR-028).

| Field | Type | Validation |
|---|---|---|
| `bypass_label:` | string | MUST appear in the allow-list documented in `.context/rules/process_gates.md` § "User-bypass labels (allow-list)". Examples: `cap-override`, `user-bypass`. Arbitrary strings are rejected. |
| `user_directive:` | string | A verbatim quote (recommended ≥5 words) from a user comment on the same issue or PR that authorizes the bypass. Must not be empty; must not be paraphrased. Critic (not the validator) checks semantic accuracy — see `.agents/critic.md` § "Bypass guard theatre". |
| `user_directive_source_url:` | URL | Must resolve to a comment URL on the same issue or PR (`github.com/<owner>/<repo>/(issues\|pull)/<n>#issuecomment-<id>` form). Validator checks URL shape and issue/PR identity; it does NOT click through to verify the quoted text actually appears in context. That semantic check belongs to Critic and Judge. |

### Example — `gate_status: passed`

```yml
plan_gate:
  gate_status: passed
  link: https://github.com/mikejmckinney/ai-repo-template/issues/338#issuecomment-4488954523
```

### Example — `gate_status: not-triggered`

```yml
diff_gate:
  gate_status: not-triggered
  not_triggered_reason: "trivial typo fix per process_gates.md § Exemptions — single-line README change."
```

### Example — `gate_status: user-bypassed` (well-formed)

```yml
diff_gate:
  gate_status: user-bypassed
  bypass_label: cap-override
  user_directive: "use the cap-override label to continue automatically"
  user_directive_source_url: https://github.com/mikejmckinney/ai-repo-template/issues/338#issuecomment-4488700000
```

### Anti-example — `gate_status: user-bypassed` (rejected: missing URL)

```yml
diff_gate:
  gate_status: user-bypassed
  bypass_label: cap-override
  user_directive: "proceed"
  # user_directive_source_url MISSING — validator BLOCKs.
```

## `verification_evidence` v2

The `verification_evidence:` field is a typed array that replaces the v1
`verification_results:` list under `schema_version: 2`. Each entry
declares its evidence class and ships the artifact shape required for
that class. The taxonomy exists to make weaker-evidence substitution
(PR #314 / PR #344-class failure modes) structurally detectable.

### Fields per entry

| Field | Type | Required | Description |
|---|---|---:|---|
| `class` | string enum | yes | One of `logical`, `mechanical`, `pragmatic`. |
| `claim` | string | yes | What this evidence is asserted to prove (one short sentence). |
| `artifact` | object | yes | Class-specific artifact shape — see matrix below. |

### Per-class artifact shape

| Class | Purpose | Required `artifact` keys |
|---|---|---|
| `logical` | Documentation / contract / cross-reference — "the rule says X." | `path:` (repo-relative file path), `section:` (heading anchor or line range). |
| `mechanical` | Repeatable command with deterministic output. | `command:` (exact shell), `expected_exit_code:` (int) or `expected_output_regex:` (string). |
| `pragmatic` | Outcome observed by executing the work in the real environment. | `url:` (permalink to executed work — PR review URL, comment URL, workflow-run URL) AND `observed_outcome:` (one-line description of what was observed). |

### Outcome → required evidence class

Some outcome classes structurally require a stronger evidence class. The
required-evidence matrix lives in `.context/rules/process_work_style.md`
§ "Evidence taxonomy"; the high-level rule is:

- **Documentation-only outcomes** (rule wording, ADR text, README copy)
  can be evidenced with `class: logical` alone.
- **Build-decision outcomes** ("the validator was wired", "the workflow
  was updated", "the schema accepts X") require at minimum `class:
  mechanical` (the relevant command + expected output).
- **Operational outcomes** ("the agent dispatched the subagent", "the
  bypass worked end-to-end", "the PR merged with the new label") require
  at minimum `class: pragmatic` (permalink to executed work).

Judge REQUEST_CHANGES (not BLOCK) when an outcome's declared evidence
class is weaker than the matrix requires. Critic separately flags
"logical-evidence-only substitution" — see `.agents/critic.md`.

### Example — mixed-class `verification_evidence` block

```yml
verification_evidence:
  - class: logical
    claim: "ADR-028 documents the v2 coexistence model."
    artifact:
      path: docs/decisions/adr-028-gate-status-schema-and-evidence-taxonomy.md
      section: "Decision"
  - class: mechanical
    claim: "Schema v2 validator accepts the new gate_status enum."
    artifact:
      command: "python scripts/validate-compliance-fixtures.py"
      expected_exit_code: 0
  - class: pragmatic
    claim: "PR #N posted parent_compliance v2 with gate_status: passed."
    artifact:
      url: https://github.com/mikejmckinney/ai-repo-template/pull/N#issuecomment-XXXXXXXX
      observed_outcome: "Comment posted; body length 14823; validator emitted no warnings."
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

## CI-MUST validation rules for v2 (ADR-028)

For blocks declaring `schema_version: 2` (or higher), validators MUST
additionally enforce:

12. Each `plan_gate` / `diff_gate` object carries `gate_status:` with a
    value in the enum `{triggered, passed, failed, not-triggered, user-bypassed}`.
13. The per-state companion fields listed in §"`gate_status` v2" are
    present and well-typed.
14. When `gate_status: user-bypassed`, the three guard fields
    (`bypass_label`, `user_directive`, `user_directive_source_url`) are
    all present and non-empty; `bypass_label` is on the allow-list in
    `.context/rules/process_gates.md`; `user_directive_source_url`
    matches the GitHub issue/PR comment URL pattern for the same
    repository. Missing or malformed → reject (corresponds to Judge BLOCK).
15. A single gate object MUST NOT carry both `gate_status:` and a
    non-null `exemption_reason:`. Reject as ambiguous.
16. Each `verification_evidence[]` entry declares `class` in the enum
    `{logical, mechanical, pragmatic}` and ships the per-class artifact
    keys defined in §"`verification_evidence` v2". Missing required keys
    → reject.
17. Validators emit a `DeprecationWarning` (not a rejection) when a
    block under any `schema_version` populates `exemption_reason:` with
    a non-null string. Coexistence is indefinite per ADR-028.

Semantic checks remain out of scope for the validator. Critic and Judge
are the semantic backstop for `user_directive` accuracy and for
logical-evidence-only substitution — see `.agents/critic.md` and
`.agents/judge.md`.
