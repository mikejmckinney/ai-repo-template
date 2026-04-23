<!-- TEMPLATE_PLACEHOLDER: This file must be regenerated for the actual project repo. -->
<!-- Run .github/prompts/repo-onboarding.md to rebuild this guide from real repo assets. -->

# AI_REPO_GUIDE.md

> **Purpose**: Canonical reference for AI agents working with this template repository.  
> **Last verified**: 2025-01-25
>
> **Note**: This file is for agents. For human documentation, see `README.md`.

## Overview

This is the **AI repo template** (`mikejmckinney/ai-repo-template`) for GitHub
Codespaces and AI-assisted development. It plugs into the GitHub Codespaces
"Dotfiles" feature (which runs an install script at Codespace startup) to
bootstrap a multi-agent development kit. It is not a Unix dotfiles repo. It
provides:
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
│   ├── backlog.yaml          # Machine-readable task list (dispatched into issues)
│   ├── backlog.schema.json   # JSON Schema for backlog.yaml
│   ├── roadmap.md            # Phase-by-phase plan
│   ├── rules/                # Immutable domain constraints
│   │   ├── README.md
│   │   ├── agent_ownership.md
│   │   ├── domain_code_quality.md
│   │   └── process_doc_maintenance.md
│   ├── sessions/             # Session history for handoff
│   │   ├── README.md
│   │   └── latest_summary.md
│   ├── state/                # Task tracking (supports parallel work)
│   │   ├── README.md
│   │   ├── _active.md            # Current priority task pointer
│   │   ├── coordination.md       # Live claim board
│   │   ├── feedback_template.md  # Stakeholder feedback template
│   │   ├── handoff_template.md   # Cross-session/role handoff template
│   │   ├── task_template.md      # Template for new tasks
│   │   └── task_*.md             # Individual task files
│   └── vision/               # Design artifacts
│       ├── README.md
│       ├── mockups/          # UI/UX mockups
│       └── architecture/     # System diagrams
│
├── docs/                     # Human reference documentation
│   ├── README.md             # Documentation index
│   ├── FAQ.md                # Common questions
│   ├── smoke-a.md            # Smoke test scenario A
│   ├── smoke-e.md            # Smoke test scenario E
│   ├── decisions/            # Architecture Decision Records (adr-001 … adr-010, adr-template)
│   ├── guides/               # How-to guides (agent-best-practices, agent-pipeline, context-files-explained, multi-agent-coordination, optional-skills)
│   ├── postmortems/          # Postmortems (template + project-specific)
│   ├── reference/            # Specs, external docs
│   └── research/             # Analyst output (analysis artifacts)
│
├── scripts/                  # Bootstrap + verification scripts
│   ├── README.md
│   ├── setup.sh              # First-run project customization
│   ├── verify-env.sh         # Environment & placeholder sanity check
│   ├── db-reset.sh           # Optional DB reset stub
│   ├── auto-rebase-overlapping.sh    # Auto-rebase library (ADR-010)
│   ├── multi-dispatch-safety.sh      # Parallel-dispatch safety classifier
│   ├── parse-ownership-table.sh      # Ownership-table parser used by workflows
│   └── test-*.sh             # Unit tests for the helper scripts above
│
├── config/                   # Deployment config templates (see table below)
│
├── .claude/
│   └── agents/               # Claude Code subagent registry (10 mirrors of .github/agents/, see ADR-003)
├── .cursor/
│   └── BUGBOT.md             # Cursor Bugbot PR review rules
├── .gemini/
│   └── styleguide.md         # Gemini Code Assist review style
├── .pre-commit-config.yaml.template  # Pre-commit hooks template
├── .cursorignore             # Files Cursor should not index
└── .github/
    ├── copilot-instructions.md   # GitHub Copilot instructions (auto-read)
    ├── pull_request_template.md  # Default PR body skeleton (Doc-sync checklist required)
    ├── agents/                   # 10 role-specialized agent files
    │   ├── analyst.agent.md, architect.agent.md, critic.agent.md,
    │   ├── judge.agent.md, pm.agent.md, frontend.agent.md,
    │   ├── backend.agent.md, qa.agent.md, devops.agent.md,
    │   └── docs.agent.md
    ├── prompts/
    │   ├── README.md             # Prompt catalog
    │   ├── copilot-onboarding.md # Guide for customizing copilot-instructions.md
    │   ├── repo-onboarding.md    # Repo onboarding workflow prompt
    │   ├── pr-resolve-all.md     # PR-review resolution procedure
    │   └── expand-backlog-entry.md # Backlog → issue expansion prompt
    ├── ISSUE_TEMPLATE/           # bug_report, feature_request, agent_init, config.yml
    └── workflows/
        ├── ci-tests.yml
        ├── claude.yml
        ├── keep-warm.yml
        ├── lint-and-format.yml
        ├── validate-connections.yml
        ├── agent-assign-copilot.yml
        ├── agent-auto-merge.yml
        ├── agent-auto-ready.yml
        ├── agent-coordination-sync.yml
        ├── agent-fix-reviews.yml
        ├── agent-multi-dispatch.yml
        ├── agent-parallelism-report.yml
        ├── agent-relay-reviews.yml
        ├── agent-release-slot.yml
        ├── auto-rebase-on-merge.yml
        ├── backlog-to-issues.yml
        └── agent-heartbeat.yml.template
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
| `.github/agents/analyst.agent.md` | Multi-tool | Needs analysis, market research, problem validation (no code) |
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
| `.context/backlog.yaml` | Machine-readable task list. Planned for dispatch into issues by `.github/workflows/backlog-to-issues.yml` once that workflow lands (added in PR 3 of the backlog-pipeline series). Validate with `pip install check-jsonschema && check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml` |
| `.context/backlog.schema.json` | JSON Schema for `backlog.yaml` (Draft-07) |
| `.context/roadmap.md` | Phase-by-phase plan |
| `.context/rules/` | Domain constraints (never violate) |
| `.context/rules/agent_ownership.md` | Canonical role → owned paths map for multi-agent work |
| `.context/rules/domain_code_quality.md` | Built-in language-neutral SOLID/TDD/clean-code floor |
| `.context/rules/process_doc_maintenance.md` | Doc-sync triggers (which companion files must update together); enforced by Judge at diff-gate |
| `.context/state/coordination.md` | Live claim board for parallel multi-agent work |
| `.context/state/feedback_template.md` | Stakeholder feedback capture template |
| `.context/state/handoff_template.md` | Cross-session/cross-role handoff template (used at ~30 turns or before role swap) |
| `.context/state/task_*.md` | Current task(s) for session handoff |
| `.context/vision/` | Mockups and architecture diagrams |

