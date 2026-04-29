# GitHub Copilot — repository instructions

> **For GitHub Copilot**: this file is the `.github/copilot-instructions.md` slot Copilot auto-reads. The actual instructions live in **`AGENTS.md`** — read that first. This file carries only Copilot-specific behavior inline.

## Read first

1. **[`AGENTS.md`](../AGENTS.md)** — truth hierarchy, role selection, onboarding, plan-as-comment requirement, Analyst pre-flight gate, testing, validation. All other AI tools (Claude, Cursor, Gemini) also read this file.
2. **[`AI_REPO_GUIDE.md`](../AI_REPO_GUIDE.md)** — structured reference (files, conventions, verification commands) optimized for agent consumption.
3. **[`.context/00_INDEX.md`](../.context/00_INDEX.md)** — project memory entry point. Lazy-loads rules, state, roadmap, and vision.
4. **[`.github/PLAN_TEMPLATE.md`](PLAN_TEMPLATE.md)** — copy this template into a comment on any issue you're about to implement, before writing code. See AGENTS.md → "Plan-as-comment requirement" and ADR-011 for the full rules and exemptions.

## Role selection

Before editing any file, identify your role (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs) and consult:

- `.github/agents/<your-role>.agent.md` — your responsibilities and Do / Don't list (canonical).
- `.context/rules/agent_ownership.md` — the canonical path-ownership map.
- `.context/state/coordination.md` — live claim board and task state machine.

Full multi-agent workflow: `docs/guides/multi-agent-coordination.md`.

## Following referenced prompt files (Copilot-specific)

When a comment or issue body contains `@copilot follow <path>` (e.g.
`@copilot follow .github/prompts/pr-resolve-all.md`):

1. Only the first `@copilot follow <path>` per comment is processed. If the
   path doesn't exist or isn't under `.github/prompts/`, post a single
   comment explaining and stop.
2. Read the entire file at `<path>` before anything else.
3. Treat its contents as primary task instructions, overriding shorter
   instructions in the mention.
4. Execute every phase/step in order. Do not skip phases.
5. If the file's "Rules" or "Verification" section conflicts with defaults
   elsewhere in this repo, the referenced file wins for this task.
6. If your cumulative response would exceed GitHub's per-comment limit
   (~65 KB), split across sequential comments labeled `Part 1/N`,
   `Part 2/N`, ... rather than truncating. Post each part as soon as ready.

Mirrors the `@claude follow <path>` convention in `.github/workflows/claude.yml`.

## Why a pointer and not a full copy

`AGENTS.md` is the single source of truth for agent instructions in this repo. Duplicating its content here would just create a drift hazard — see experiment [#208](https://github.com/mikejmckinney/ai-repo-template/issues/208), which confirmed Copilot follows markdown references from this file to AGENTS.md and other repo files. [`CLAUDE.md`](../CLAUDE.md) uses the same pointer pattern for the same reason.

When AGENTS.md headings change, the references in this file's "Read first" and "Role selection" sections must be re-verified — see `.context/rules/process_doc_maintenance.md`.

## Repository knobs (variables)

- `REVIEW_ON_PUSH` — when set to literal `true`, the `agent-review-on-push.yml` workflow nudges Gemini + Copilot to re-review after each push to an open non-draft PR. Default unset = off. See `docs/guides/agent-pipeline.md` § Step 3.
