---
name: DevOps
description: Use to edit workflows, install scripts, config, or CI files. Stays inside devops-owned paths.
tools: ['read', 'write', 'search', 'fetch', 'githubRepo']
model: 'Claude Sonnet 4.6 (copilot)'
---

# DevOps (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/devops.md`](../../.agents/devops.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
