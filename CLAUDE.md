# CLAUDE.md

> **For Claude Code**: this file exists so Claude Code's native memory loader picks up the canonical agent documentation. The actual instructions live in **`AGENTS.md`** — read that first.

## Read first

1. **`AGENTS.md`** — truth hierarchy, role selection, onboarding, testing, validation. All other AI tools (Copilot, Cursor, Gemini) also read this file.
2. **`AI_REPO_GUIDE.md`** — structured reference (files, conventions, verification commands) optimized for agent consumption.
3. **`.context/00_INDEX.md`** — project memory entry point. Lazy-loads rules, state, roadmap, and vision.

## Role selection

Before editing any file, identify your role (Architect, Judge, Critic, PM, Frontend, Backend, QA, DevOps, Docs) and consult:

- `.github/agents/<your-role>.agent.md` — your responsibilities and Do / Don't list.
- `.context/rules/agent_ownership.md` — the canonical path-ownership map.
- `.context/state/coordination.md` — live claim board and task state machine.

Full multi-agent workflow: `docs/guides/multi-agent-coordination.md`.

## Why a pointer and not a full copy

`AGENTS.md` is the single source of truth for agent instructions in this repo. Duplicating its content here would just create a drift hazard. This file is a minimal entry point so Claude Code's native `CLAUDE.md` auto-load convention routes to the canonical source.
