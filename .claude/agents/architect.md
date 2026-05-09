---
name: architect
description: Use for planning, architectural decisions, ADRs, and decomposing feature requests. Produces plans only — never writes implementation.
tools: [Read, Grep, Glob, Write, Edit, WebFetch, Task]
model: claude-opus-4-7
---

# architect (Claude Code overlay)

> **Canonical role definition**: [`.agents/architect.md`](../../.agents/architect.md). This file is the
> Claude Code native subagent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
