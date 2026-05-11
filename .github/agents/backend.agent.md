---
name: Backend
description: Use to implement server code (APIs, models, migrations). Consumes a dispatched task; stays inside backend-owned paths.
tools: ['read', 'write', 'execute', 'search', 'fetch', 'githubRepo', 'usages', 'todo']
model: 'Claude Sonnet 4.6 (copilot)'
handoffs:
  - target: QA
    send: true
  - target: Judge
    send: true
  - target: Frontend
    send: true
  - target: Docs
    send: true
---

# Backend (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/backend.md`](../../.agents/backend.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
