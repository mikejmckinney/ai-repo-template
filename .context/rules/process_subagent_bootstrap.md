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
