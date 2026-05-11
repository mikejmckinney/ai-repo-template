---
name: consensus-candidate-claude
description: Multi-model consensus dry-run candidate planner pinned to Claude Opus 4.7. Dispatched by the initiating agent of `.github/prompts/multi-model-consensus-plan.md` to produce one of the three independent candidate plans before synthesis. Not a general planning role — use Architect for production plans.
tools: ['read', 'search', 'usages']
model: 'Claude Opus 4.7 (copilot)'
user-invocable: false
---

# Consensus Candidate — Claude Opus 4.7 (Copilot SDK overlay)

> **Canonical role definition**: [`.agents/architect.md`](../../.agents/architect.md). This overlay
> reuses the Architect persona and output format with a different model pin so
> the consensus workflow can fan three planning passes across distinct vendors
> without natural-language model hints in subagent prompts (Copilot's
> subagent loader does not honor model hints in prompt bodies; only the
> overlay's `model:` frontmatter pins the model — see ADR-019 and
> [`.github/prompts/multi-model-consensus-plan.md`](../prompts/multi-model-consensus-plan.md)).

This overlay is **Copilot-only** and intentionally not mirrored to
`.claude/agents/` or `.agents/`; `scripts/checks/050-agent-mirror.sh` exempts
the `consensus-candidate-*` name prefix. It exists to let
`.github/prompts/multi-model-consensus-plan.md` dispatch repeatable, model-pinned
candidate planners. Promotion to N-way mirroring is justified only once the
repo gains a third platform whose model catalog differs meaningfully from
Copilot's.

Behavior, output format, and constraints are identical to Architect — produce
a plan only, never write implementation, mark the candidate plan with
`<!-- consensus-plan-candidate -->` and identify model + platform on the first
line of the plan body.
