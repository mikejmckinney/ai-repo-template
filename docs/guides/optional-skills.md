# Optional Skills & External Harnesses

> **Purpose**: Curated list of optional external tools that extend Claude Code (or compatible AI harnesses) with additional skills, agents, or workflows. **None of these are vendored** into this template — they are per-project opt-ins. Pick what fits your stack.

## Why Not Vendor?

This repo is a **language-agnostic template**. Vendoring large opinionated tool collections would:

- Force downstream projects to adopt a specific stack (usually TS/Node).
- Balloon the template's maintenance surface.
- Contradict the "minimal, focused files" philosophy in `docs/guides/agent-best-practices.md:17-52`.

Instead, we document the good options and let each project install what it needs.

## When to Reach for Optional Skills

Only install an optional skill when:

1. It solves a problem your **role-specialized agents** (see `multi-agent-coordination.md`) can't handle alone.
2. It fits your actual stack (not "might be cool someday").
3. The install's footprint is justified by active, repeated use.

## Built-in Baseline

Before reaching for any of the external options below, note that the template already ships `.context/rules/domain_code_quality.md` — a language-neutral SOLID / TDD / clean-code floor that Judge and Critic enforce during review. The curated options in this file **extend or replace** that baseline for teams that want stricter or stack-specific enforcement.

## Curated Options

### SOLID Skills

- **Repo**: https://github.com/ramziddin/solid-skills
- **What it is**: A single Claude Code skill that enforces SOLID principles, TDD red-green-refactor, clean code naming, and clean-architecture vertical slicing.
- **Fits**: Object-oriented codebases, primarily **TypeScript / NestJS**. Also useful for any OO language where SOLID applies.
- **Skip if**: Your project is primarily functional (Haskell, Elm, Rust idiomatic style), scripting (shell, Python glue), or your team already has strong review conventions.
- **Install**:
  ```bash
  npx skills add ramziddin/solid-skills
  ```
- **Where it lands**: Claude Code skills dir (typically `~/.claude/skills/solid/`). Not committed to the repo.
- **How it interacts with this template's roles**: Activates when Frontend / Backend agents write or refactor code. Complements Judge's diff-gate.

### Everything Claude Code

- **Repo**: https://github.com/affaan-m/everything-claude-code
- **What it is**: A large opinionated harness bundling 36+ specialized subagents, 150+ skills, 79+ slash commands, hooks, and cross-language rules.
- **Fits**: Teams that want a batteries-included setup and are willing to prune what they don't use.
- **Skip if**: You prefer the minimal role-based model this template already provides, or you don't want to maintain a large skill graph.
- **Warnings**:
  - Opinionated defaults may conflict with this template's ownership map.
  - Size is substantial — review what actually activates in your sessions.
  - Overlap with role agents in `.github/agents/**`: decide which system owns each concern before installing to avoid duplicate/contradictory instructions.
- **Install (plugin)**:
  ```
  /plugin marketplace add https://github.com/affaan-m/everything-claude-code
  /plugin install ecc@ecc
  ```
- **Install (manual)**:
  ```bash
  git clone https://github.com/affaan-m/everything-claude-code.git
  ./install.sh --profile full   # or a language-specific profile
  ```

### OpenClaw (optional runtime framework)

- **Repo**: https://github.com/ramziddin/openclaw
- **What it is**: A Python-based agent runtime with a persistent task DB (PocketBase), cron-driven heartbeats, and webhook notifications (e.g. Telegram, Slack). Wraps Claude to run multi-agent teams autonomously between sessions.
- **Fits**: You need **continuously-running autonomous agents** — e.g. a marketing-ops or research team that wakes itself up every N minutes without a human triggering it. You're comfortable running a Python + PocketBase service alongside your app.
- **Skip if**: The opt-in `agent-heartbeat.yml.template` GitHub Action already covers your "nudge on stuck tasks" needs (it usually does); you want to keep the template language-agnostic and dependency-free; you don't want a message-bus dependency.
- **Interaction with this template's roles**:
  - OpenClaw's *coordinator / boss* maps to `pm.agent.md`. Pick one to own dispatch — don't run both.
  - Its *review gates* map to `judge.agent.md` (procedural) and `critic.agent.md` (subjective). Reuse the existing role files inside OpenClaw rather than recreating them.
  - Its task DB duplicates `.context/state/**`. Pick one as canonical — the markdown files are git-native and survive without the runtime; the DB is live but requires OpenClaw to read.
- **Install**: Follow the OpenClaw repo's instructions. This template intentionally does not vendor the runtime — see "Why Not Vendor?" above.
- **Record the decision**: If you adopt OpenClaw, add an ADR under `docs/decisions/` noting which system owns dispatch and state, to prevent future agents from drifting.

## Recommended Integration Pattern

If you install one of these and it conflicts with a role agent in `.github/agents/**`:

1. Decide which system is the source of truth for that concern.
2. Remove or mute the duplicate from the other system.
3. Record the decision in an ADR under `docs/decisions/` so future sessions understand the split.

## Adding New Options

When a new skill or harness proves valuable, add an entry here with:

- Repo URL
- One-line "what it is"
- "Fits" + "Skip if" for quick stack-matching
- Install command
- Any interaction notes with the existing role agents

Keep entries short. This file is a menu, not a manual.

## See Also

- `.github/agents/` — the role agents this template ships with by default.
- `docs/guides/multi-agent-coordination.md` — how the built-in roles coordinate.
- `docs/guides/agent-best-practices.md` — constraints that apply to any skill you add.
