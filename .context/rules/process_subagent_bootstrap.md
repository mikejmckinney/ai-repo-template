# Subagent bootstrap and compliance return

> ADR-026 rule for parent dispatch packets, dispatched subagent startup, and
> `subagent_compliance` evidence. Read when dispatching a subagent, receiving
> subagent output, or using subagent output as plan-gate/diff-gate evidence.

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
   call against `/repos/{owner}/{repo}/branches/<branch>`) in
   `subagent_compliance.verification[].evidence`. The verification command
   must run AFTER `git push` in the same response, so its output reflects
   the post-push state of the remote — not the pre-dispatch tip.
3. **Required parent-side defense.** After every dispatch that claims a
   push, the parent OP runs `git fetch origin && git log origin/<branch>
   -1 --oneline` and compares against the claimed commit SHA. A mismatch
   triggers `apply_replays[]` reconstruction or re-dispatch. Do not trust
   the subagent's success report alone.

This is recorded as a runtime limitation rather than a contract change
because the root cause is in the dispatch host, not in role behavior. The
rule above hedges against it without granting subagents broader permissions
or weakening OP's diff-gate authority.
