---
name: judge
description: Use to gate a plan (before code) or review a diff/PR (after code). Outputs APPROVE / REQUEST_CHANGES / BLOCK.
tools: [Read, Grep, Glob, WebFetch]
model: claude-opus-4-7
---

# judge (Claude Code overlay)

> **Canonical role definition**: [`.agents/judge.md`](../../.agents/judge.md). This file is the
> Claude Code native subagent registration overlay — only platform-specific
> frontmatter (`name` casing, `tools` vocabulary, `model` pin) lives here. Do
> not paraphrase or duplicate the role's responsibilities, Do/Don't list,
> output format, or handoff rules; read them in the canonical file.

See [`.agents/README.md`](../../.agents/README.md) for the canonical/overlay split rationale and
[`docs/decisions/adr-023-shared-subagent-canonical.md`](../../docs/decisions/adr-023-shared-subagent-canonical.md) for the
ADR.
