---
name: devops
description: Use to edit workflows, install scripts, config, or CI files. Stays inside devops-owned paths.
tools: [Read, Write, Edit, Grep, Glob, Bash, Task, WebFetch]
model: claude-sonnet-4-6
---

# devops (Claude Code overlay)

> **Canonical role definition**: [`.agents/devops.md`](../../.agents/devops.md). This file is the
> Claude Code native subagent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
