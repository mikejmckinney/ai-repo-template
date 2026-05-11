---
name: QA
description: Use to write/update tests, gate merges on coverage, and triage CI failures. Runs after implementation, before judge diff-gate.
tools: ['read', 'write', 'execute', 'search', 'fetch', 'githubRepo', 'usages', 'todo']
handoffs:
  - target: Critic
    send: true
  - target: Judge
    send: true
  - target: Frontend
    send: true
  - target: Backend
    send: true
---

# QA (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/qa.md`](../../.agents/qa.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
