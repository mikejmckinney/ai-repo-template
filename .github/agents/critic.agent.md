---
name: Critic
description: Use as a devil's-advocate reviewer alongside judge. Catches subjective-quality issues, hidden assumptions, and AI clichés.
tools: ['read', 'search', 'execute', 'fetch', 'githubRepo', 'usages']
model: 'Claude Sonnet 4.6 (copilot)'
handoffs:
  - target: Judge
    send: true
---

# Critic (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/critic.md`](../../.agents/critic.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