### Prompts (user-triggered, not auto-loaded)
| File | Purpose |
|------|---------|
| `.github/prompts/copilot-onboarding.md` | Guide for customizing copilot-instructions.md |
| `.github/prompts/repo-onboarding.md` | Repo onboarding workflow prompt |

### Setup Scripts
| File | Purpose |
|------|---------|
| `install.sh` | Runs on Codespace start; installs extensions, copies prompts |
| `test.sh` | Verifies template integrity (see Verification Commands below for live check count) |
| `scripts/setup.sh` | First-run project customization helper |
| `scripts/verify-env.sh` | Environment & placeholder sanity check |
| `scripts/db-reset.sh` | Optional database reset stub |

### Issue Templates
| File | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/bug_report.md` | Structured bug reports |
| `.github/ISSUE_TEMPLATE/feature_request.md` | Feature requests with acceptance criteria |
| `.github/ISSUE_TEMPLATE/agent_init.md` | Initialize repo from template |
| `.github/ISSUE_TEMPLATE/config.yml` | Chooser config (rewritten by `scripts/setup.sh`) |

### Deployment Configs
| File | Platform | Purpose |
|------|----------|---------|
| `config/vercel.json.template` | Vercel | Frontend, serverless |
| `config/railway.toml.template` | Railway | Backend services |
| `config/render.yaml.template` | Render | Full-stack blueprint |
| `config/docker-compose.yml.template` | Docker Compose | Local dev stack |

### Development Tools
| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml.template` | Pre-commit hooks (linting, secrets) |
| `docs/decisions/README.md` | ADR index, supersession discipline, what a well-documented ADR looks like |
| `docs/decisions/adr-template.md` | Architecture Decision Record template (with "When to write" header) |
| `docs/postmortems/README.md` | Postmortem index, when to write, ADR-vs-postmortem split, "What generalizes" promotion gate |
| `docs/postmortems/postmortem-template.md` | Postmortem / lessons-learned template (Trigger, Expected vs Actual, Root cause, What generalizes, Action items) |
| `.github/pull_request_template.md` | PR template with required doc-sync checklist |
| `docs/guides/agent-best-practices.md` | Token limits, session handoff, secrets, prompt caching, issue/PR granularity |
| `docs/guides/multi-agent-coordination.md` | Parallel role-based workflow (Analyst/Architect/FE/BE/PM/QA/DevOps/Docs/Judge/Critic) |
| `docs/guides/optional-skills.md` | Optional external Claude Code skills (SOLID, everything-claude-code) |
| `.github/workflows/agent-heartbeat.yml.template` | Optional scheduled workflow to surface stale locks / stuck tasks |

