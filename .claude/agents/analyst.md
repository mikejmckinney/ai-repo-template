---
name: analyst
description: Use for needs analysis, market research, competitive analysis, and validating whether a project should be built. Produces research artifacts — never writes implementation code.
tools: [Read, Grep, Glob, WebFetch, Write, Edit, Task]
model: claude-opus-4-7
---

# analyst (Claude Code overlay)

> **Canonical role definition**: [`.agents/analyst.md`](../../.agents/analyst.md). This file is the
> Claude Code native subagent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
