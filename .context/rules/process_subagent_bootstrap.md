# Subagent bootstrap and compliance return

> ADR-026 rule for parent dispatch packets, dispatched subagent startup, and
> `subagent_compliance` evidence. Read when dispatching a subagent, receiving
> subagent output, or using subagent output as plan-gate/diff-gate evidence.

## Positional output contract

**Exact-output subagents emit their required first line before any handshake
content.**

- Judge: `DECISION:` must be the literal first character sequence of the
  response. Do not prepend a session handshake, receipt section, or receipt
  line before the role output.
- Critic: `CRITIC DECISION:` must be the literal first character sequence.
  Same constraint.

After the role-specific body, append in order:

1. `## Subagent session handshake` — the 7-field table from AGENTS.md
   `## Session handshake (read-receipt)`.
2. `## Subagent context receipt` — the file table from AGENTS.md
   `## Session context receipt`.
3. `subagent_compliance` YAML block.

Non-exact-output subagents (Architect, Backend, Frontend, QA, DevOps, Docs,
Analyst, PM) are not constrained by this rule. They may begin with
`Role receipt v<N> — <role>` (see `## Receipt evidence`); non-exact-output roles
that begin with `Role receipt v<N> — <role>` retain that preamble — the new
trailing blocks coexist with it. They are encouraged to emit
`## Subagent session handshake` and `## Subagent context receipt` at the end of
their response in the same order described above.

## Parent dispatch packet

Before dispatching a subagent, the parent/default agent must provide enough
context for the role to decide without guessing:

- role name,
- goal and task scope,
- expected output surface,
- relevant issue, PR, plan, or diff link,
- required process files,
- ownership constraints,
- required gates,
- current `AGENTS_MD_VERSION`,
- known deviations, exemptions, or missing context.
- **For Judge dispatch**: include `mode: plan-gate` or `mode: diff-gate` in the dispatch packet.
  This is a **documentation requirement for the dispatching parent** — it declares which gate context
  the packet was sent for and enables reliable output-format conformance.
  When `mode:` is absent, Judge falls back to content inference (Priority 2 in `.agents/judge.md` § "Mode Selection")
  then asks one clarifying question (Priority 3) before proceeding. Judge will explicitly confirm
  the selected mode via self-check before emitting any output regardless of whether `mode:` was supplied.
  Including `mode:` is the dispatching parent's documentation responsibility; omitting it degrades
  Judge output-format reliability. Enforcement derives entirely from the Mode Selection priority
  chain in `.agents/judge.md` (Priority 1-2-3); this entry is an annotation to that chain, not a
  new independent gate condition.

If any required field is unknown, state that explicitly. Do not let the
subagent infer missing issue/PR state or ownership.

## Subagent startup order

A dispatched subagent must load, in order:

1. `AGENTS.md` and the current `AGENTS_MD_VERSION`.
2. Its canonical role file under `.agents/` and that file's
   `role_contract_version`.
3. `.context/rules/process_role_selection.md`.
4. `.context/rules/agent_ownership.md`.
5. Every process rule named in the parent dispatch packet.
6. The issue, PR, plan, diff, or other task context supplied by the parent.

A subagent may load additional files when relevant, but the trailing
`subagent_compliance.context_files_used` list must name the files that
actually affected the role output.

## Missing context behavior

If the dispatch packet omits the role, goal, expected output, required
context, or relevant issue/PR/plan/diff link, do not guess.

- Non-exact-output roles may return `NEEDS_CONTEXT`.
- Exact-output roles must preserve their first-line contract. Judge still
  starts with `DECISION:` and Critic still starts with `CRITIC DECISION:`;
  they should use `REQUEST_CHANGES` and name `NEEDS_CONTEXT` in the body.

In both cases, append `subagent_compliance` when enough context exists to
identify the role contract and task scope.

## Receipt evidence

Non-exact-output roles may begin with:

```text
Role receipt v<role_contract_version> — <role>
```

Exact-output roles must not prepend a receipt line. They record receipt
evidence in the trailing `subagent_compliance.receipt` object with
`mode: trailing-block`.

## Required return block

Every dispatched subagent response ends with a `subagent_compliance` YAML
block matching `docs/compliance_schemas.md`.

Required discipline:

- Use `role_contract_version`, never `overlay_version`.
- Use the loaded `AGENTS_MD_VERSION` for `agents_md_version`.
- List only files actually modified in `files_modified`; review-only roles use
  an empty list.
