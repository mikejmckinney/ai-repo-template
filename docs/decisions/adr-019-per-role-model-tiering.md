# ADR-019: Per-role model tiering across Claude Code and Copilot

## Status

Accepted

## Date

2026-05-07

## Context

GitHub's May 2026 model multipliers raised per-request costs on premium models. Recent overages: ~$130 Claude Pro, ~$82 Copilot premium requests. Across the team's subscription mix (Copilot Pro+, Claude Pro, ChatGPT Pro), the dominant cost driver is uniform routing of every role through the parent harness's model — which on Claude Code is whatever model the user has selected (typically Opus or Sonnet) and on Copilot is whichever model the chat session is running.

ADR-003 ratified the original `.claude/agents/<role>.md` mirror design and chose `model: inherit` as the universal default for all 9 (now 10) Claude Code subagent registrations. That decision was correct for ADR-003's scope (proving the dispatch path works) but is now the bottleneck on cost optimization: a Sonnet-class implementation role and an Opus-class judge role both run on whatever the parent picked.

This ADR ships per-role `model:` pinning across both `.claude/agents/*.md` (Claude Code) and `.github/agents/*.agent.md` (Copilot custom agents), with a tier table that separates roles into High / Mid / Low cost classes. Per-platform divergence in `model:` values is intentional and load-bearing — Claude Code's loader accepts Anthropic-only model strings; Copilot's loader accepts a multi-vendor qualified format (`Model Name (vendor)`) and a native fallback array.

