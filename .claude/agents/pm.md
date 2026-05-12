---
name: pm
description: Use to dispatch approved plans into GitHub live-state comments/labels, manage claims, and resolve cross-role ownership conflicts.
tools: [Read, Grep, Glob, Write, Edit, Task]
model: claude-sonnet-4-6
---

# pm (Claude Code overlay)

> **Canonical role definition**: [`.agents/pm.md`](../../.agents/pm.md). This file is the
> Claude Code native subagent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