- List skipped pointers only when a potentially relevant pointer was
  consciously skipped, with a specific reason.
- Include an `opportunity_notes` field (same 9-field shape as the
  `agent-state:v1` `opportunity_notes` array — see
  `.context/rules/process_opportunity_feedback.md` § "Required fields
  (9 total)") when the subagent produced or modified files.
  `opportunity_notes: []` (empty list) is permitted and is the
  common case. Read-only subagents (Analyst pre-flight, Judge
  gate review, Critic review with no diff) MAY omit the field
  entirely. The ≤3-per-session cap applies.
- Do not claim runtime proof. The block is evidence reported by the role, not
  proof that the host enforced dispatch or handoff behavior.

Missing `subagent_compliance` makes that subagent output unusable as gate
evidence. It is not proof that dispatch failed.

## Parent handling of subagent evidence

The parent/default agent must copy parsed subagent compliance objects into
`parent_compliance.subagents_dispatched` when preparing PR evidence. Raw
verbatim subagent output may be preserved for provenance, but validators and
reviewers rely on parsed fields.

If a subagent omits compliance, the parent may still summarize the work, but
must not cite that output as Judge/Critic/QA gate evidence.

## Edit verification and pass-back contract

A dispatched subagent that intends to modify files must, before reporting
`run_status: SUCCESS`, re-read each file in `files_modified` and confirm the
expected post-edit anchors are present. If verification fails, or if the
runtime errored before the edit could be persisted, the subagent must:

1. Set `subagent_compliance.run_status` to `BLOCKED_ON_RUNTIME` (or
   `PARTIAL` when some edits landed and others did not).
2. Populate `subagent_compliance.apply_replays[]` with byte-anchored patches
   the parent can replay deterministically. Each entry has `path`,
   `anchor` (the existing literal substring to locate the edit point;
   must be unique within the file), and `replacement` (the literal
   substring to substitute for `anchor`). For pure insertions, set
   `replacement` to the anchor text plus the inserted block.
3. Leave `files_modified` empty for any file whose edit did not land. Do
   not list aspirational edits in `files_modified`.

The "returned byte-anchored patches in the failure response" pattern from
PR #312's Architect dispatch is the gold standard. The "returned nothing"
pattern from the same PR's Docs dispatch is the failure mode this contract
is designed to prevent.

Granting subagents broader write/exec permissions is **not** the right
remediation for runtime failures: that splits write authority across N
runtimes, defeats OP's diff-gate role, and increases blast radius. Pass-back
keeps OP as the single applier and keeps the diff gate authoritative.

## Parent handling of pass-back evidence

When a subagent returns `run_status != SUCCESS` with `apply_replays[]`:

1. The parent applies each patch via its own edit tool, verifies the
   target file contains the expected post-edit bytes, and records the
   applied SHA / file paths in `parent_compliance.deviations[]` with
   `id: subagent-runtime-failure-replayed`.
2. The parent records both the subagent's reported `files_modified`
   (empty) and the parent-applied paths in
   `parent_compliance.monolithic_justification`, naming pass-back
   explicitly so the diff is not mistaken for default-agent scope creep.
3. If the parent cannot apply a patch (anchor missing, conflict),
   surface this as a `NEEDS_CONTEXT` follow-up rather than silently
   re-implementing the edit.

A subagent that returns `run_status: BLOCKED_ON_RUNTIME` with empty
`apply_replays[]` and no concrete artifact is a process compliance failure.
The parent must document this in `parent_compliance.deviations[]` with
`id: subagent-runtime-failure-without-replay` and explain in
`monolithic_justification` how the role-owned work was reconstructed (e.g.,
verbatim from the issue body, from the plan, or by re-dispatching).

## Known runtime limitation: dispatched-subagent ghost-success

A subagent that performs file edits and then claims `git commit` + `git push`
from inside its own terminal context can return a textually plausible
success response — populated `files_modified`, a commit SHA, even a
`git push` log line — when no commit actually landed on the remote. The
parent OP detects this only by independently running `git fetch && git log
origin/<branch> -1` after each dispatch. Empirical observation lives in
[`process_model_tier.md`](process_model_tier.md) § "Known runtime
observation: dispatched-subagent ghost-success".

**Required discipline for dispatched subagents that intend to push:**

1. **Prefer the pass-back pattern.** Make file edits, populate
   `apply_replays[]` with byte-anchored patches per the contract above, set
   `run_status: BLOCKED_ON_RUNTIME` if you cannot verify the push landed,
   and let the parent OP commit + push. Single-applier discipline is the
   single most effective hedge against this failure mode.
2. **If a subagent commits + pushes directly,** include the literal output
   of `git log origin/<branch> -1 --oneline` (or the equivalent `gh api`
   call against `/repos/{owner}/{repo}/branches/<branch>`) in the
   `subagent_compliance` block. The v1 schema has no `verification` field;
   record the snippet inline in the relevant `apply_replays[].anchor`
   prose, the surrounding response narrative immediately above the
   `subagent_compliance` block, or as a parent-replayed post-hoc check
   captured in `parent_compliance.subagents_dispatched[].subagent_compliance`
   pass-through. The verification command must run AFTER `git push` in the
   same response, so its output reflects the post-push state of the
   remote — not the pre-dispatch tip.
3. **Required parent-side defense.** After every dispatch that claims a
   push, the parent OP runs `git fetch origin && git log origin/<branch>
   -1 --oneline` and compares against the claimed commit SHA. A mismatch
   triggers `apply_replays[]` reconstruction or re-dispatch. Do not trust
   the subagent's success report alone.

This is recorded as a runtime limitation rather than a contract change
because the root cause is in the dispatch host, not in role behavior. The
rule above hedges against it without granting subagents broader permissions
or weakening OP's diff-gate authority.

## Subagent compliance schema variance

In practice, subagents register `subagent_compliance` blocks that vary in
shape from the strict `compliance_schemas.md` v1 spec — e.g., emitting
`role_contract_version`, `receipt: { mode, value }`, `context_files_used`,
`pointers_skipped`, or per-role evidence sub-blocks (`ownership_check`,
`gates_invoked`, `inputs_evaluated`) that the canonical schema does not
list. This was first observed during the Mode A dogfood test against
sandbox issue #2 (May 2026), where Judge round-1 returned a richer block
than the spec asked for.

**Parent handling rules:**

1. **Treat the canonical v1 required fields as required.** A
   `subagent_compliance` block (whether standalone or as an entry inside
   `parent_compliance.subagents_dispatched[]`) is valid only when **all**
   nine required keys are present: `role`,
   `role_contract_version`, `agents_md_version`, `receipt`,
   `context_files_used`, `pointers_skipped`, `task_scope`,
   `files_modified`, `gates_invoked`. The optional v1.1 additive keys
   `run_status` and `apply_replays` MAY be present. The schema authority
   is `scripts/lib/compliance_schema.py` (the `allowed_keys` /
   `required_keys` set in `validate_subagent`); when this rule and the
   schema disagree, the schema wins and this rule is the bug.
2. **The strict validator (`scripts/lib/compliance_schema.py`
   `_reject_unknown_keys`) rejects any field outside the canonical set,
   in standalone `subagent_compliance` blocks **and** in each
   `parent_compliance.subagents_dispatched[]` entry** (each entry is
   itself validated via `validate_subagent`; there is **no** nested
   `subagent_compliance` key, and there is **no** `notes` field on
   subagent entries — both shapes will hard-fail
   `scripts/validate-compliance-examples.py` /
   `scripts/validate-compliance-fixtures.py` per
   `docs/compliance_schemas.md` §"CI-MUST validation rules for v1"
   rule 6). Capture diagnostically-useful extras (extra-role evidence,
   non-schema annotations, `missing_fields` notes) in **adjacent prose**
   in the PR/issue comment body around the block, **not** as keys inside
   the block. The structured slot is canonical-only.
3. **If a subagent omits a canonically-required field**, the parent OP
   re-dispatches with an explicit reminder to include the missing field
   rather than recording the gap as a key inside the block — the strict
   validator does not accept a `missing_fields` key, and a downstream
   Judge diff-gate or QA hook will surface the same gap. Only if
   re-dispatch is impossible (e.g., the runtime is unavailable) does the
   parent describe the gap in narrative prose adjacent to the block and
   BLOCK rather than proceed.
4. **Schema-vs-practice drift is a feedback signal**, not a defect. When
   the same extra field appears across multiple dispatches of the same
   role, file an issue against `compliance_schemas.md` proposing the
   addition rather than asking subagents to drop it.
