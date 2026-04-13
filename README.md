<!-- TEMPLATE_PLACEHOLDER: GENERATED FROM mikejmckinney/dotfiles. -->
<!-- THIS REPO IS NOT THE TEMPLATE ITSELF. Replace this README for the actual project. -->

# AI-Ready Repository Template

<!-- Agent Status Badge - Update phase as project progresses -->
<!-- Options: Phase 0: Design | Phase 1: Foundation | Phase 2: Development | Phase 3: Polish | Phase 4: Maintenance -->
![Agent Status](https://img.shields.io/badge/Agent%20Status-Phase%200%3A%20Design-blue)
![Last Updated](https://img.shields.io/badge/Last%20Updated-January%202025-green)

A template repository for GitHub Codespaces that provides pre-configured AI agent prompts, context management for LLM memory, and automatic development environment setup. Use this as a starting point for new repositories or link it to your Codespaces settings.

> **For AI Agents**: See `AI_REPO_GUIDE.md` for a concise reference optimized for agent consumption.

## Features

- **AI Agent Prompts** - Pre-configured prompts for onboarding AI assistants to any codebase
- **Multi-Agent Roles** - Role-specialized agent files (Architect, Frontend, Backend, PM, QA, DevOps, Docs, Judge) with an ownership map so multiple agents can work in parallel without code conflicts
- **Context Pack** - Structured directory (`.context/`) for project memory across LLM sessions
- **Automatic Extension Installation** - Essential VS Code extensions installed on Codespace start
- **Multi-Platform Support** - Works with Cursor, GitHub Copilot, Gemini Code Assist, and more
- **CI/CD Templates** - Self-healing pipeline, keep-warm, and connectivity check workflows
- **Deployment Configs** - Templates for Vercel, Railway, and Render
- **Issue Templates** - Bug reports, feature requests, and agent initialization
- **Pre-commit Hooks** - Template for linting, secret detection, and commit standards
- **ADR Templates** - Architecture Decision Record templates with examples
- **Verification Scripts** - Built-in testing (58 checks) to ensure template integrity

## Repository Structure

```
/
├── AI_REPO_GUIDE.md              # Canonical AI reference (create in target repos)
├── AGENTS.md                     # Root agent instructions
├── AGENT.md                      # Deprecated redirect
├── CLAUDE.md                     # Claude Code native memory pointer to AGENTS.md
├── README.md                     # This file
├── install.sh                    # Codespace bootstrap script
├── test.sh                       # Template verification script
│
├── .context/                     # Project context (canonical truth)
│   ├── 00_INDEX.md               # Context entry point
│   ├── roadmap.md                # Phase-by-phase plan
│   ├── rules/                    # Immutable domain constraints
│   ├── state/                    # Mutable progress tracking
│   │   ├── _active.md            # Points to current priority task
│   │   └── task_*.md             # Individual task files
│   └── vision/                   # Design artifacts
│       ├── mockups/              # UI/UX mockups
│       └── architecture/         # System diagrams
│
├── docs/                         # Human reference documentation
│   ├── README.md                 # Documentation guide
│   ├── reference/                # Specs, research
│   ├── guides/                   # How-to guides
│   └── decisions/                # Architecture Decision Records
│
├── .cursor/
│   └── BUGBOT.md                 # Cursor Bugbot PR review rules
│
├── .gemini/
│   └── styleguide.md             # Gemini Code Assist style guide
│
├── config/                       # Deployment config templates
│   ├── README.md                 # Platform recommendations
│   ├── vercel.json.template      # Vercel frontend config
│   ├── railway.toml.template     # Railway backend config
│   └── render.yaml.template      # Render blueprint config
│
├── .pre-commit-config.yaml.template  # Pre-commit hooks template
│
└── .github/
    ├── copilot-instructions.md   # GitHub Copilot instructions (auto-read)
    ├── agents/
    │   └── judge.agent.md        # GitHub Copilot plan/diff gate agent
    ├── prompts/
    │   ├── copilot-onboarding.md # Guide for customizing copilot-instructions.md
    │   └── repo-onboarding.md    # Comprehensive repo onboarding prompt
    ├── ISSUE_TEMPLATE/           # Issue templates
    │   ├── bug_report.md         # Bug report template
    │   ├── feature_request.md    # Feature request template
    │   ├── agent_init.md         # Agent initialization task
    │   └── config.yml            # Template chooser config
    └── workflows/
        ├── auto-resolve-on-merge.yml  # Auto-resolve PR comments
        ├── ci-tests.yml               # CI pipeline (customize for project)
        ├── keep-warm.yml              # Ping backend to prevent suspension
        └── validate-connections.yml   # Daily connectivity checks
```

## AI Agent Files

### Agent Instructions (auto-loaded by AI tools)

| File | Platform | Purpose |
|------|----------|---------|
| `AGENTS.md` | Most AI tools | Root instructions, references AI_REPO_GUIDE.md |
| `CLAUDE.md` | Claude Code | Native memory-file pointer to AGENTS.md |
| `.github/copilot-instructions.md` | GitHub Copilot | Copilot-specific instructions |
| `.cursor/BUGBOT.md` | Cursor Bugbot | Strict PR review rules with verification |
| `.gemini/styleguide.md` | Gemini Code Assist | PR review with severity labels |
| `.github/agents/judge.agent.md` | Multi-tool | Procedural plan-gate + diff-gate reviewer |
| `.github/agents/critic.agent.md` | Multi-tool | Devil's Advocate — subjective quality review |
| `.github/agents/architect.agent.md` | Multi-tool | Plan + ADR author (no code) |
| `.github/agents/pm.agent.md` | Multi-tool | Task dispatcher + ownership enforcer (no code) |
| `.github/agents/frontend.agent.md` | Multi-tool | UI layer implementer |
| `.github/agents/backend.agent.md` | Multi-tool | Server layer implementer |
| `.github/agents/qa.agent.md` | Multi-tool | Test author + CI gate |
| `.github/agents/devops.agent.md` | Multi-tool | Workflows, configs, install scripts |
| `.github/agents/docs.agent.md` | Multi-tool | README, AI_REPO_GUIDE.md, guides |

### Context Pack (LLM memory)

| File | Purpose |
|------|---------|
| `.context/00_INDEX.md` | Entry point - project summary and key decisions |
| `.context/roadmap.md` | Phase-by-phase plan with acceptance criteria |
| `.context/rules/` | Immutable constraints (domain rules) |
| `.context/rules/agent_ownership.md` | Canonical role → owned paths map for multi-agent work |
| `.context/state/coordination.md` | Live claim board for parallel multi-agent work |
| `.context/state/task_*.md` | Current task(s) for cognitive handoff |
| `.context/sessions/` | Session history to prevent repeating mistakes |
| `.context/vision/` | Mockups and architecture diagrams |

### Prompts (user-triggered)

| File | Purpose |
|------|---------|
| `.github/prompts/copilot-onboarding.md` | Guide for customizing copilot-instructions.md |
| `.github/prompts/repo-onboarding.md` | Comprehensive onboarding workflow |

### Issue Templates

| File | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/bug_report.md` | Structured bug reports |
| `.github/ISSUE_TEMPLATE/feature_request.md` | Feature requests with acceptance criteria |
| `.github/ISSUE_TEMPLATE/agent_init.md` | Initialize repo from template (agent task) |

### Deployment Configs

| File | Platform | Purpose |
|------|----------|---------|
| `config/vercel.json.template` | Vercel | Frontend, serverless functions |
| `config/railway.toml.template` | Railway | Backend services |
| `config/render.yaml.template` | Render | Full-stack blueprints |

### Development Tools

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml.template` | Pre-commit hooks for linting, secrets, formatting |
| `docs/decisions/adr-template.md` | Template for Architecture Decision Records |
| `docs/guides/multi-agent-coordination.md` | How role-based agents work in parallel without conflicts |
| `docs/guides/optional-skills.md` | Curated optional Claude Code skills (SOLID, everything-claude-code) |
| `.github/workflows/agent-heartbeat.yml.template` | Optional scheduled workflow to surface stale locks / stuck tasks |

## Included VS Code Extensions

| Extension | Description |
|-----------|-------------|
| [Cline](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev) | AI coding assistant |
| [Live Preview](https://marketplace.visualstudio.com/items?itemName=ms-vscode.live-server) | Live server for web development |
| [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) | Code formatter |
| [Live Share](https://marketplace.visualstudio.com/items?itemName=ms-vsliveshare.vsliveshare) | Real-time collaborative development |

## CI/CD Workflows

| Workflow | Purpose | Customization Required |
|----------|---------|------------------------|
| `ci-tests.yml` | Build, lint, test on push/PR | Yes - add your commands |
| `keep-warm.yml` | Ping backend every 14 min | Set `BACKEND_URL` secret |
| `validate-connections.yml` | Daily connectivity check | Set `BACKEND_URL` secret |
| `auto-resolve-on-merge.yml` | Resolve threads on merge | None |

## Setup

### Option 1: Use as Codespaces Dotfiles

1. Go to [GitHub Codespaces settings](https://github.com/settings/codespaces)
2. Under "Dotfiles", select this repository
3. Check "Automatically install dotfiles"
4. Your next Codespace will automatically run `install.sh`

### Option 2: Create Repository from Template

1. Click "Use this template" on GitHub
2. Create your new repository
3. Replace all files containing `TEMPLATE_PLACEHOLDER`
4. Fill in `.context/00_INDEX.md` with your project details
5. Customize `ci-tests.yml` for your tech stack

### Option 3: Copy to Existing Repository

1. Clone this repository
2. Copy desired files to your project
3. Create an `AI_REPO_GUIDE.md` specific to your project
4. Customize `.context/` for your project state

## First-Time Repo Initialization

After creating a repo from this template, create an issue with this prompt for the AI agent:

```markdown
This repository was created from a template. Any file containing TEMPLATE_PLACEHOLDER is scaffolding.

Truth hierarchy:
1) ./.context/** (canonical project direction)
2) ./docs/** (supporting detail)
3) codebase (implementation reality)

Please:
1. Verify .context/00_INDEX.md and .github/prompts/*.md exist
2. Scan and list all files containing TEMPLATE_PLACEHOLDER
3. Determine project purpose from .context/**, docs/**, and codebase
4. Run .github/prompts/repo-onboarding.md then copilot-onboarding.md
5. Replace README.md with project-specific content
6. Regenerate AI_REPO_GUIDE.md for THIS repo
7. Do not modify .context/** unless instructed
```

## Onboarding New Agent Sessions

Use this prompt to continue work on an existing repo:

```markdown
1. Read .context/state/_active.md or task_*.md to understand the immediate goal.
2. Read .context/00_INDEX.md to locate relevant rules/constraints.
3. Check: Run `git status` and `./scripts/verify-env.sh` to ensure stability.
4. Skim: Review .context/sessions/latest_summary.md for recent decisions.
5. Report: "I have reviewed the context. Current task is [Task Name]. 
   Environment is [Stable/Unstable]. Ready for instructions."
```

This structured protocol ensures context is loaded correctly before proceeding.

## Verification

Run the verification script to ensure all template files are present and valid:

```bash
./test.sh
```

Expected output:
```
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

1. Create a new Codespace with this as your dotfiles repo
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

1. **Fill in `.context/00_INDEX.md`** - Document your project's purpose and current state
2. **Define roadmap phases** - Use `.context/roadmap.md` to plan work
3. **Create domain rules** - Add constraints to `.context/rules/`
4. **Start with mockups** - Add design artifacts to `.context/vision/` before coding
5. **Create task files** - Use `state/task_*.md` for cognitive handoff between sessions
6. **Keep AGENTS.md minimal** - It should just point to AI_REPO_GUIDE.md
7. **Customize CI pipeline** - Update `ci-tests.yml` for your tech stack
8. **Run tests** - Use `./test.sh` to verify your customizations

## License

MIT - Feel free to fork and customize for your own workflow!
