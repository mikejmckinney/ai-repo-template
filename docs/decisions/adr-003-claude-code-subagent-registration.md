# ADR-003: Register role agents as native Claude Code subagents

## Status

Accepted

## Date

2026-04-14

## Context

This template ships 9 role-specialized agent markdown files under `.github/agents/**` (architect, judge, critic, pm, frontend, backend, qa, devops, docs). They have been authored from day one in **Copilot's custom-agent schema**: the `.agent.md` filename suffix, YAML frontmatter with `name`, `description`, and lowercase Copilot tool names (`read`, `write`, `search`, `fetch`, `githubRepo`, `usages`). Per `docs.github.com/en/copilot/how-tos/copilot-sdk/use-copilot-sdk/custom-agents` and the 2025-10-28 GitHub Copilot "Custom agents" GA changelog, Copilot's SDK custom-agent runtime already auto-delegates to a sub-agent whose `description:` matches the user's intent, so for Copilot users these roles are already fully wired up with no action required.

Claude Code has a conceptually parallel but schema-incompatible subagent loader. It reads `.claude/agents/*.md` and expects:

- kebab-case `name:` (not two-word or TitleCase)
- Claude Code tool names (`Read`, `Write`, `Edit`, `Grep`, `Glob`, `Bash`, `Task`, `WebFetch`) — the Copilot tool names are not recognized and are silently ignored
- optional `model:` override
- a body that becomes the subagent's system prompt

Without a `.claude/agents/` mirror, Claude Code treats `.github/agents/*.agent.md` as **documentation only** — the main conversation can read them as reference material, but Claude Code cannot dispatch them via the `Task` tool, and auto-dispatch on `description:` never fires because Claude Code has no subagents registered. Concretely, a user who clones this template and asks *"create a pong game"* in Claude Code sees the entire feature built inline in the main conversation, losing the multi-agent benefits (parallel work, ownership enforcement, plan-gate / diff-gate automation) that the template's documentation promises.

While verifying this plan with the user, we also found a pre-existing bug in `.github/agents/architect.agent.md`: the `tools:` list lacked `'write'` even though architect's `owned_paths:` block (same file) includes `docs/decisions/**`, `.context/roadmap.md`, `.context/vision/architecture/**`, and `.context/rules/**` — all write targets. Every other non-review role has `'write'`; judge and critic correctly don't. The "plan-only, no implementation code" rule is enforced by body text, not by removing the write tool. Fixed in the same commit as this ADR.

## Decision

We will ship a **parallel `.claude/agents/*.md` registry** that mirrors the 9 roles in `.github/agents/**`. Each `.claude/agents/<role>.md` file contains:

1. Claude Code frontmatter — kebab-case `name:`, the shared `description:` string, a Claude-Code-schema `tools:` list, and `model: inherit`.
2. A ~30-line pointer body that tells the subagent to read the canonical `.github/agents/<role>.agent.md` file, plus the coordination files (`AGENTS.md`, `docs/guides/multi-agent-coordination.md`, `.context/rules/agent_ownership.md`, `.context/state/coordination.md`, `AI_REPO_GUIDE.md`, `.context/00_INDEX.md`).
3. Role-specific handoff guidance pointing at `Task(subagent_type: <next-role>, ...)`.

We will also:

- **Normalize all 9 `description:` fields** in `.github/agents/*.agent.md` to the same trigger-phrase form used in `.claude/agents/*.md`. Copilot's SDK runtime matches on `description:` the same way Claude Code does, so any improvement to auto-dispatch quality benefits both loaders. Using byte-identical strings lets us enforce a `test.sh` invariant.
- **Enforce description parity** in `test.sh` (`grep -m1 '^description:'` on both copies; fail on any mismatch).
- **Enforce mirror completeness** in `test.sh` (every `.github/agents/<role>.agent.md` must have a matching `.claude/agents/<role>.md`).
- **Update `install.sh`** so the Codespaces bootstrap `MULTIAGENT_FILES` array copies the 9 new mirror files into the workspace.
- **Update `.context/rules/agent_ownership.md`** to register `.github/agents/**` / `.claude/agents/**` as Architect-owned with PM coordination.
- **Fix architect's missing `'write'` tool** in `.github/agents/architect.agent.md` (side-fix, same commit).

## Options Considered

### Option 1: Mirror `.github/agents/**` into `.claude/agents/**` (chosen)
- **Pros**: Non-breaking for Copilot / Cursor / Gemini, which continue reading `.github/agents/**`. Gives Claude Code native subagent dispatch. Pointer-body design keeps detailed role definitions in a single file (`.github/agents/<role>.agent.md`). `test.sh` invariants prevent drift at the frontmatter level.
- **Cons**: Two files per role. Adding a new role requires updating both and updating `install.sh` + `test.sh` + this guide. Pointer bodies duplicate a small amount of "mandatory reading" list content.

### Option 2: Move everything to `.claude/agents/`
- **Pros**: Single location. Simpler mental model.
- **Cons**: **Breaks Copilot's custom-agent runtime** — Copilot looks at `.github/agents/*.agent.md`, not `.claude/`. Also breaks any Cursor / Gemini pathway that reads `.github/agents/`. Non-starter for a template that intentionally targets multiple AI harnesses.

