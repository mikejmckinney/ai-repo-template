<!-- TEMPLATE_PLACEHOLDER: This file must be regenerated for the actual project repo. -->
<!-- Run .github/prompts/repo-onboarding.md to rebuild this guide from real repo assets. -->

# AI_REPO_GUIDE.md

> **Purpose**: Canonical reference for AI agents working with this template repository.  
> **Last verified**: 2025-01-25
>
> **Note**: This file is for agents. For human documentation, see `README.md`.

## Overview

This is a **dotfiles template repository** for GitHub Codespaces and AI-assisted development. It provides:
- Pre-configured AI agent prompts for onboarding and code review
- Context management structure for LLM memory across sessions
- Automatic VS Code extension installation on Codespace startup
- CI/CD workflow templates for self-healing pipelines
- Standardized files that can be copied to new repositories

## Quick Start

```bash
# Verify template files
./test.sh

# Manual install simulation (for testing)
bash install.sh
```

## Repository Structure

```
/
├── AI_REPO_GUIDE.md          # This file - canonical AI reference
├── AGENTS.md                 # Root agent instructions (always read first)
├── AGENT.md                  # Deprecated redirect to AGENTS.md
├── CLAUDE.md                 # Claude Code native memory pointer to AGENTS.md
├── README.md                 # User-facing documentation
├── install.sh                # Codespace bootstrap script
├── test.sh                   # Verification script
│
├── .context/                 # Project context (canonical truth)
│   ├── 00_INDEX.md           # Context entry point
│   ├── roadmap.md            # Phase-by-phase plan
│   ├── rules/                # Immutable domain constraints
│   ├── state/                # Task tracking (supports parallel work)
│   │   ├── _active.md        # Points to current priority task
│   │   └── task_*.md         # Individual task files
│   └── vision/               # Design artifacts
│       ├── mockups/          # UI/UX mockups
│       └── architecture/     # System diagrams
│
├── docs/                     # Human reference documentation
│   ├── README.md             # Documentation index
│   ├── reference/            # Specs, research, external docs
│   ├── guides/               # How-to guides
│   └── decisions/            # Architecture Decision Records
│
├── .cursor/
│   └── BUGBOT.md             # Cursor Bugbot PR review rules
├── .gemini/
│   └── styleguide.md         # Gemini Code Assist review style
└── .github/
    ├── copilot-instructions.md   # GitHub Copilot instructions (auto-read)
    ├── agents/
    │   └── judge.agent.md        # Plan-gate + diff-gate reviewer agent
    ├── prompts/
    │   ├── copilot-onboarding.md # Guide for customizing copilot-instructions.md
    │   └── repo-onboarding.md    # Comprehensive repo onboarding prompt
    └── workflows/
        ├── auto-resolve-on-merge.yml  # Auto-resolve PR comments on merge
        ├── ci-tests.yml               # CI pipeline template (customize)
        ├── keep-warm.yml              # Ping backend to prevent suspension
        └── validate-connections.yml   # Daily connectivity checks
```

## Key Files by Purpose

### Agent Instructions (read by AI assistants automatically)
| File | Tool/Platform | Purpose |
|------|--------------|---------|
| `AGENTS.md` | Most AI tools | Root instructions, points to this file |
| `CLAUDE.md` | Claude Code | Native memory-file pointer to AGENTS.md |
| `.github/copilot-instructions.md` | GitHub Copilot | Copilot-specific instructions |
| `.cursor/BUGBOT.md` | Cursor Bugbot | PR review rules |
| `.gemini/styleguide.md` | Gemini Code Assist | PR review style guide |
| `.github/agents/judge.agent.md` | Multi-tool | Procedural plan/diff gate reviewer (no code) |
| `.github/agents/critic.agent.md` | Multi-tool | Devil's Advocate — subjective quality review (no code) |
| `.github/agents/architect.agent.md` | Multi-tool | Plan + ADR author (no code) |
| `.github/agents/pm.agent.md` | Multi-tool | Task dispatcher + ownership enforcer (no code) |
| `.github/agents/frontend.agent.md` | Multi-tool | UI layer implementer |
| `.github/agents/backend.agent.md` | Multi-tool | Server layer implementer |
| `.github/agents/qa.agent.md` | Multi-tool | Test author + CI gate |
| `.github/agents/devops.agent.md` | Multi-tool | Workflows, configs, install scripts |
| `.github/agents/docs.agent.md` | Multi-tool | README, AI_REPO_GUIDE.md, guides |

### Context Pack (project memory)
| File | Purpose |
|------|---------|
| `.context/00_INDEX.md` | Entry point, project summary |
| `.context/roadmap.md` | Phase-by-phase plan |
| `.context/rules/` | Domain constraints (never violate) |
| `.context/rules/agent_ownership.md` | Canonical role → owned paths map for multi-agent work |
| `.context/rules/domain_code_quality.md` | Built-in language-neutral SOLID/TDD/clean-code floor |
| `.context/state/coordination.md` | Live claim board for parallel multi-agent work |
| `.context/state/task_*.md` | Current task(s) for session handoff |
| `.context/vision/` | Mockups and architecture diagrams |

