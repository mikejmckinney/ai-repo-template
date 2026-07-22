# AI-Ready Repository Template

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
| `docs/` | Humans | Deep reference: guides, ADRs, benchmark results, research |
| `.context/` | AI agents | Project direction, roadmap, retrospective lessons, and vision (lazy-loaded) |
| `AGENTS.md` (root) | Most AI tools | Root startup contract (Copilot, Cursor, Gemini, Claude Code, etc.) |
| `.github/prompts/` | Review and workflow automation | Shared lenses plus advisory, daily, and weekly prompts |
| `.agents/skills/multi-model-consensus/` | Cross-agent | Optional independent multi-model review |
| `install.sh` (root) | GitHub Codespaces "Dotfiles" | Bootstrap script — Codespaces expects it at repo root |
| `test.sh` (root) | `.github/workflows/ci-tests.yml` | Template verification, invoked by CI as `./test.sh` |
| `scripts/` | Project consumers (post-clone) | One-time project customization (`setup.sh`, `verify-env.sh`) |

ADR-031 defines the active model: one implementing agent, blocking CI, normal parallel advisory review, recurring retro, and opt-in multi-model consensus.

**Why not consolidate?** `docs/` vs `.context/` and `README.md` vs `AI_REPO_GUIDE.md` were explicitly evaluated and rejected in `docs/decisions/adr-001-context-pack-structure.md` — different audiences and a truth hierarchy. `install.sh`/`test.sh` cannot move to `scripts/` without breaking the Codespaces Dotfiles convention and the CI workflow.

## Features

- **AI Agent Prompts** - Pre-configured prompts for onboarding AI assistants to any codebase
- **Monolithic Agent Workflow** - One implementing agent with normal parallel advisory feedback and recurring retro automation
- **Context Pack** - Structured directory (`.context/`) for project memory across LLM sessions
- **Automatic Extension Installation** - Essential VS Code extensions installed on Codespace start
- **Multi-Platform Support** - Works with Cursor, GitHub Copilot, Gemini Code Assist, and more
- **CI/CD Automation** - Blocking tests and lint with label-gated parallel advisory and recurring repository review
- **Issue Templates** - Bug reports, feature requests, and agent initialization
- **Explicit Quality Checks** - Read-only CI plus local formatting, lint, link, and repository verification commands
- **ADR Templates** - Architecture Decision Record templates with examples
- **Verification Scripts** - Built-in testing (see `./test.sh` output for current check count) to ensure template integrity

## Repository reference (for agents)

The active repository layout, context-pack catalog, prompt catalog, workflow catalog,
and validation commands live in [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md), the
structured reference optimized for AI agents.

Why split? Per [`docs/decisions/adr-022-top-level-md-scope-split.md`](docs/decisions/adr-022-top-level-md-scope-split.md), `README.md` (this file) is for human onboarding; [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md) is for agent reference; and [`AGENTS.md`](AGENTS.md) is the operating contract every AI tool reads first.

## Included VS Code Extensions

