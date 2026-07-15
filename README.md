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
| `AGENTS.md` (root) | Most AI tools | Root startup contract (Copilot, Cursor, Gemini, Claude Code, etc.) |
| `.github/prompts/` | Review and workflow automation | Shared lenses plus advisory, daily, and weekly prompts |
| `.opencode/skills/local-consensus/` | OpenCode | Optional independent multi-model review |
| `install.sh` (root) | GitHub Codespaces "Dotfiles" | Bootstrap script — Codespaces expects it at repo root |
| `test.sh` (root) | `.github/workflows/ci-tests.yml` | Template verification, invoked by CI as `./test.sh` |
| `scripts/` | Project consumers (post-clone) | One-time project customization (`setup.sh`, `verify-env.sh`) |

ADR-031 defines the active model: one implementing agent, blocking CI, optional parallel advisory review, recurring retro, and opt-in local consensus.

**Why not consolidate?** `docs/` vs `.context/` and `README.md` vs `AI_REPO_GUIDE.md` were explicitly evaluated and rejected in `docs/decisions/adr-001-context-pack-structure.md` — different audiences and a truth hierarchy. `install.sh`/`test.sh` cannot move to `scripts/` without breaking the Codespaces Dotfiles convention and the CI workflow.

## Features

- **AI Agent Prompts** - Pre-configured prompts for onboarding AI assistants to any codebase
- **Monolithic Agent Workflow** - One implementing agent with optional parallel advisory feedback and recurring retro automation
- **Context Pack** - Structured directory (`.context/`) for project memory across LLM sessions
- **Automatic Extension Installation** - Essential VS Code extensions installed on Codespace start
- **Multi-Platform Support** - Works with Cursor, GitHub Copilot, Gemini Code Assist, and more
- **CI/CD Automation** - Blocking tests and lint with opt-in advisory and recurring repository review
- **Issue Templates** - Bug reports, feature requests, and agent initialization
- **Pre-commit Hooks** - Template for linting, secret detection, and commit standards
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
`ai-review:live` enables optional parallel advisory review; and scheduled daily
and weekly workflows perform retrospective review and draft-fix work.

## Setup

> Not sure whether to fork or use the template? See [AI_REPO_GUIDE.md § Template vs. Fork](AI_REPO_GUIDE.md#template-vs-fork-choosing-how-to-start) for guidance.

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
4. In Mode B, follow the skill's bootstrap procedure to reset and repopulate `.context/00_INDEX.md`, `.context/roadmap.md`, `.context/vision/README.md`, and `DESIGN.md`, delete template-only architecture diagrams, then customize with project-specific content
5. Replace remaining `TEMPLATE_PLACEHOLDER` and `PLEASE_UPDATE_THIS/URL` values and customize `ci-tests.yml` for your tech stack

### Option 3: Copy to Existing Repository

1. Clone this repository
2. Copy desired files to your project
3. Create an `AI_REPO_GUIDE.md` specific to your project
4. Customize `.context/` for your project state

## Repository onboarding

Use the OpenCode `repo-onboarding` skill for first-clone orientation, Mode B
template bootstrap, or rebuilding `AI_REPO_GUIDE.md`. Use the Agent
Initialization issue template when the work needs a durable issue contract.

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

### Review Automation

- Add `ai-review:live` when optional advisory feedback is useful during implementation.
- Daily and weekly workflows review merged work and repository health.
- Use the OpenCode `local-consensus` skill only for consequential uncertainty.

## Best Practices

When using this template in a new repository:

1. **Start with the OpenCode `repo-onboarding` skill** - it repopulates `.context/00_INDEX.md`, `.context/roadmap.md`, `.context/vision/README.md`, and other project context before regenerating `AI_REPO_GUIDE.md`
2. **Customize the operating contract** - Add project-wide constraints to `AGENTS.md`
3. **Start with mockups** - Add design artifacts to `.context/vision/` before coding
4. **Use GitHub live state** - Keep issue/PR `agent-state:v1` comments current for cognitive handoff between sessions
5. **Keep AGENTS.md as the canonical agent instructions** - Per [`docs/decisions/adr-002-agents-md-ownership.md`](docs/decisions/adr-002-agents-md-ownership.md), `AGENTS.md` is read by most AI tools (Copilot, Cursor, Gemini, Claude Code) and references `AI_REPO_GUIDE.md` for structured detail. Edit it directly when agent-facing rules change; do not strip it down to a pointer.
6. **Customize CI pipeline** - Update `ci-tests.yml` for your tech stack
7. **Run tests** - Use `./test.sh` to verify your customizations

## Limitations

Known constraints of this template. Agent-facing detail (environment variables, tool-specific path rules, workflow placeholders) lives in [`AI_REPO_GUIDE.md` § Gotchas / Known Issues](AI_REPO_GUIDE.md#gotchas--known-issues).

- **Opinionated scaffolding.** The monolithic workflow, `.context/` lazy-loading pattern, and review lifecycle reflect decisions recorded in `docs/decisions/`.
- **No runtime code.** This is a docs/config template, not a language-specific starter. Your project brings its own build, test, and deploy toolchain; `ci-tests.yml` ships with placeholder commands you must replace.
- **Codespaces-centric bootstrap.** `install.sh` is wired to the GitHub Codespaces "Dotfiles" feature (via the `$DOTFILES` env var). It falls back to its own directory elsewhere, but some convenience features (extension install, prompt copy) assume a Codespace.
- **Template placeholders are text, not schema.** The `TEMPLATE_PLACEHOLDER` marker is grep-discoverable but not validated for correctness. Running `scripts/verify-env.sh` lists them; the agent still has to make the judgement call on replacement content.

## Future Improvements

Template-level items under consideration. Per-decision follow-ups live in the "Future Work" subsection of each ADR under `docs/decisions/`.

- **Stricter placeholder scanning in CI.** Move `TEMPLATE_PLACEHOLDER` detection from an ad-hoc script into a required CI check so derived projects cannot merge partial customizations.
- **More deployment templates.** Cloudflare Workers, Fly.io, and Kubernetes manifests are candidates. Each addition is a maintenance commitment — contribute only if you'll maintain it.
- **First-class dotfiles separation.** Splitting the repo into "template assets" and "Codespaces bootstrap" would let teams adopt one without the other.

## FAQ

Answers to common questions about using this template, derived-project detection, and deployment configs live in [`docs/FAQ.md`](docs/FAQ.md).

## License

MIT - Feel free to fork and customize for your own workflow!
