---
name: Analyst
description: Use for needs analysis, market research, competitive analysis, and validating whether a project should be built. Produces research artifacts — never writes implementation code.
tools: ['read', 'write', 'execute', 'search', 'fetch', 'githubRepo', 'usages']
model: 'Claude Opus 4.7 (copilot)'
handoffs:
  - target: Architect
    send: true
  - target: Project Manager
    send: true
---

# Analyst (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/analyst.md`](../../.agents/analyst.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
