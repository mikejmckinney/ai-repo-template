---
name: consensus-candidate-gemini
description: Multi-model consensus dry-run candidate planner pinned to Gemini 3.1 Pro. Dispatched by the initiating agent of `.github/prompts/multi-model-consensus-plan.md` to produce one of the three independent candidate plans before synthesis. Not a general planning role — use Architect for production plans.
tools: ['read', 'search', 'usages']
model: 'Gemini 3.1 Pro (Preview) (copilot)'
user-invocable: false
---

# Consensus Candidate — Gemini 3.1 Pro (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/architect.md`](../../.agents/architect.md). This overlay
> reuses the Architect persona and output format with a different model pin so
> the consensus workflow can fan three planning passes across distinct vendors
> without natural-language model hints in subagent prompts.

This overlay is **Copilot-only** and intentionally not mirrored to
`.claude/agents/` or `.agents/`; `scripts/checks/050-agent-mirror.sh` exempts
the `consensus-candidate-*` name prefix. See
[`consensus-candidate-claude.agent.md`](consensus-candidate-claude.agent.md)
for the rationale and behavioral contract.