| Extension | Description |
|-----------|-------------|
| [Cline](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev) | AI coding assistant |
| [Live Preview](https://marketplace.visualstudio.com/items?itemName=ms-vscode.live-server) | Live server for web development |
| [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) | Code formatter |
| [Live Share](https://marketplace.visualstudio.com/items?itemName=ms-vsliveshare.vsliveshare) | Real-time collaborative development |

## CI/CD Workflows

The active workflow map lives in [`AI_REPO_GUIDE.md`](AI_REPO_GUIDE.md). At a
glance, CI and lint block merge; Copilot assignment remains monolithic;
agents normally enable parallel advisory review with `ai-review:live`; scheduled daily
and weekly workflows perform retrospective review and draft-fix work.

## Setup

Choose the Codespaces hook, GitHub template, or selective-copy path according to
how much of the repository kit the target project should inherit.

### Option 1: Link as your Codespaces "Dotfiles" repo

> Note: GitHub Codespaces has a feature literally named **Dotfiles** that runs
> an install script at Codespace startup. This template is not a Unix dotfiles
> repo (no `~/.bashrc` etc.) — it just uses that Codespaces hook to bootstrap
> the repository kit. The quoted strings below are the exact labels in the
> GitHub Codespaces settings UI.

1. Go to [GitHub Codespaces settings](https://github.com/settings/codespaces)
2. Under "Dotfiles", select this repository
3. Check "Automatically install dotfiles"
4. Your next Codespace will automatically run `install.sh`

### Option 2: Create Repository from Template

1. Click "Use this template" on GitHub
2. Create your new repository
3. Run the OpenCode `repo-onboarding` skill
4. In `template-seed`, inspect the existing resources and extend, replace, or delete only what project evidence requires
5. Complete `.context/onboarding-state.json` and add application checks only when the detected stack defines them

### Option 3: Copy to Existing Repository

1. Clone this repository
2. Copy desired files to your project
3. Create an `AI_REPO_GUIDE.md` specific to your project
4. Customize `.context/` for your project state

## Repository onboarding

Use the OpenCode `repo-onboarding` skill for unfamiliar-repository orientation,
`template-seed` onboarding, or rebuilding a missing/stale `AI_REPO_GUIDE.md`.
Its modes are `ai-repo-template`, `template-seed`, and `complete`. Use the Agent
Initialization issue template when the work needs a durable issue contract.

## Verification

Run the verification script to ensure all template files are present and valid:

```bash
./test.sh
```

The exact pass count changes as checks are added. A successful run ends with:

```text
========================================
Template Repository Verification
========================================

Summary
========================================
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

### Review Automation

- Apply `ai-review:live` to every eligible same-repository task PR and use arrived current-head feedback without waiting for it.
- Daily and weekly workflows review merged work and repository health.
- Use the OpenCode `multi-model-consensus` skill only for consequential uncertainty.

## Best Practices

When using this template in a new repository:

1. **Start with the OpenCode `repo-onboarding` skill** - it classifies lifecycle state, preserves useful resources, and updates project context only where evidence requires it
2. **Customize the operating contract** - Add project-wide constraints to `AGENTS.md`
3. **Design before frontend implementation** - For verified UI work, generate
   `DESIGN.md` with the onboarding helper and add design artifacts to
   `.context/vision/`; non-UI repositories do not need a root design contract
4. **Use GitHub live state** - Keep issue/PR `agent-state:v1` comments current for cognitive handoff between sessions
5. **Keep AGENTS.md as the canonical agent instructions** - Per [`docs/decisions/adr-002-agents-md-ownership.md`](docs/decisions/adr-002-agents-md-ownership.md), `AGENTS.md` is read by most AI tools (Copilot, Cursor, Gemini, Claude Code) and references `AI_REPO_GUIDE.md` for structured detail. Edit it directly when agent-facing rules change; do not strip it down to a pointer.
6. **Extend CI from evidence** - Add application checks only for commands the
   detected stack actually defines
7. **Run tests** - Use `./test.sh` to verify your customizations

## Limitations

Known constraints of this template. Agent-facing environment and tool warnings
live in [`AI_REPO_GUIDE.md` § Known Warnings](AI_REPO_GUIDE.md#known-warnings).

- **Opinionated scaffolding.** The monolithic workflow, `.context/` lazy-loading pattern, and review lifecycle reflect decisions recorded in `docs/decisions/`.
- **No runtime code.** This is a docs/config template, not a language-specific starter. Your project brings its own build, test, and deploy toolchain; onboarding adds application checks only from verified project commands.
- **Codespaces-centric bootstrap.** `install.sh` is wired to the GitHub Codespaces "Dotfiles" feature (via the `$DOTFILES` env var). It falls back to its own directory elsewhere, but some convenience features (extension install, prompt copy) assume a Codespace.
- **Lifecycle state is explicit.** `.context/onboarding-state.json` distinguishes a fresh template seed from a completed derived repository; retained template resources are not treated as defects.

## Future Improvements

Template-level items under consideration. Per-decision follow-ups live in the "Future Work" subsection of each ADR under `docs/decisions/`.

- **More deployment templates.** Cloudflare Workers, Fly.io, and Kubernetes manifests are candidates. Each addition is a maintenance commitment — contribute only if you'll maintain it.
- **First-class dotfiles separation.** Splitting the repo into "template assets" and "Codespaces bootstrap" would let teams adopt one without the other.

## FAQ

Answers to common questions about using this template, derived-project detection, and deployment configs live in [`docs/FAQ.md`](docs/FAQ.md).

## License

MIT - Feel free to fork and customize for your own workflow!
