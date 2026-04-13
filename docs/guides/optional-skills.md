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
