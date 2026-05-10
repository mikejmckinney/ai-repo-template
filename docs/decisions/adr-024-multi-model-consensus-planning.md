# ADR-024: Multi-model consensus planning (prompt-first; no new role in v1)

## Status

Accepted

## Date

2026-05-10

## Context

Complex architectural and orchestration changes in this repo currently rely on a single planning pass before Judge plan-gate. In practice, manually asking multiple model-backed agents for independent plans has produced better results than any single pass: each model surfaces different tradeoffs, risks, simplifications, and blind spots. The repo lacked a structured way to capture that benefit, and ad-hoc multi-model planning generated formatting drift (each session producing differently-shaped artifacts) and synthesis drift (no agreed-upon way to merge candidate plans into one Judge-gateable artifact).

This ADR is part of the cost-mitigation lineage tracked in parent epic [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) and is downstream of ADR-019 (per-role model tiering). It introduces an **optional, opt-in** planning workflow — not a new default — because multi-model consensus can improve plan quality on high-risk work but also raises model usage and should not become the default path for trivial issues.

This ADR is also constrained by ADR-009 Decision 3 (the dispatch reality matrix): in-session role fan-out is currently fully wired only on Claude Code CLI. The workflow is intended to compare multiple model/platform perspectives — including ones Claude Code cannot reach — so the design must be **prompt-first**, executable across runtimes, with subagent dispatch as a preferred-but-not-required optimization where available.

ADR-023 reorganized role definitions: canonical bodies live in `.agents/<role>.md` and platform overlays in `.github/agents/<role>.agent.md` and `.claude/agents/<role>.md` carry only frontmatter. Adding a new permanent role in v1 would require updating the canonical role set, two platform overlay sets, install file lists (`install.sh` `MULTIAGENT_FILES`), the ownership map, and the N-way mirror/parity checks (`scripts/checks/050-agent-mirror.sh`). That cost is real and should not be paid until the workflow proves useful enough to justify it.

## Decision

We will ship multi-model consensus planning as **a prompt and a guide**, not as a new role:

1. **`.github/prompts/multi-model-consensus-plan.md`** — a shared procedural prompt that defines the candidate-plan and final-consensus-plan formats, candidate orchestration, bias guardrails, candidate failure handling, and the explicit handoff to Judge plan-gate.
2. **`docs/guides/multi-model-consensus.md`** — operator-facing guide covering trigger conditions, when not to use, cost guardrails, runtime fallback, and a worked example.
3. **`.context/rules/repo_orchestration_patterns.md` §P9** — vocabulary entry for **Multi-Model Plan Consensus**. AP promotion (block-on-sight misuse rules) is **deferred** until at least five high-stakes issues have used the workflow and produced enough evidence about misuse and failure modes (uncertain — the "five" threshold is the issue #295 body's recommendation, not a measured value).
4. **No new permanent `synthesizer` role in v1.** The initiating agent (typically Architect) performs the synthesis pass. Promotion to a first-class role is tracked in issue #296 and gated on accumulated usage evidence.

The workflow inherits model-tier expectations from [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) and ADR-019. It does not introduce a parallel model-routing policy. The final consensus plan is **not approval** — Judge plan-gate runs on it like any other plan-as-comment per `.context/rules/process_gates.md`.

The prompt prefers in-session subagents where the runtime supports them (Claude Code CLI today) but must remain executable through separate sessions or manual candidate runs on runtimes that lack in-session fan-out. This is the load-bearing portability constraint per ADR-009 Decision 3.

## Options Considered

### Option 1: Prompt + guide, no new role (chosen)

- **Pros**: Reuses existing infrastructure (prompts/, guides/, ADRs/, plan-gate). No new canonical role. No new platform overlays. No new install-file entries. No new mirror/parity checks. Workflow can be revised by editing one prompt and one guide. Portable across runtimes by design (subagents preferred, separate sessions fall back). Cheapest possible v1.
- **Cons**: Synthesis quality depends on the initiating agent's discipline, since there is no role-level enforcement. Bias guardrails and failure handling live in prose, not in a tools/`description:` contract. If usage proves the workflow durable, a future ADR will need to migrate synthesis into a role anyway.

### Option 2: Add a `.agents/synthesizer.md` role + platform overlays now

- **Pros**: Stronger contract (frontmatter `description:` triggers dispatch; `tools:` constrains what synthesis can do; per-platform `model:` pins). Native dispatch on both Copilot and Claude Code via existing N-way overlay parity. Synthesis behavior is enforceable via tests rather than convention.
- **Cons**: Premature. ADR-023's canonical-out-of-vendor decomposition makes a new role cheap *per file* but not free *per system* — adding `synthesizer` requires touching `install.sh` `MULTIAGENT_FILES`, the ownership map, the multi-agent-coordination guide, the design-patterns reference, and the `scripts/checks/050-agent-mirror.sh` parallel arrays. Doing that for a workflow whose usage rate has not been measured risks expanding the role surface for an experiment. If consensus planning turns out to be useful only one or two times before being supplanted by a different design, we'd be left with a permanent role to deprecate via another ADR.

### Option 3: Pure documentation, no prompt

- **Pros**: Zero new automation surface. Lowest possible cost.
- **Cons**: Without a prompt to anchor the candidate-plan and final-consensus-plan formats, every consensus run reinvents the format. Synthesis comparisons become apples-to-oranges. Loses the legibility benefit that motivated the work. Effectively the status quo we're trying to improve on.

### Option 4: GitHub Action that orchestrates consensus planning end-to-end

- **Pros**: Fully automated; no per-issue manual setup.
- **Cons**: Cross-vendor dispatch from Actions is not solved (no Claude Code dispatcher inside Actions; Copilot has no API for "run this prompt as agent X with model Y"). Adds an `AP8`-class workflow surface to the repo for an experimental pattern. Premature given v1 usage is unknown.

## Consequences

### Positive

- High-risk and ADR-worthy issues gain a structured way to compare multiple-model plans without inventing the format each time.
- The workflow is opt-in, capped at three candidates, and explicitly not the default — usage growth is bounded by the trigger criteria in the guide.
- Adding the workflow does not expand the canonical role set; the role taxonomy stays at 10 (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs).
- Subagent-when-available / separate-session-when-not keeps the prompt portable across runtimes and consistent with ADR-009 Decision 3.
- Bias guardrails and candidate failure handling are explicit in the prompt, reducing the chance the synthesizer rubber-stamps a fluent-but-shallow candidate or silently treats garbage output as valid input.
- The final consensus plan is a plan, not approval — Judge plan-gate is preserved without exception.

### Negative

- Synthesis quality remains dependent on the initiating agent's discipline; the contract is in prose, not in a `tools:`/`description:` declaration.
- Three candidate plans plus one synthesis pass costs more than a single plan-as-comment. The trigger criteria in the guide are the only governor on cost growth.
- Reviewers reading consensus comments must follow more permalinks (the candidate comments) to audit the synthesis.
- If the workflow proves useful, promoting synthesis to a `synthesizer` role later is a separate ADR + the full ADR-023 add-a-role checklist (canonical body, two overlays, install list, ownership, mirror check). Issue #296 tracks that.
- Critic and Judge gain one more pattern (`P9`) to remember when reviewing orchestration-layer changes; the file already had eight patterns.

### Neutral

- The prompt joins the existing shared procedural prompts (`pr-resolve-all.md`, `repo-onboarding.md`, `expand-backlog-entry.md`, `capture-postmortem.md`, `mirror-postmortem.md`, `pre-push-review.md`) and is exempt from Analyst pre-flight per `.github/prompts/README.md` §"Files here".
- `P9` ships as vocabulary only; AP promotion is deferred until five-plus high-stakes uses establish concrete misuse and failure evidence (per the issue body's explicit guidance).

## References

- Parent epic: [#220](https://github.com/mikejmckinney/ai-repo-template/issues/220) — AI cost-mitigation strategy lineage.
- This issue: [#295](https://github.com/mikejmckinney/ai-repo-template/issues/295) — feature request that motivated this ADR.
- Follow-up: [#296](https://github.com/mikejmckinney/ai-repo-template/issues/296) — possible promotion of synthesis to a first-class `synthesizer` role.
- [ADR-009](./adr-009-parallel-multi-agent-execution.md) Decision 3 — dispatch reality matrix that motivates the prompt-first / runtime-fallback design.
- [ADR-019](./adr-019-per-role-model-tiering.md) — model-tier rules this workflow inherits (including Amendment #6: Copilot subagent cost-tier ceiling).
- [ADR-020](./adr-020-orchestration-patterns-reference.md) — pattern reference file this ADR adds `P9` to.
- [ADR-023](./adr-023-shared-subagent-canonical.md) — canonical-out-of-vendor role decomposition that defines the cost of adding a new role.
- [`.github/prompts/multi-model-consensus-plan.md`](../../.github/prompts/multi-model-consensus-plan.md) — the prompt this ADR ratifies.
- [`docs/guides/multi-model-consensus.md`](../guides/multi-model-consensus.md) — operator-facing guide.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) §`P9` — vocabulary entry.
- [`.github/PLAN_TEMPLATE.md`](../../.github/PLAN_TEMPLATE.md) — plan template the final consensus plan stays compatible with.
