# CLAUDE.md

> **For Claude Code**: this file exists so Claude Code's native memory loader picks up the canonical agent documentation. The actual instructions live in **`AGENTS.md`** — read that first.

@AGENTS.md

## Read first

1. **[`AGENTS.md`](AGENTS.md)** — thin contract: handshake, truth hierarchy, link table to per-concern process rules. All other AI tools (Copilot, Cursor, Gemini) also read this file. Per-concern rules live under `.context/rules/process_*.md`.
2. **[`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md)** — structured reference (files, conventions, verification commands) optimized for agent consumption.
3. **[`.context/00_INDEX.md`](.context/00_INDEX.md)** — project memory entry point. Lazy-loads rules, state, roadmap, and vision.
4. **[`.github/PLAN_TEMPLATE.md`](.github/PLAN_TEMPLATE.md)** — copy this template into a comment on any issue you're about to implement, before writing code. See [`.context/rules/process_gates.md`](.context/rules/process_gates.md) and ADR-011 for the full rules and exemptions.
5. **[`.github/prompts/op-issue-workflow.md`](.github/prompts/op-issue-workflow.md)** — end-to-end OP issue→merge playbook for the default agent. Read the first time you pick up an issue.

## Role selection

Before editing any file, identify your role (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs) and consult:

- [`.agents/<your-role>.md`](.agents/) — your full role definition (canonical, platform-agnostic; per ADR-023).
- [`.github/agents/<your-role>.agent.md`](.github/agents/) — Copilot SDK custom-agent registration overlay (frontmatter only; points to canonical).
- [`.claude/agents/<your-role>.md`](.claude/agents/) — Claude Code subagent registration overlay (frontmatter only; points to canonical).
- [`.context/rules/agent_ownership.md`](.context/rules/agent_ownership.md) — the canonical path-ownership map.
- [`.context/rules/process_role_selection.md`](.context/rules/process_role_selection.md) — multi-agent workflow protocol.
- Assigned GitHub issue, linked PR, latest `agent-state:v1` comment, and labels — primary live coordination state per ADR-025.

Full multi-agent workflow: see [docs/guides/multi-agent-coordination.md](docs/guides/multi-agent-coordination.md).

## Native subagents

The 10 roles above are registered as native Claude Code subagents in `.claude/agents/**`. You can dispatch each via the `Task` tool:

```
Task(subagent_type: 'analyst', ...)
Task(subagent_type: 'architect', ...)
Task(subagent_type: 'judge', ...)
Task(subagent_type: 'critic', ...)
Task(subagent_type: 'pm', ...)
Task(subagent_type: 'frontend', ...)
Task(subagent_type: 'backend', ...)
Task(subagent_type: 'qa', ...)
Task(subagent_type: 'devops', ...)
Task(subagent_type: 'docs', ...)
```

Claude Code will also auto-invoke the right role when a user request matches a subagent's `description:` frontmatter. The same `description:` string is used by GitHub Copilot's SDK custom-agent runtime when it reads `.github/agents/*.agent.md` — `test.sh` enforces that every overlay's `description:` matches the canonical `.agents/<role>.md` byte-for-byte so all loaders dispatch on the same text. See `docs/decisions/adr-023-shared-subagent-canonical.md` (and the partially-superseded `docs/decisions/adr-003-claude-code-subagent-registration.md`).

## Why a pointer and not a full copy

`AGENTS.md` is the single source of truth for agent instructions in this repo. Duplicating its content here would just create a drift hazard. This file is a minimal entry point so Claude Code's native `CLAUDE.md` auto-load convention routes to the canonical source.

## Why at the repo root (not `.claude/CLAUDE.md`)

Claude Code's memory loader auto-discovers **either** `./CLAUDE.md` **or** `./.claude/CLAUDE.md` for project instructions (see the ["Choose where to put CLAUDE.md files" table in the memory docs](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files)). Both locations are equally valid and are also picked up by `anthropics/claude-code-action@v1`, which runs the Claude Code CLI under the hood.

We keep this file at the repo root by convention — it's the `/init` default, it's the location most contributors expect, and it keeps `CLAUDE.md` visible next to `AGENTS.md` / `AI_REPO_GUIDE.md` / `README.md` in directory listings and GitHub's file browser. Moving it to `.claude/CLAUDE.md` would be functionally equivalent; it's a preference, not a requirement.

Note that `.claude/agents/*.md` (the 10 role subagent registrations) is a **different** slot — that's a separate schema-incompatible loader for subagents, described in `docs/decisions/adr-003-claude-code-subagent-registration.md`. `.claude/CLAUDE.md` and `.claude/agents/*.md` can coexist.
