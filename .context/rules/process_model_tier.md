# Model tier dispatch convention

> Extracted from AGENTS.md §"Model tier dispatch convention" in PR for #253 (ADR-021).
> Read when dispatching subagents or planning a tier upshift on a specific task.

Each role is pinned to a cost tier (High / Mid / Low) in its platform registration overlays — `.claude/agents/<role>.md` and `.github/agents/<role>.agent.md` — per [ADR-019](../../docs/decisions/adr-019-per-role-model-tiering.md). The canonical role body lives in `.agents/<role>.md` (platform-agnostic, ADR-023) and contains no `model:` field; tier values are platform-specific frontmatter and stay in the overlays. The canonical tier table is in ADR-019; do not duplicate it here. Three behavioral notes that affect day-to-day agent work:

1. **Per-platform value-space divergence is intentional.** `.claude/agents/*.md` uses Anthropic-only model strings (`claude-opus-4-7`, `claude-sonnet-4-6`, `inherit`). `.github/agents/*.agent.md` uses Copilot's qualified format (`'Claude Opus 4.7 (copilot)'`, etc.) or omits the field for Low-tier roles. `test.sh` enforces per-platform allowlists in `scripts/checks/050-agent-mirror.sh`; description-parity (byte-identical `description:` field across canonical + overlays) is unchanged.
2. **Copilot subagent cost-tier ceiling.** A High-tier subagent dispatched from a Copilot chat session whose main model is below Opus silently downgrades to the main's tier. To get an Opus dispatch on Copilot, set the chat picker to Opus before invoking the subagent. See [ADR-019 Amendment #6](../../docs/decisions/adr-019-per-role-model-tiering.md#amendment-6--copilot-subagent-cost-tier-ceiling-limitation--workaround). Claude Code has no equivalent ceiling.
3. **Per-task tier upshift via the plan template.** Use the `Model tier:` field in [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) to upshift a specific task above its role's default tier. Default is `mid`; when set to `top`, include a one-line justification.

Reassessment cadence and follow-up work (verified Copilot fallback arrays, etc.) live in ADR-019.

## Known runtime observation: dispatched-subagent ghost-success

During the multi-stage dispatch session for issue #313 (May 2026), 3 of 5 dispatched subagents returned a textually plausible success report — including a populated `subagent_compliance` block claiming `files_modified` and a pushed commit SHA — but no commit existed on the remote when the parent OP ran `git fetch && git log origin/<branch> -1`. Calling this pattern "ghost-success" because the failure mode is silent: the subagent does not error, returns a structurally valid response, and only the parent's independent re-verification surfaces the drift.

**Empirical breakdown for that session (sample size 5, recorded for future correlation, not yet actionable):**

| Role | Tier (per ADR-019) | Workload shape | Outcome |
|---|---|---|---|
| Architect | High | 30+ file edits + commit + push (canary ripple) | ghost-success |
| PM | Mid | 1 file, 2-line insert + commit + push | real-success |
| Docs | Mid | 1 large new file + 4 small edits + commit + push | ghost-success |
| DevOps | Mid | (parent-authored, not dispatched after pattern emerged) | n/a |
| Critic | Mid | read-only review + post issue comment | real-success |
| Judge | High | read-only review + post issue comment | ghost-success |

**Tier is unlikely to be the cause.** Architect is the highest tier on Copilot per ADR-019 and ghost-succeeded; Critic and PM are mid-tier and real-succeeded. The pattern instead correlates more strongly with **specific tool-call shapes inside a subagent runtime context**:

- `git push` from a terminal command issued inside a subagent context is the leading suspect (intermittent OP ghost-success has been observed historically with the same shape).
- High-volume `create_file` / `multi_replace_string_in_file` chains followed by a commit may also be implicated.
- Pure read + `gh ... comment` workloads (Critic, PM) succeeded reliably this session.

**Implication for tier upshift decisions.** Do not upshift Architect/Docs/Judge to a higher tier as a remediation for ghost-success — the empirical signal does not support it. Instead, prefer one of:

1. Have the subagent return file edits via the `apply_replays[]` pattern documented in `.context/rules/process_subagent_bootstrap.md` § "Edit verification and pass-back contract", and let the parent OP commit + push (the established single-applier pattern).
2. If the subagent must touch the working tree directly, require a `git log origin/<branch> -1 --oneline` verification snippet in the response narrative immediately adjacent to the `subagent_compliance` block (the v1 schema has no `verification` field; see `.context/rules/process_subagent_bootstrap.md` § "Edit verification and pass-back contract") so the parent OP catches the drift in the same response rather than after-the-fact.

**Sample size warning.** N=5 is too small to support a structural change to ADR-019's tier table. This section records the observation so the next multi-stage dispatch session can extend the table and reach actionable N (~20). After that, decide whether to file an ADR-019 amendment, a runtime-host bug report against the dispatch layer, or a tools-layer fix (e.g., subagents lose `git push` capability and must use `apply_replays`).