### CI/CD Workflows
| File | Purpose |
|------|---------|
| `ci-tests.yml` | Build, lint, test pipeline (customize for project) |
| `lint-and-format.yml` | Markdown + script lint/format pass |
| `keep-warm.yml` | Prevents free-tier backend suspension |
| `validate-connections.yml` | Daily backend/DB connectivity check |
| `claude.yml` | Claude Code triggers (`@claude` mention + auto-review on PR open) |
| `agent-assign-copilot.yml` | Gated Copilot PR assignment for `copilot:ready` issues |
| `agent-auto-merge.yml` | Opt-in auto-merge via `auto-merge` label (CI green + threads resolved) |
| `agent-auto-ready.yml` | Marks Copilot PRs ready for review when implementation completes |
| `agent-coordination-sync.yml` | Reconciles `.context/state/coordination.md` with live PR/issue state |
| `agent-fix-reviews.yml` | Triggers Claude to run `pr-resolve-all.md` on review feedback |
| `agent-multi-dispatch.yml` | Parallel Copilot fan-out with overlap-safety classifier |
| `agent-parallelism-report.yml` | Cross-PR overlap classifier; posts a comment on every open PR |
| `agent-relay-reviews.yml` | Relays bot review comments to Copilot via `@copilot follow` |
| `agent-release-slot.yml` | Releases Copilot slot + drains queue on PR close |
| `auto-rebase-on-merge.yml` | Opt-in auto-rebase of overlapping PRs via `auto-rebase` label |
| `backlog-to-issues.yml` | Materializes `.context/backlog.yaml` entries as GitHub issues |
| `agent-heartbeat.yml.template` | Optional scheduled workflow to surface stale locks |

## Truth Hierarchy

See `AGENTS.md` §"Truth hierarchy" for the canonical definition. Summary:
`.context/**` > `docs/**` > codebase.

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
# Check all required files exist
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

- `install.sh` reads the `$DOTFILES` environment variable (set automatically by
  the GitHub Codespaces "Dotfiles" feature when this repo is linked as the
  user's dotfiles repo). The variable name is a Codespaces convention — it
  points at this template, not at Unix dotfiles. If `$DOTFILES` is not set,
  `install.sh` falls back to the script's own directory.
- The `code` command may not be available outside of VS Code/Codespaces environments
- Some AI tools only read files from specific paths (see tool documentation)
- Workflow files (`.github/workflows/`) contain `TEMPLATE_PLACEHOLDER` and must be customized

## Updating This Guide

When making changes to this template:
1. Update this file if structure/commands/conventions change
2. Run `./test.sh` to verify integrity
3. Update README.md if user-facing behavior changes
4. Update `.context/` files if project direction changes
