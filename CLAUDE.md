# CLAUDE.md

> **For Claude Code**: this file exists so Claude Code's native memory loader picks up the canonical agent documentation. The actual instructions live in **`AGENTS.md`** — read that first.

## Read first

1. **`AGENTS.md`** — truth hierarchy, role selection, onboarding, testing, validation. All other AI tools (Copilot, Cursor, Gemini) also read this file.
2. **`AI_REPO_GUIDE.md`** — structured reference (files, conventions, verification commands) optimized for agent consumption.
3. **`.context/00_INDEX.md`** — project memory entry point. Lazy-loads rules, state, roadmap, and vision.

## Role selection

Before editing any file, identify your role (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs) and consult:

- `.github/agents/<your-role>.agent.md` — your responsibilities and Do / Don't list (canonical).
- `.claude/agents/<your-role>.md` — the Claude Code subagent registration mirror (points back to the canonical file).
- `.context/rules/agent_ownership.md` — the canonical path-ownership map.
- `.context/state/coordination.md` — live claim board and task state machine.

Full multi-agent workflow: `docs/guides/multi-agent-coordination.md`.

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

Claude Code will also auto-invoke the right role when a user request matches a subagent's `description:` frontmatter. The same `description:` string is used by GitHub Copilot's SDK custom-agent runtime when it reads `.github/agents/*.agent.md` — `test.sh` enforces that both copies stay byte-identical so the two loaders dispatch on the same text. See `docs/decisions/adr-003-claude-code-subagent-registration.md`.

## Why a pointer and not a full copy

`AGENTS.md` is the single source of truth for agent instructions in this repo. Duplicating its content here would just create a drift hazard. This file is a minimal entry point so Claude Code's native `CLAUDE.md` auto-load convention routes to the canonical source.

## Why at the repo root (not `.claude/CLAUDE.md`)

Claude Code's memory loader auto-discovers **either** `./CLAUDE.md` **or** `./.claude/CLAUDE.md` for project instructions (see the ["Choose where to put CLAUDE.md files" table in the memory docs](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files)). Both locations are equally valid and are also picked up by `anthropics/claude-code-action@v1`, which runs the Claude Code CLI under the hood.

We keep this file at the repo root by convention — it's the `/init` default, it's the location most contributors expect, and it keeps `CLAUDE.md` visible next to `AGENTS.md` / `AI_REPO_GUIDE.md` / `README.md` in directory listings and GitHub's file browser. Moving it to `.claude/CLAUDE.md` would be functionally equivalent; it's a preference, not a requirement.

Note that `.claude/agents/*.md` (the 10 role subagent registrations) is a **different** slot — that's a separate schema-incompatible loader for subagents, described in `docs/decisions/adr-003-claude-code-subagent-registration.md`. `.claude/CLAUDE.md` and `.claude/agents/*.md` can coexist.
