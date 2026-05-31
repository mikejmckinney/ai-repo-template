<!-- TEMPLATE_PLACEHOLDER: GENERATED FROM mikejmckinney/ai-repo-template. -->
<!-- THIS REPO IS NOT THE TEMPLATE ITSELF. Replace this README for the actual project. -->

# AI-Ready Repository Template

<!-- Agent Status Badge - Update phase as project progresses -->
<!-- Options: Phase 0: Design | Phase 1: Foundation | Phase 2: Development | Phase 3: Polish | Phase 4: Maintenance -->
![Agent Status](https://img.shields.io/badge/Agent%20Status-Phase%200%3A%20Design-blue)

A template repository for GitHub Codespaces that provides pre-configured AI agent prompts, context management for LLM memory, and automatic development environment setup. Use this as a starting point for new repositories or link it to your Codespaces settings.

> **For AI Agents**: See `AI_REPO_GUIDE.md` for a concise reference optimized for agent consumption.

## Motivation

This template exists to give a new repository a working AI-collaboration baseline on day one: startup instructions, durable context, and human-readable docs that do not fight each other.

The split between `README.md`, `AI_REPO_GUIDE.md`, `AGENTS.md`, `.context/`, and `docs/` is intentional. Humans need setup and rationale; agents need a compact reference and canonical state surfaces. The template keeps those concerns separate so onboarding stays clear instead of collapsing into one noisy file.

## Repo map

The repo looks like it has duplicated documentation. It doesn't — each location targets a different audience or loader. See `docs/guides/context-files-explained.md` for the full rationale and ADR references.

| Location | Audience / Loader | Role |
|----------|-------------------|------|
| `README.md` (this file) | Humans | Setup, features, customization — verbose on purpose |
| `AI_REPO_GUIDE.md` | AI agents | Token-optimized command/structure/convention reference |
| `docs/` | Humans | Deep reference: guides, ADRs, research |
| `.context/` | AI agents | Canonical project truth: rules, state, roadmap, vision (lazy-loaded) |
| `CLAUDE.md` (root) | Claude Code native loader | Project memory pointer to `AGENTS.md`. Kept at root by convention; `./.claude/CLAUDE.md` would also work ([memory docs](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files)) |
| `AGENTS.md` (root) | Most other AI tools | Root agent instructions (Copilot, Cursor, Gemini, etc.) |
| `.claude/agents/` | Claude Code subagent loader | Role mirrors registered as native subagents (see ADR-003) |
| `.github/agents/` | Copilot SDK custom-agent runtime | Canonical role files for multi-agent work |
| `install.sh` (root) | GitHub Codespaces "Dotfiles" | Bootstrap script — Codespaces expects it at repo root |
| `test.sh` (root) | `.github/workflows/ci-tests.yml` | Template verification, invoked by CI as `./test.sh` |
| `scripts/` | Project consumers (post-clone) | One-time project customization (`setup.sh`, `verify-env.sh`) |

**Why not consolidate?** `docs/` vs `.context/` and `README.md` vs `AI_REPO_GUIDE.md` were explicitly evaluated and rejected in `docs/decisions/adr-001-context-pack-structure.md` — different audiences and a truth hierarchy. `install.sh`/`test.sh` cannot move to `scripts/` without breaking the Codespaces Dotfiles convention and the CI workflow. `CLAUDE.md` is a soft convention — it *could* live at `./.claude/CLAUDE.md` and Claude Code would still auto-discover it, but we keep it at the root alongside `AGENTS.md` and `AI_REPO_GUIDE.md` for visibility.

## Features

- **AI Agent Prompts** - Pre-configured prompts for onboarding AI assistants to any codebase
- **Multi-Agent Roles** - Role-specialized agent files (Analyst, Architect, Frontend, Backend, PM, QA, DevOps, Docs, Judge, Critic) with an ownership map so multiple agents can work in parallel without code conflicts
- **Context Pack** - Structured directory (`.context/`) for project memory across LLM sessions
- **Automatic Extension Installation** - Essential VS Code extensions installed on Codespace start
- **Multi-Platform Support** - Works with Cursor, GitHub Copilot, Gemini Code Assist, and more
- **CI/CD Templates** - Self-healing pipeline, keep-warm, and connectivity check workflows
- **Deployment Configs** - Templates for Vercel, Railway, and Render
- **Issue Templates** - Bug reports, feature requests, and agent initialization
- **Pre-commit Hooks** - Template for linting, secret detection, and commit standards
- **ADR Templates** - Architecture Decision Record templates with examples
- **Verification Scripts** - Built-in testing (see `./test.sh` output for current check count) to ensure template integrity
- **Backlog-Ready Issue Pipeline** - `.context/backlog.yaml` is a machine-readable task list (validated by `.context/backlog.schema.json`). The backlog is auto-converted into GitHub issues and routed through a gated Copilot assignment workflow with concurrent + daily budgets and a queue. The pipeline relies on state labels (`copilot:ready`, `copilot:in-progress`, `copilot:queued`, `copilot:daily-cap-hit`, `from-backlog`, `needs-human`) which `scripts/setup.sh` creates automatically. See [`docs/guides/agent-pipeline.md`](docs/guides/agent-pipeline.md) for the intended end-to-end flow.

## Repository reference (for agents)

The full directory tree, the agent-file catalog, the context-pack catalog, the prompts catalog, the issue-template catalog, the deployment-config catalog, the development-tools catalog, and the CI/CD-workflow catalog all live in [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md) — the structured reference optimized for AI agents.

Why split? Per [`docs/decisions/adr-022-top-level-md-scope-split.md`](docs/decisions/adr-022-top-level-md-scope-split.md), `README.md` (this file) is for human onboarding; [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md) is for agent reference; [`AGENTS.md`](AGENTS.md) is the thin contract every AI tool reads first. The Repo map above is the human-oriented summary; [`AI_REPO_GUIDE.md` § Repository Structure](AI_REPO_GUIDE.md#repository-structure) has the full ASCII tree.

## Included VS Code Extensions

| Extension | Description |
|-----------|-------------|
| [Cline](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev) | AI coding assistant |
| [Live Preview](https://marketplace.visualstudio.com/items?itemName=ms-vscode.live-server) | Live server for web development |
| [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) | Code formatter |
| [Live Share](https://marketplace.visualstudio.com/items?itemName=ms-vsliveshare.vsliveshare) | Real-time collaborative development |

## CI/CD Workflows

The full workflow catalog (~17 entries with required secrets and customization notes) lives in [`AI_REPO_GUIDE.md` § CI/CD Workflows](AI_REPO_GUIDE.md#cicd-workflows). At a glance: `ci-tests.yml` runs build/lint/test, `claude.yml` powers `@claude` triggers, the `agent-*` family handles autonomous Copilot dispatch and review, and `auto-rebase-on-merge.yml` keeps parallel branches current. Most workflows require `CLAUDE_PAT` or `ANTHROPIC_API_KEY` secrets — see the table.

## Setup

> Not sure whether to fork or use the template? See [AI_REPO_GUIDE.md § Template vs. Fork](AI_REPO_GUIDE.md#template-vs-fork-choosing-how-to-start) for guidance.

### Option 1: Link as your Codespaces "Dotfiles" repo

> Note: GitHub Codespaces has a feature literally named **Dotfiles** that runs
> an install script at Codespace startup. This template is not a Unix dotfiles
> repo (no `~/.bashrc` etc.) — it just uses that Codespaces hook to bootstrap
> the multi-agent kit. The quoted strings below are the exact labels in the
> GitHub Codespaces settings UI.

1. Go to [GitHub Codespaces settings](https://github.com/settings/codespaces)
2. Under "Dotfiles", select this repository
3. Check "Automatically install dotfiles"
4. Your next Codespace will automatically run `install.sh`

### Option 2: Create Repository from Template

1. Click "Use this template" on GitHub
2. Create your new repository
3. Run `.github/prompts/repo-onboarding.md`
4. In Mode B, restore `.context/00_INDEX.md`, `.context/roadmap.md`, and `.context/vision/README.md` from the prompt's canonical stubs, delete `.context/vision/architecture/multi-agent-flow.md` and `.context/vision/architecture/state-surfaces.md`, then repopulate the resettable `.context` files with project-specific content
5. Replace remaining `TEMPLATE_PLACEHOLDER` and `PLEASE_UPDATE_THIS/URL` values and customize `ci-tests.yml` for your tech stack

### Option 3: Copy to Existing Repository

1. Clone this repository
2. Copy desired files to your project
3. Create an `AI_REPO_GUIDE.md` specific to your project
4. Customize `.context/` for your project state

## Onboarding prompts (for AI agents)

Two agent-facing prompts — the **first-time repo initialization** prompt to bootstrap a new project from this template, and the **per-session onboarding** prompt to continue work on an existing repo — live in [`AI_REPO_GUIDE.md` § Onboarding Prompts](AI_REPO_GUIDE.md#onboarding-prompts). After creating a repo from this template, paste the first-time-init prompt into a GitHub issue and assign it to your AI agent.

## Verification

Run the verification script to ensure all template files are present and valid:

```bash
./test.sh
```

Expected output:

```text
========================================
Template Repository Verification
========================================

Checking required files...
✓ AI_REPO_GUIDE.md exists
✓ AGENTS.md exists
...

========================================
Summary
========================================
Passed: 74
Warnings: 0
Failed: 0

Template verification PASSED
```

## Testing Your Setup

### Manual Verification

```bash
# Check all files exist
ls -la AI_REPO_GUIDE.md AGENTS.md install.sh test.sh

# Validate shell script syntax
bash -n install.sh
bash -n test.sh

# Run the test suite
./test.sh

# Test install script (safe to run locally)
bash install.sh
```

### In a Codespace

1. Create a new Codespace with this repo linked as your Codespaces "Dotfiles" repo
2. Check that extensions are installed: `code --list-extensions`
3. Verify prompts are copied to workspace

## Customization

### Adding Extensions

Edit `install.sh` to add more extensions:

```bash
EXTENSIONS=(
    "your.extension-id"
    # ... existing extensions
)
```

### Adding Prompts

1. Create new prompt files in `.github/prompts/`
2. Update `install.sh` to copy them if needed
3. Update `test.sh` to verify them

### Platform-Specific Files

- **Cursor**: Add files to `.cursor/`
- **Gemini**: Add files to `.gemini/`
- **GitHub Copilot**: Add files to `.github/agents/` or `.github/prompts/`

## Best Practices

When using this template in a new repository:

1. **Start with `.github/prompts/repo-onboarding.md`** - It is the canonical Mode B reset workflow and stub source for the resettable `.context` files
2. **Repopulate `.context/00_INDEX.md`, `.context/roadmap.md`, and `.context/vision/README.md`** - Replace the canonical stubs with project-specific purpose, plan, and design context before regenerating `AI_REPO_GUIDE.md`
3. **Create domain rules** - Add constraints to `.context/rules/`
4. **Start with mockups** - Add design artifacts to `.context/vision/` before coding
5. **Use GitHub live state** - Keep issue/PR `agent-state:v1` comments current for cognitive handoff between sessions
6. **Keep AGENTS.md as the canonical agent instructions** - Per [`docs/decisions/adr-002-agents-md-ownership.md`](docs/decisions/adr-002-agents-md-ownership.md), AGENTS.md is read by most AI tools (Copilot, Cursor, Gemini, Claude Code via `CLAUDE.md`) and references `AI_REPO_GUIDE.md` for structured detail. Edit it directly when agent-facing rules change; do not strip it down to a pointer.
7. **Customize CI pipeline** - Update `ci-tests.yml` for your tech stack
8. **Run tests** - Use `./test.sh` to verify your customizations

## Limitations

Known constraints of this template. Agent-facing detail (environment variables, tool-specific path rules, workflow placeholders) lives in [`AI_REPO_GUIDE.md` § Gotchas / Known Issues](AI_REPO_GUIDE.md#gotchas--known-issues).

- **Opinionated scaffolding.** The 10-role multi-agent model, `.context/` lazy-loading pattern, and dual agent registries (`.github/agents/` + `.claude/agents/`) reflect specific design choices recorded in `docs/decisions/`. Forks that disagree should strip rather than bend.
- **No runtime code.** This is a docs/config template, not a language-specific starter. Your project brings its own build, test, and deploy toolchain; `ci-tests.yml` ships with placeholder commands you must replace.
- **Codespaces-centric bootstrap.** `install.sh` is wired to the GitHub Codespaces "Dotfiles" feature (via the `$DOTFILES` env var). It falls back to its own directory elsewhere, but some convenience features (extension install, prompt copy) assume a Codespace.
- **Template placeholders are text, not schema.** The `TEMPLATE_PLACEHOLDER` marker is grep-discoverable but not validated for correctness. Running `scripts/verify-env.sh` lists them; the agent still has to make the judgement call on replacement content.

## Future Improvements

Template-level items under consideration. Per-decision follow-ups live in the "Future Work" subsection of each ADR under `docs/decisions/`.

- **Automate `.claude/agents/` generation from `.github/agents/`.** Current sync is manual; `test.sh` only verifies the `description:` line matches. See [`docs/decisions/adr-003-claude-code-subagent-registration.md`](docs/decisions/adr-003-claude-code-subagent-registration.md) § Future Work.
- **Stricter placeholder scanning in CI.** Move `TEMPLATE_PLACEHOLDER` detection from an ad-hoc script into a required CI check so derived projects cannot merge partial customizations.
- **Nested auto-handoff validation for subagent chaining.** Exercise `architect → pm → implementer → judge` end-to-end in CI to prevent role-boundary regressions.
- **More deployment templates.** Cloudflare Workers, Fly.io, and Kubernetes manifests are candidates. Each addition is a maintenance commitment — contribute only if you'll maintain it.
- **First-class dotfiles separation.** Splitting the repo into "template assets" and "Codespaces bootstrap" would let teams adopt one without the other.

## FAQ

Answers to common questions about using this template — why the multiple agent files exist, how to tell template vs derived project, whether you need all the deployment configs, and more. See [`docs/FAQ.md`](docs/FAQ.md).

## License

MIT - Feel free to fork and customize for your own workflow!
