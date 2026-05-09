# GitHub Copilot — repository instructions

> **For GitHub Copilot**: this file is the `.github/copilot-instructions.md` slot Copilot auto-reads. The actual instructions live in **`AGENTS.md`** — read that first. This file carries only Copilot-specific behavior inline.

## Read first

1. **[`AGENTS.md`](../AGENTS.md)** — thin contract: handshake, truth hierarchy, link table to per-concern process rules. All other AI tools (Claude, Cursor, Gemini) also read this file. Per-concern rules live under `.context/rules/process_*.md`.
2. **[`AI_REPO_GUIDE.md`](../AI_REPO_GUIDE.md)** — structured reference (files, conventions, verification commands) optimized for agent consumption.
3. **[`.context/00_INDEX.md`](../.context/00_INDEX.md)** — project memory entry point. Lazy-loads rules, state, roadmap, and vision.
4. **[`.github/PLAN_TEMPLATE.md`](PLAN_TEMPLATE.md)** — copy this template into a comment on any issue you're about to implement, before writing code. See [`.context/rules/process_gates.md`](../.context/rules/process_gates.md) and ADR-011 for the full rules and exemptions.

## Role selection

Before editing any file, identify your role (analyst, architect, judge, critic, pm, frontend, backend, qa, devops, docs) and consult:

- [`.agents/<your-role>.md`](../.agents/) — your full role definition (canonical, platform-agnostic; per ADR-023).
- [`.github/agents/<your-role>.agent.md`](agents/) — Copilot SDK custom-agent registration overlay (frontmatter only; points to canonical).
- [`.context/rules/agent_ownership.md`](../.context/rules/agent_ownership.md) — the canonical path-ownership map.
- [`.context/rules/process_role_selection.md`](../.context/rules/process_role_selection.md) — multi-agent workflow protocol.
- [`.context/state/coordination.md`](../.context/state/coordination.md) — live claim board and task state machine.

Full multi-agent workflow: [`docs/guides/multi-agent-coordination.md`](../docs/guides/multi-agent-coordination.md).

## Subagent dispatch (Copilot-specific)

Unlike Claude Code, the VS Code Copilot Chat surface does **not**
automatically route a user message to the right role subagent based on the
agent's `description:` field. The default agent (you) handles everything
unless one of the following happens:

1. The user `@mention`s a role explicitly (e.g. `@Architect`, `@Judge`).
2. The user invokes `#runSubagent` to force a specific role.
3. **You proactively call the `runSubagent` tool yourself.**

**Use `runSubagent` proactively** whenever a task fits a registered role's
specialty rather than absorbing the work into the default agent. The 10
roles (analyst, architect, backend, critic, devops, docs, frontend, judge,
pm, qa) are registered as Copilot SDK custom agents under
[`.github/agents/`](agents/) with bodies pointing to canonical
[`.agents/<role>.md`](../.agents/). Each role's `description:` frontmatter
field is the dispatch hint — match the user's request against those.

Heuristics for when to dispatch:

- Research / market validation / "should we build this" → `Analyst`
- Plan / ADR / decompose feature into tasks → `Architect`
- Server code, APIs, models, migrations → `Backend`
- UI components, pages, styles → `Frontend`
- Tests, CI triage, coverage gates → `QA`
- Workflows, install scripts, CI config → `DevOps`
- README / AI_REPO_GUIDE / docs/ updates → `Docs`
- Plan-gate or diff-gate review (APPROVE / REQUEST_CHANGES / BLOCK) → `Judge`
- Devil's-advocate review for hidden assumptions / AI clichés → `Critic`
- Dispatching approved plans into per-role task files → `Project Manager`

Don't dispatch for trivial single-step operations (one-line edit, single
file read, quick lookup) — the dispatch overhead isn't worth it. Do
dispatch when the task naturally lives inside one role's owned paths or
benefits from that role's specialized prompt.

Mid-chain agent-to-agent handoffs (declared via the `handoffs:` field in
each `.github/agents/<role>.agent.md` overlay, with `send: true` for
automatic firing) are a separate mechanism — they kick in once a subagent
is already running and finishes its hop. The user-message → first-agent
selection is still your responsibility as the default agent.

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

- `REVIEW_ON_PUSH` — when set to literal `false`, disables the `agent-review-on-push.yml` nudges to Gemini + Copilot after each push to an open non-draft PR. Default unset = on. See `docs/guides/agent-pipeline.md` § Repository variables.
- `PR_RESOLVE_MAX_ROUNDS` — max rounds `pr-resolve-all.md` runs per PR before escalating (integer; default `3`). Per-PR override: `cap-override` label on the PR (unbounded) or `@<agent> cap-override N` comment on the PR (N rounds). See `docs/guides/agent-pipeline.md` § Repository variables.

## Code review behavior (Copilot pull-request reviewer)

When Copilot is invoked as a PR reviewer (the `copilot-pull-request-reviewer[bot]`
identity), apply the same dedup discipline that `.cursor/BUGBOT.md` and
`.gemini/styleguide.md` describe so repeat findings don't pile up across
rounds:

- Before flagging an issue, scan the PR's existing review threads (open AND
  resolved). If the same issue on the same `file:line` is already present in
  any thread, do **not** re-report it.
- Skip any issue whose existing thread contains a reply matching the literal
  prefix `Deferred —` (the deferral marker emitted by
  `.github/prompts/pr-resolve-all.md` Phase 4). That issue has been triaged
  as out-of-scope, not-reproducible, or a known limitation; re-raising it is
  noise.
- Honor the project-convention skip lists in `.cursor/BUGBOT.md` and
  `.gemini/styleguide.md` (KL-01..KL-05 and the "Project conventions (skip
  these classes of finding)" sections). Those patterns are intentional and
  must not be flagged at any severity.
- A finding that is genuinely *new information* on the same line (a
  different bug, not the same bug from a different angle) is not a
  duplicate. When in doubt, prefer skipping over re-raising.
