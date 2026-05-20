---
name: <role>
description: <byte-identical description shared by all overlays>
role_contract_version: 1
agents_md_compat: <AGENTS_MD_VERSION>
owned_paths:
  - '<owned/path/glob>'
handoff_targets:
  - <downstream-role>
---

# <Role> Agent

This template is the canonical starting point for role files under `.agents/`.
Platform overlays under `.github/agents/` and `.claude/agents/` stay thin and
must not duplicate this role body.

## Bootstrap contract

Before doing role work, load:

1. `AGENTS.md` and its current `AGENTS_MD_VERSION`.
2. This canonical role file and its `role_contract_version`.
3. `.context/rules/process_role_selection.md`.
4. `.context/rules/agent_ownership.md`.
5. Any process rules listed in the parent dispatch packet.
6. The issue, PR, plan, or diff context supplied in the dispatch packet.

If the dispatch packet omits the role, goal, expected output, required context,
or relevant issue/PR/plan/diff link, do not guess. Non-exact-output roles may
return `NEEDS_CONTEXT`; exact-output roles preserve their required first line
and use `REQUEST_CHANGES` with `NEEDS_CONTEXT` in the body.

## Receipt evidence

Non-exact-output roles may begin with:

```text
Role receipt v<role_contract_version> — <role>
```

Exact-output roles must preserve their existing first-line contract. For
example, Judge still begins with `DECISION:` and Critic still begins with
`CRITIC DECISION:`. Those roles record receipt evidence in the trailing
`subagent_compliance` block instead of prepending another line.

## Return contract

End every dispatched role response with a `subagent_compliance` YAML block
conforming to `docs/compliance_schemas.md`.

Use `role_contract_version` from this canonical role file. Do not use
`overlay_version`; platform overlays are registration shims and do not own the
role contract version.

```yaml
subagent_compliance:
  role: <role>
  role_contract_version: 1
  agents_md_version: <AGENTS_MD_VERSION>
  receipt:
    mode: visible-line  # or trailing-block for exact-output roles
    value: Role receipt v<role_contract_version> — <role>
  context_files_used:
    - AGENTS.md
    - .agents/<role>.md
  pointers_skipped: []
  task_scope: <parent-assigned task scope>
  files_modified: []
  gates_invoked: []
```

## Role-specific content

Add the role's responsibilities, Do/Don't lists, output format, and handoff
rules below this heading. Keep platform-specific `tools:` and `model:` fields
out of canonical role files.
