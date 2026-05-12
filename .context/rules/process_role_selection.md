# Role selection and context pack usage

> Extracted from AGENTS.md §"Role selection (multi-agent workflow)", §"Context pack usage", and §"Onboarding procedure" in PR for #253 (ADR-021).
> Read before claiming a task or making your first edit in a new session.

## Role selection (multi-agent workflow)

This template supports parallel role-specialized agents. Before editing any file:
1. Identify your role (or ask the user which role to adopt). Canonical role definitions live in [`.agents/`](../../.agents/) (platform-agnostic, ADR-023) — Analyst, Architect, Judge, Critic, PM, Frontend, Backend, QA, DevOps, Docs. Each role has thin platform overlays in [`.github/agents/<role>.agent.md`](../../.github/agents/) (Copilot SDK) and [`.claude/agents/<role>.md`](../../.claude/agents/) (Claude Code) that point back to the canonical.
2. Read `.context/rules/agent_ownership.md` to confirm which paths your role owns.
3. Read the assigned GitHub issue, linked PR (if any), latest `agent-state:v1` comment, and labels to see active claims before editing. Repo-local `_active.md` / `coordination.md` files are legacy compatibility views after ADR-025, not the primary live-state source.
4. Stay inside your owned paths. Any cross-role edit requires PM coordination. **Never guess ownership silently** — escalate to PM.
5. Full workflow (analysis → plan-gate → dispatch → parallel implementation → QA → diff-gate → merge) is documented in `docs/guides/multi-agent-coordination.md`.

## Context pack usage

- Start with `.context/00_INDEX.md` for project overview
- Check the assigned GitHub issue, linked PR, latest `agent-state:v1` comment, and labels for current work in progress
- Reference `.context/rules/` for constraints that must not be violated
- Use `.context/roadmap.md` to understand project phases
- Reference `.context/vision/` for design mockups and architecture

## Onboarding procedure

1. Read [`AI_REPO_GUIDE.md`](../../AI_REPO_GUIDE.md).
2. Read `.context/00_INDEX.md` if it exists.
3. Check the assigned GitHub issue, linked PR, latest `agent-state:v1` comment, and labels for cognitive handoff from previous sessions.
4. If AI_REPO_GUIDE.md missing or stale: follow [`.github/prompts/repo-onboarding.md`](../../.github/prompts/repo-onboarding.md) to rebuild context.