This ADR is **Phase 2** of the cost-mitigation strategy tracked in [issue #220](https://github.com/mikejmckinney/ai-repo-template/issues/220). Phase 1 (workflow defaults + loop discipline), Phase 3 (Codex A/B + Cursor BugBot CI), and Phase 4 (Copilot handoff orchestration) are scoped separately and are not affected by this decision.

**Numbering note:** prior #220 plans referenced this ADR as "ADR-016." That number had landed on a different decision (Pre-merge verification gate) before Phase 2 implementation began. This ADR is filed as ADR-019; structurally identical to the planned design.

## Decision

We adopt the following per-role tier table as the canonical model-routing reference for both `.claude/agents/*.md` and `.github/agents/*.agent.md`:

| Role | Tier | Claude Code (`model:`) | Copilot (`model:`) |
|---|---|---|---|
| analyst | High | `claude-opus-4-7` | `'Claude Opus 4.7 (copilot)'` |
| architect | High | `claude-opus-4-7` | `'Claude Opus 4.7 (copilot)'` |
| judge | High | `claude-opus-4-7` | `'Claude Opus 4.7 (copilot)'` |
| critic | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| pm | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| backend | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| frontend | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| devops | Mid | `claude-sonnet-4-6` | `'Claude Sonnet 4.6 (copilot)'` |
| qa | Low | `inherit` | _(omit; inherits from main session)_ |
| docs | Low | `inherit` | _(omit; inherits from main session)_ |

**Critic escalation:** Critic stays at Mid by default but escalates to judge-tier (Opus) when its review output flags `severity: high`. Escalation is a body-text instruction in the canonical `.agents/critic.md`, not a frontmatter mechanism. (Both platform overlays — `.github/agents/critic.agent.md` and `.claude/agents/critic.md` — are thin pointers to the canonical per ADR-023, so the escalation rule lives in exactly one place.)

**`test.sh` enforcement** (per-platform allowlists, added in this PR after the existing description-parity check):

- **Claude allowlist** (`.claude/agents/*.md`): `model:` value is one of `inherit | claude-opus-4-7 | claude-sonnet-4-6 | claude-haiku-4-5`. Anthropic strings only.
- **Copilot allowlist** (`.github/agents/*.agent.md`): `model:` line is either absent (Low tier) or matches the qualified-format regex `^model: '[A-Za-z0-9. ()-]+ \(copilot\)'$`. Multi-vendor values accepted as long as the `(copilot)` suffix is present.

Description-parity check (`test.sh:~650-670`) is left unchanged — it asserts byte-identical `description:` fields, not tier alignment. Cross-platform tier divergence within a role is intentional and acceptable (see Amendment #2).

## Amendments

### Amendment #1 — Pin specific model versions, not abstract tiers

`model: claude-opus-4-7`, not `model: opus`. Anthropic's `opus` alias auto-rolls to whichever Opus generation is current; auto-rolling silently changes behavior, cost, and latency for every High-tier role on the day Anthropic ships a new Opus. Pinning a version makes upgrades a deliberate PR with a diff humans can review.

### Amendment #2 — Per-platform fallback strategy

Workflow-layer "if Opus is rate-limited, retry with Sonnet" is rejected for both platforms. It hides cost / quality drift behind retries that look like transient noise.

- **Copilot** supports a native YAML array (per VS Code custom-agents docs, verified 2026-05-07): `model: ['Claude Opus 4.7 (copilot)', 'GPT-5.2 (copilot)']`. The runtime tries each in order until one is available. **v1 of this ADR ships single-string pins on all Copilot roles** because cross-vendor cost-tier alignment between Anthropic and OpenAI/Vertex models on Copilot's pricing surface has not been verified; shipping speculative fallback arrays risks silent tier-downgrade. Adding fallback arrays per role is a follow-up once tier alignment is verified.
- **Claude Code** has no equivalent (single-string `model:` only). Document the fallback chain in this ADR's prose; humans/agents follow it manually when the pinned model is unavailable.

### Amendment #3 — Tier table is v1 of an A/B framework, not a permanent assignment

The tier table above is the starting point. Re-evaluate each role's tier quarterly, or when a new model release shifts the price/quality frontier materially. Record reassessments as amendments to this ADR, not new ADRs, so the history stays in one place. The reusable A/B protocol for evaluating model swaps is a deferred Phase 4 deliverable of [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) — see the [Phase 4 stub comment](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4393282716). When that work lands it will live as a new section (working title "Model / workflow A/B protocol") in [`docs/guides/agent-pipeline.md`](../guides/agent-pipeline.md); until then, that section does not exist and this paragraph is the only canonical reference.

### Amendment #4 — Model strings are placeholders subject to vendor cadence

At time of writing (2026-05-07), Claude Opus 4.7 and Sonnet 4.6 are the current Anthropic generations; GPT-5.2 is the current Copilot offering. If any of these strings doesn't resolve at implementation time, swap to the then-current equivalent and note it in the implementation PR. Don't block on the exact label.

### Amendment #5 — Narrow exception for dev-context aliases

Files under `experiment/**` or `spike/**` MAY use unpinned aliases (`model: opus`) for the duration of the experiment. Those paths exist to iterate fast on prompts/personas; forcing a Phase-2 pin would drag every spike through ADR review. The exception expires when the file is promoted out of those directories OR when the file accumulates >50 commits, whichever comes first. Production roles under `.claude/agents/**` and `.github/agents/**` get no exception.

### Amendment #6 — Copilot subagent cost-tier ceiling (limitation + workaround)

Per the VS Code Copilot subagents docs (verified 2026-05-07): *"The requested model cannot exceed the cost tier of the main model. If you request a more expensive model, the subagent falls back to the main model."* Concretely: a High-tier subagent (e.g., `analyst` / `architect` / `judge` pinned to Opus 4.7) dispatched from a Copilot chat session running Sonnet (Mid tier) silently downgrades to Sonnet — the `model:` pin in `.github/agents/<role>.agent.md` is ignored.

This is **Copilot-only**. Claude Code's subagent dispatcher has no equivalent ceiling.

**Recommended workaround:** users who want High-tier subagents to actually receive their pinned model should set their Copilot chat-default model to the highest tier any subagent in their workflow is pinned to (i.e., set the picker to Opus 4.7 if you want `analyst` to actually run on Opus). The role files for `analyst`, `architect`, and `judge` carry a one-paragraph note linking back to this amendment.

This constraint is one more reason the tier table is a v1 A/B framework (Amendment #3) — if the ceiling forces most teams to run Opus-as-main anyway, the cost savings of Mid/Low tiering on Copilot shrink and the table needs revisiting.

### Amendment #7 — Qualified vendor format for Copilot model strings

Copilot's multi-vendor selector requires the `Model Name (vendor)` format for disambiguation: `Claude Opus 4.7 (copilot)`, `GPT-5.2 (copilot)`, `Gemini 3 Flash (Preview) (copilot)`. The `test.sh` allowlist regex for `.github/agents/**` accepts this format and (in a future revision) array forms of it. Claude Code allowlist for `.claude/agents/**` uses bare Anthropic model strings (no vendor suffix).

### Amendment #8 — June 2026 Copilot pricing reassessment and interim GPT-5.4 xhigh guidance

GitHub's June 2026 Copilot pricing update changes the relative premium-request multipliers on Copilot's pricing surface. The cross-vendor cost-alignment assumption behind Amendment #2's "single-string pins until verified" rule is therefore stale and must be re-validated against the new billing baseline. In this ADR, "cost" on the Copilot side means billed Copilot cost first (premium-request multiplier / pricing tier), not raw token count; token use and latency remain secondary evaluation metrics.

This amendment does **not** change the canonical tier table above and does **not** change any `.github/agents/*.agent.md` overlay `model:` lines. Until issue #220 Phase 3 / Phase 4 is refreshed and benchmarked against the updated pricing surface, the existing Copilot-side Anthropic pins remain the documented repo default. The current table stays accepted as the v1 baseline, not because it is proven optimal under the June 2026 pricing surface, but because the comparison data needed to justify a remap does not yet exist.

Interim guidance for Copilot users: when the work is reasoning-heavy and parent-model choice matters because of Amendment #6's cost-tier ceiling — for example OP orchestration, `pr-resolve-all.md` review loops, plan-gate, diff-gate, or architecture-heavy design work — `GPT-5.4 xhigh` is the preferred comparison baseline and MAY be used as the parent session model pending benchmark results. This is guidance for human session setup, not an overlay remap and not a claim that `GPT-5.4 xhigh` is the final per-role winner.

The decision about whether to remap any Copilot role from the current Anthropic strings to `GPT-5.4 xhigh` (or another Copilot model), and whether to add verified Copilot fallback arrays, is deferred to the refreshed benchmark work in issue #220. That refresh must evaluate ROI per role and per workflow class, at minimum across: billed Copilot cost, review-loop convergence, plan/review quality, latency to task completion, and context-fit / truncation risk. If the refreshed benchmark shows that `GPT-5.4 xhigh` has better ROI for specific Copilot roles, capture that as a later ADR-019 amendment and update the affected overlays in the same PR.

## Options Considered

### Option 1: Per-role pinning with per-platform divergence (chosen)

- **Pros**: directly addresses the cost driver. Per-platform divergence is the natural fit — Claude Code only dispatches to Anthropic; Copilot may route through GPT or Gemini for the same role. Reversible per-role by editing one file.
- **Cons**: 20 files to maintain instead of 10. Description-parity check stays at byte-identical (per-platform divergence applies to `model:` only, not `description:`). Allowlist drift requires periodic test.sh updates.

### Option 2: Universal `model: inherit` (status quo, ratified by ADR-003)

- **Pros**: simplest. One mental model.
- **Cons**: doesn't address the cost driver. Every role runs on whatever the user picked, including expensive ones for cheap roles.

### Option 3: Cross-platform tier-parity assertion in `test.sh`

- **Pros**: stronger consistency guarantee.
- **Cons**: rejected. Copilot's multi-vendor capability means a role MAY legitimately use a non-Anthropic model on Copilot while using Anthropic on Claude Code (e.g., a future `architect` on Gemini 3.1 Pro for Copilot users while Claude Code users stay on Opus). Forcing tier-parity blocks exactly the multi-vendor flexibility Copilot is designed for.

### Option 4: Workflow-layer fallback orchestration

- **Pros**: handles vendor outages automatically.
- **Cons**: rejected per Amendment #2. Hides cost/quality drift behind retries that look like transient noise. Copilot's native YAML array is the right place for fallback (when verified tier alignment exists); Claude Code documents the chain in prose.

## Consequences

### Positive

- Per-role cost optimization is now in the repo and reproducible across team members. New contributors get the tier defaults automatically by cloning.
- The single source of cost-routing truth is one ADR + one tier table — `test.sh` enforces that no agent file silently drifts off the allowlist.
- Reassessment cadence (Amendment #3) builds in a re-evaluation gate as models evolve.

### Negative

- 20-file maintenance surface instead of 10. The shared subagent body refactor ([#248](https://github.com/mikejmckinney/ai-repo-template/issues/248)) addresses this once a 3rd platform is added.
- Copilot cost-ceiling (Amendment #6) means the Copilot-side cost benefit is contingent on user discipline (set Opus-as-main if you want Opus subagents). Documentation, not enforcement.
- Allowlist regex must be updated as models evolve. Tied to reassessment cadence in Amendment #3.

### Neutral

- ADR-003 stays accepted as the registration-mechanism decision; only its `model: inherit` choice is superseded.
- Description-parity check is unchanged; cross-platform divergence on `model:` does not touch the `description:` invariant.

## Implementation

This ADR ships in one PR (`feature/devops-220-phase2`):

1. ADR-019 file (this file) created.
2. `docs/decisions/adr-003-...md` Status updated to `Accepted (per-role `model:` choice superseded by ADR-019)`.
3. `docs/decisions/README.md` index updated with ADR-019 row.
4. All 10 `.claude/agents/*.md` files updated per the tier table.
5. All 10 `.github/agents/*.agent.md` files updated per the tier table; `model:` omitted on Low-tier roles.
6. `.github/agents/critic.agent.md` and `.claude/agents/critic.md` body updated with the judge-Opus escalation note.
7. `.github/agents/analyst.agent.md`, `architect.agent.md`, `judge.agent.md` body updated with a note linking Amendment #6 (Copilot cost-ceiling workaround).
8. `AGENTS.md` adds a "Model tier dispatch convention" section pointing to this ADR.
9. `.github/PLAN_TEMPLATE.md` adds a `Model tier:` per-task override field.
10. `docs/guides/agent-pipeline.md` cost table refreshed; per-role tier column added.
11. `test.sh` adds two per-platform allowlist assertions after the existing description-parity check.

## Future Work

- Refresh issue #220 Phase 3 / Phase 4 benchmarking against GitHub's June 2026 Copilot pricing surface before changing any Copilot overlay `model:` pins.
- Treat Copilot "cost" primarily as billed Copilot cost on the current pricing surface, with token usage and latency measured as secondary metrics rather than primary routing inputs.
- Use `GPT-5.4 xhigh` as the interim comparison baseline for reasoning-heavy Copilot parent sessions while benchmark data is being refreshed.
- Evaluate ROI by role and workflow class, not only by raw model quality: include billed cost, convergence in review loops, plan/review quality, time-to-completion, and context-fit/truncation risk.
- If refreshed evidence shows a better Copilot mapping than the current Anthropic-pinned v1 baseline, land that change as a later ADR-019 amendment together with any required overlay and enforcement updates.
- Keep Copilot fallback-array support deferred until cross-vendor syntax and cost-tier semantics are verified against real benchmark results rather than assumed parity.
- **Verified Copilot fallback arrays** (Amendment #2 follow-up): once Anthropic / OpenAI / Vertex tier alignment is verified on Copilot's pricing surface, add `model: [...]` arrays to High and Mid Copilot roles per the verified mapping. File as a follow-up issue after at least one billing cycle of Phase 2 data.
- **Reassessment cadence** (Amendment #3): first quarterly review ~3 months after this ADR lands; capture in a new amendment.
- **Phase 4 handoff orchestration** ([#220 Phase 4 stub](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4393282716)): per-handoff `model:` overrides will reference this ADR's tier table.
- **Shared subagent body refactor** ([#248](https://github.com/mikejmckinney/ai-repo-template/issues/248)): when the body refactor lands, the per-platform `model:` lines stay in their respective overlay files (the divergence is exactly the kind of frontmatter the refactor is designed to keep platform-local).

## References

- Supersedes the `model: inherit` choice in [ADR-003](./adr-003-claude-code-subagent-registration.md). Registration mechanism (the `.claude/agents/*.md` mirror itself) remains accepted.
- [Issue #220](https://github.com/mikejmckinney/ai-repo-template/issues/220) — AI Cost-Mitigation Strategy (parent).
- [Phase 2 plan revision (canonical 7 amendments)](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4392976865).
- [Phase 2 implementation plan](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4393545439).
- [Numbering correction (ADR-016 → ADR-019)](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4393550797).
- [Phase 4 handoff orchestration stub](https://github.com/mikejmckinney/ai-repo-template/issues/220#issuecomment-4393282716).
- [#248 Shared subagent body refactor](https://github.com/mikejmckinney/ai-repo-template/issues/248).
- VS Code Copilot custom-agents docs: `https://code.visualstudio.com/docs/copilot/customization/custom-agents` (verified 2026-05-07).
- VS Code Copilot subagents docs: `https://code.visualstudio.com/docs/copilot/agents/subagents` (verified 2026-05-07; source of Amendment #6 cost-ceiling text).
