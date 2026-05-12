---
name: Docs
description: Use to update README, AI_REPO_GUIDE, CLAUDE.md, or docs/. Runs in parallel with implementers when visible behavior changes.
tools: ['read', 'write', 'execute', 'search', 'githubRepo', 'todo']
handoffs:
  - target: Judge
    send: true
  - target: Architect
    send: true
---

# Docs (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/docs.md`](../../.agents/docs.md). This file is the
> Copilot SDK custom-agent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
