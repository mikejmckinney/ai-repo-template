# Model tier dispatch convention

> Extracted from AGENTS.md §"Model tier dispatch convention" in PR for #253 (ADR-021).
> Read when dispatching subagents or planning a tier upshift on a specific task.

Each role is pinned to a cost tier (High / Mid / Low) in its platform registration overlays — `.claude/agents/<role>.md` and `.github/agents/<role>.agent.md` — per [ADR-019](../../docs/decisions/adr-019-per-role-model-tiering.md). The canonical role body lives in `.agents/<role>.md` (platform-agnostic, ADR-023) and contains no `model:` field; tier values are platform-specific frontmatter and stay in the overlays. The canonical tier table is in ADR-019; do not duplicate it here. Three behavioral notes that affect day-to-day agent work:

1. **Per-platform value-space divergence is intentional.** `.claude/agents/*.md` uses Anthropic-only model strings (`claude-opus-4-7`, `claude-sonnet-4-6`, `inherit`). `.github/agents/*.agent.md` uses Copilot's qualified format (`'Claude Opus 4.7 (copilot)'`, etc.) or omits the field for Low-tier roles. `test.sh` enforces per-platform allowlists in `scripts/checks/050-agent-mirror.sh`; description-parity (byte-identical `description:` field across canonical + overlays) is unchanged.
2. **Copilot subagent cost-tier ceiling.** A High-tier subagent dispatched from a Copilot chat session whose main model is below Opus silently downgrades to the main's tier. To get an Opus dispatch on Copilot, set the chat picker to Opus before invoking the subagent. See [ADR-019 Amendment #6](../../docs/decisions/adr-019-per-role-model-tiering.md#amendment-6--copilot-subagent-cost-tier-ceiling-limitation--workaround). Claude Code has no equivalent ceiling.
3. **Per-task tier upshift via the plan template.** Use the `Model tier:` field in [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) to upshift a specific task above its role's default tier. Default is `mid`; when set to `top`, include a one-line justification.

Reassessment cadence and follow-up work (verified Copilot fallback arrays, etc.) live in ADR-019.
