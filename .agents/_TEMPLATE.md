---
name: <role>
description: <byte-identical description shared by all overlays>
owned_paths:
  - '<specialty/path/glob>'
handoff_targets:
  - <downstream-role>
---

# <Role> Agent

This template is the canonical starting point for role files under `.agents/`.
Platform overlays under `.github/agents/`, `.claude/agents/`, `.cursor/agents/`,
and `.codex/agents/` stay thin and must not duplicate this role body.

Read `AGENTS.md` and the assigned issue, PR, plan, or diff before role work. If
required context is missing, ask for it rather than guessing. `owned_paths` and
`handoff_targets` are optional specialty guidance, not mandatory dispatch or
path-ownership gates.

## Role-specific content

Add the role's responsibilities, Do/Don't lists, output format, and handoff
guidance below this heading. Keep platform-specific `tools:` and `model:` fields
out of canonical role files.
