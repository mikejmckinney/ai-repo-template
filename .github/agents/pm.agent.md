---
name: Project Manager
description: Use to dispatch approved plans into per-role task files, manage locks, and resolve cross-role ownership conflicts.
tools: ['read', 'write', 'search', 'githubRepo']
model: 'Claude Sonnet 4.6 (copilot)'
---

# Project Manager (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/pm.md`](../../.agents/pm.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