### Prompts (user-triggered, not auto-loaded)
| File | Purpose |
|------|---------|
| `.github/prompts/copilot-onboarding.md` | Guide for customizing copilot-instructions.md |
| `.github/prompts/repo-onboarding.md` | Comprehensive repo onboarding workflow |

### Setup Scripts
| File | Purpose |
|------|---------|
| `install.sh` | Runs on Codespace start; installs extensions, copies prompts |
| `test.sh` | Verifies template integrity (58 checks) |

### Issue Templates
| File | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/bug_report.md` | Structured bug reports |
| `.github/ISSUE_TEMPLATE/feature_request.md` | Feature requests with acceptance criteria |
| `.github/ISSUE_TEMPLATE/agent_init.md` | Initialize repo from template |

### Deployment Configs
| File | Platform | Purpose |
|------|----------|---------|
| `config/vercel.json.template` | Vercel | Frontend, serverless |
| `config/railway.toml.template` | Railway | Backend services |
| `config/render.yaml.template` | Render | Full-stack blueprint |

### Development Tools
| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml.template` | Pre-commit hooks (linting, secrets) |
| `docs/decisions/adr-template.md` | Architecture Decision Record template |
| `docs/guides/agent-best-practices.md` | Token limits, session handoff, secrets |
| `docs/guides/multi-agent-coordination.md` | Parallel role-based workflow (Architect/FE/BE/PM/QA/DevOps/Docs/Judge/Critic) |
| `docs/guides/optional-skills.md` | Optional external Claude Code skills (SOLID, everything-claude-code) |
| `.github/workflows/agent-heartbeat.yml.template` | Optional scheduled workflow to surface stale locks / stuck tasks |

### CI/CD Workflows
| File | Purpose |
|------|---------|
| `ci-tests.yml` | Build, lint, test pipeline (customize for project) |
| `keep-warm.yml` | Prevents free-tier backend suspension |
| `validate-connections.yml` | Daily backend/DB connectivity check |
| `auto-resolve-on-merge.yml` | Resolves PR threads on merge |

## Truth Hierarchy

When information conflicts, use this priority:
1. **`.context/**`** — canonical project direction and constraints
2. **`docs/**`** — supporting reference material
3. **Codebase** — current implementation reality

## Conventions

### File Naming
- Agent instruction files: `AGENTS.md`, `*.agent.md`, or tool-specific paths
- Prompts: `*.prompt.md` or in `.github/prompts/`
- Style guides: `styleguide.md` in tool-specific directories
- Context files: Use clear names, prefer `.md` extension

### Content Guidelines
- Keep instructions concise (aim for < 2 pages per file)
- Include verification commands where applicable
- Use structured output formats (checklists, tables)
- Reference this file (`AI_REPO_GUIDE.md`) for canonical commands

### Testing Requirements
- Follow test pyramid: many unit tests, fewer integration tests, minimal E2E
- Write tests before or alongside implementation (TDD preferred)
- All behavioral changes must include tests
- CI must pass before tasks are marked complete

## Verification Commands

```bash
# Check all required files exist (58 checks)
./test.sh

# Validate shell scripts (if shellcheck installed)
shellcheck install.sh test.sh

# List all markdown files
find . -name "*.md" -not -path "./.git/*" | head -20

# Verify context pack structure
ls -la .context/

# Verify config templates
ls -la config/
```

## Using This Template

### For new repositories
1. Create repo from this template (or copy files)
2. Replace all files containing `TEMPLATE_PLACEHOLDER`
3. Fill in `.context/00_INDEX.md` with project details
4. Define roadmap in `.context/roadmap.md`
5. Customize `ci-tests.yml` for your tech stack

### For Codespaces
1. Link this repo in GitHub Codespaces settings
2. Extensions install automatically via `install.sh`
3. AI prompts copied to workspace

### First-time repo initialization
See the "Easiest way to initialize new repo" prompt in the main README or create an issue with instructions for the agent.

## Gotchas / Known Issues

- `install.sh` requires the `$DOTFILES` environment variable (set automatically by GitHub Codespaces)
- The `code` command may not be available outside of VS Code/Codespaces environments
- Some AI tools only read files from specific paths (see tool documentation)
- Workflow files (`.github/workflows/`) contain `TEMPLATE_PLACEHOLDER` and must be customized

## Updating This Guide

When making changes to this template:
1. Update this file if structure/commands/conventions change
2. Run `./test.sh` to verify integrity
3. Update README.md if user-facing behavior changes
4. Update `.context/` files if project direction changes
