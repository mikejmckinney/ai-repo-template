---
name: Project Manager
description: Use to dispatch approved plans into GitHub live-state comments/labels, manage claims, and resolve cross-role ownership conflicts.
tools: ['read', 'write', 'execute', 'search', 'todo']
model: 'Claude Sonnet 4.6 (copilot)'
handoffs:
  - target: Analyst
    send: true
  - target: Architect
    send: true
  - target: Judge
    send: true
  - target: Frontend
    send: true
  - target: Backend
    send: true
  - target: QA
    send: true
  - target: Critic
    send: true
  - target: DevOps
    send: true
  - target: Docs
    send: true
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