### Option 3: Symlink `.claude/agents/<role>.md` → `.github/agents/<role>.agent.md`
- **Pros**: No duplication.
- **Cons**: The two loaders require **different frontmatter schemas** (lowercase Copilot tool names vs. TitleCase Claude Code tool names; `Project Manager` vs. `pm` for the `name:` field). A symlinked file can only satisfy one schema. Symlinks in git also have historical reliability issues on Windows Codespaces.

### Option 4: Generate `.claude/agents/` from `.github/agents/` at install time via a transform script
- **Pros**: Single source of truth for everything, not just `description:`.
- **Cons**: Adds a script dependency (Python or `yq`) to the template bootstrap — this template is deliberately language-agnostic and shell-only. Creates a drift window between in-repo state and generated state. Tooling friction for anyone auditing `.claude/agents/` content in git history. **Rejected for v1** — may revisit later if the mirror becomes a maintenance burden.

## Consequences

### Positive

- Claude Code can now auto-dispatch any of the 9 roles via `Task(subagent_type: <role>, ...)`. The multi-agent coordination workflow documented in `docs/guides/multi-agent-coordination.md` works out of the box in any template-derived repo.
- Auto-dispatch also fires when a user request matches a role's `description:` — both Copilot and Claude Code benefit from the description-tuning normalization.
- Canonical role content lives in exactly one place (`.github/agents/<role>.agent.md`). The `.claude/` mirror is a thin pointer that always defers to it.
- Description parity is guaranteed by `test.sh`, so the Copilot loader and Claude Code loader always dispatch on the same string.
- Architect can now actually write its own ADRs and roadmap updates (tool fix).

### Negative

- Adding a new role requires updating two files (plus `install.sh`, `test.sh`, the ownership table, and this guide). `test.sh` makes forgetting the mirror a hard failure, but forgetting `install.sh` is only caught at the Codespaces bootstrap step.
- The `.claude/agents/*.md` pointer bodies duplicate a ~10-line "mandatory reading" list. This content could drift from the canonical role file over time; we accept this because the pointer body is intentionally minimal and stable.
- The `description:` parity invariant forbids tool-specific wording. If we ever want to phrase one role's description differently for Copilot and Claude Code (e.g., because one loader turns out to match substrings differently), we'd have to retire Check B in `test.sh`.

### Neutral

- Cursor and Gemini CLI continue reading `.github/agents/**` unchanged. Their dispatch behavior is unaffected by this change.
- The existing `owned_paths:` and `handoff_targets:` keys in `.github/agents/*.agent.md` remain Copilot-specific YAML extensions. Claude Code ignores them; we intentionally do not replicate them in `.claude/agents/*.md` to keep the mirror thin.

## Implementation

- [x] Create `.claude/agents/{architect,judge,critic,pm,frontend,backend,qa,devops,docs}.md` with Claude Code schema frontmatter and pointer bodies.
- [x] Normalize all 9 `description:` lines in `.github/agents/*.agent.md` to trigger-phrase form, identical to the `.claude/` mirror.
- [x] Fix `.github/agents/architect.agent.md` missing `'write'` tool.
- [x] Extend `install.sh` `MULTIAGENT_FILES` array with the 9 new mirror files.
- [x] Extend `test.sh` `REQUIRED_FILES` with the 9 new mirror files and add Check A (mirror completeness) + Check B (description parity).
- [x] Update `.context/rules/agent_ownership.md` Shared / Contested Files table to register `.github/agents/**` / `.claude/agents/**` as Architect-owned.
- [x] Update `docs/guides/multi-agent-coordination.md` with a "How AI tools dispatch these roles" section.
- [x] Update `CLAUDE.md` with a "Native subagents" section.

## Future Work

- **Automated generation** of `.claude/agents/` from `.github/agents/` via a transform script — revisit if the maintenance burden of manual mirroring becomes significant.
- **Nested auto-handoff validation** — empirically confirm that a subagent invoking `Task(subagent_type: <next>, ...)` from within its own session produces the chained flow described in `multi-agent-coordination.md`'s end-to-end diagram. Document any caveats.
- **Optional Copilot schema fields** — consider adding `target:`, `user-invocable:`, or `disable-model-invocation:` to specific roles if we want to opt any role out of auto-dispatch.

## References

- GitHub Copilot docs — Custom agents and sub-agent orchestration: `docs.github.com/en/copilot/how-tos/copilot-sdk/use-copilot-sdk/custom-agents`
- GitHub Copilot docs — Custom agents configuration reference: `docs.github.com/en/copilot/reference/custom-agents-configuration`
- GitHub Changelog 2025-10-28 — Custom agents for GitHub Copilot GA
- Claude Code docs — Create custom subagents: `code.claude.com/docs/en/sub-agents`
- Claude Code docs — Subagents in the SDK: `code.claude.com/docs/en/agent-sdk/subagents`
- `docs/guides/multi-agent-coordination.md` — the multi-agent workflow this ADR enables
- ADR-001 — Context pack structure
- ADR-002 — AGENTS.md ownership
