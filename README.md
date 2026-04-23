<!-- TEMPLATE_PLACEHOLDER: GENERATED FROM mikejmckinney/ai-repo-template. -->
<!-- THIS REPO IS NOT THE TEMPLATE ITSELF. Replace this README for the actual project. -->

# AI-Ready Repository Template

<!-- Agent Status Badge - Update phase as project progresses -->
<!-- Options: Phase 0: Design | Phase 1: Foundation | Phase 2: Development | Phase 3: Polish | Phase 4: Maintenance -->
![Agent Status](https://img.shields.io/badge/Agent%20Status-Phase%200%3A%20Design-blue)
![Last Updated](https://img.shields.io/badge/Last%20Updated-January%202025-green)

A template repository for GitHub Codespaces that provides pre-configured AI agent prompts, context management for LLM memory, and automatic development environment setup. Use this as a starting point for new repositories or link it to your Codespaces settings.

> **For AI Agents**: See `AI_REPO_GUIDE.md` for a concise reference optimized for agent consumption.

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
│   ├── backlog.yaml              # Machine-readable task list (dispatched into issues)
│   ├── backlog.schema.json       # JSON Schema for backlog.yaml
│   ├── roadmap.md                # Phase-by-phase plan
│   ├── rules/                    # Immutable domain constraints
│   │   ├── README.md
│   │   ├── agent_ownership.md    # Role → owned paths map
│   │   ├── domain_code_quality.md # Language-neutral quality floor
│   │   └── process_doc_maintenance.md # Doc-sync trigger map
│   ├── sessions/                 # Session history for handoff
│   │   ├── README.md
│   │   └── latest_summary.md     # Most recent session summary
│   ├── state/                    # Mutable progress tracking
│   │   ├── README.md
│   │   ├── _active.md            # Points to current priority task
│   │   ├── coordination.md       # Live claim board for parallel agents
│   │   ├── feedback_template.md  # Stakeholder feedback template
│   │   ├── handoff_template.md   # Cross-session/role handoff template
│   │   ├── task_template.md      # Template for new tasks
│   │   └── task_*.md             # Individual task files
│   └── vision/                   # Design artifacts
│       ├── README.md
│       ├── mockups/              # UI/UX mockups
│       └── architecture/         # System diagrams
│
├── docs/                         # Human reference documentation
│   ├── README.md                 # Documentation guide
│   ├── FAQ.md                    # Common questions about this template
│   ├── smoke-a.md                # Smoke test scenario A
│   ├── smoke-e.md                # Smoke test scenario E
│   ├── decisions/                # Architecture Decision Records (adr-001 … adr-010, adr-template)
│   ├── guides/                   # How-to guides (agent-best-practices, agent-pipeline, context-files-explained, multi-agent-coordination, optional-skills)
│   ├── postmortems/              # Postmortems (template + project-specific)
│   ├── reference/                # Specs, external docs
│   └── research/                 # Analyst output (analysis artifacts)
│
├── .claude/
│   └── agents/                   # Claude Code subagent registry (10 mirrors of .github/agents/, see ADR-003)
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
│   ├── render.yaml.template      # Render blueprint config
│   └── docker-compose.yml.template # Local dev compose stack
│
├── scripts/                      # Project bootstrap + verification scripts
│   ├── README.md                 # Script catalog
│   ├── setup.sh                  # First-run project customization
│   ├── verify-env.sh             # Environment & placeholder sanity check
│   ├── db-reset.sh               # Optional DB reset stub
│   ├── auto-rebase-overlapping.sh    # Auto-rebase library (ADR-010)
│   ├── multi-dispatch-safety.sh      # Parallel-dispatch safety classifier
│   ├── parse-ownership-table.sh      # Ownership-table parser used by workflows
│   └── test-*.sh                 # Unit tests for the helper scripts above
│
├── .pre-commit-config.yaml.template  # Pre-commit hooks template
├── .cursorignore                 # Files Cursor should not index
│
└── .github/
    ├── copilot-instructions.md   # GitHub Copilot instructions (auto-read)
    ├── pull_request_template.md  # Default PR body skeleton (Doc-sync checklist required)
    ├── agents/                   # Role-specialized agent files (10 files)
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
    ├── ISSUE_TEMPLATE/           # Issue templates
    │   ├── bug_report.md         # Bug report template
    │   ├── feature_request.md    # Feature request template
    │   ├── agent_init.md         # Agent initialization task
    │   └── config.yml            # Template chooser config
    └── workflows/
        ├── ci-tests.yml               # CI pipeline (customize for project)
        ├── claude.yml                 # Claude Code agent triggers (review, mention)
        ├── keep-warm.yml              # Ping backend to prevent suspension
        ├── lint-and-format.yml        # Lint & format check
        ├── validate-connections.yml   # Daily connectivity checks
        ├── agent-assign-copilot.yml   # Gated Copilot PR assignment
        ├── agent-auto-merge.yml       # Opt-in auto-merge via auto-merge label
        ├── agent-auto-ready.yml       # Mark Copilot PRs ready when complete
        ├── agent-coordination-sync.yml # Sync coordination.md state
        ├── agent-fix-reviews.yml      # Run pr-resolve-all.md (Claude)
        ├── agent-multi-dispatch.yml   # Parallel Copilot fan-out
        ├── agent-parallelism-report.yml # Cross-PR overlap classifier
        ├── agent-relay-reviews.yml    # Relay bot review comments to Copilot
        ├── agent-release-slot.yml     # Release Copilot slot on PR close
        ├── auto-rebase-on-merge.yml   # Opt-in auto-rebase via auto-rebase label
        ├── backlog-to-issues.yml      # Materialize backlog.yaml entries as issues
        └── agent-heartbeat.yml.template # Optional: stale-lock surfacer
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
| `.github/agents/analyst.agent.md` | Multi-tool | Needs analysis, market research, problem validation (no code) |
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
| `.context/rules/domain_code_quality.md` | Built-in language-neutral SOLID/TDD/clean-code floor |
| `.context/state/coordination.md` | Live claim board for parallel multi-agent work |
| `.context/state/feedback_template.md` | Stakeholder feedback capture template |
| `.context/state/task_*.md` | Current task(s) for cognitive handoff |
| `.context/sessions/` | Session history to prevent repeating mistakes |
| `.context/vision/` | Mockups and architecture diagrams |

### Prompts (user-triggered)

| File | Purpose |
|------|---------|
| `.github/prompts/copilot-onboarding.md` | Guide for customizing copilot-instructions.md |
| `.github/prompts/repo-onboarding.md` | Repo onboarding workflow prompt |
| `.github/prompts/pr-resolve-all.md` | Procedural — review-resolution playbook used by `agent-fix-reviews.yml` and the `@copilot follow` / `@claude follow` convention |
| `.github/prompts/expand-backlog-entry.md` | Procedural — used by `backlog-to-issues.yml` to expand sparse `backlog.yaml` entries |

### Issue Templates

| File | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/bug_report.md` | Structured bug reports |
| `.github/ISSUE_TEMPLATE/feature_request.md` | Feature requests with acceptance criteria |
| `.github/ISSUE_TEMPLATE/agent_init.md` | Initialize repo from template (agent task) |
| `.github/ISSUE_TEMPLATE/config.yml` | Chooser config (rewritten by `scripts/setup.sh` at init) |

### Deployment Configs

| File | Platform | Purpose |
|------|----------|---------|
| `config/vercel.json.template` | Vercel | Frontend, serverless functions |
| `config/railway.toml.template` | Railway | Backend services |
| `config/render.yaml.template` | Render | Full-stack blueprints |
| `config/docker-compose.yml.template` | Docker Compose | Local dev stack |

### Development Tools

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml.template` | Pre-commit hooks for linting, secrets, formatting |
| `docs/decisions/adr-template.md` | Template for Architecture Decision Records |
| `docs/postmortems/README.md` | Postmortems / lessons-learned index and "What generalizes" promotion gate |
| `docs/postmortems/postmortem-template.md` | Template for retrospective lessons (Trigger, Expected vs Actual, Root cause, Action items) |
| `docs/decisions/adr-001-context-pack-structure.md` | Rationale for the `.context/` layout |
| `docs/decisions/adr-002-agents-md-ownership.md` | AGENTS.md ownership assignment |
| `docs/decisions/adr-003-claude-code-subagent-registration.md` | Claude Code subagent registration rationale |
| `docs/decisions/adr-004-analyst-role-and-feedback-loop.md` | Analyst role and agile feedback loop |
| `docs/guides/multi-agent-coordination.md` | How role-based agents work in parallel without conflicts |
| `docs/guides/agent-pipeline.md` | End-to-end operations guide for the autonomous agent pipeline (Copilot/Claude/auto-merge/backlog) |
| `docs/guides/agent-best-practices.md` | Token limits, handoff, secrets |
| `docs/guides/context-files-explained.md` | What every file in the context pack is for |
| `docs/guides/optional-skills.md` | Curated optional Claude Code skills (SOLID, everything-claude-code) |
| `.github/workflows/agent-heartbeat.yml.template` | Optional scheduled workflow to surface stale locks / stuck tasks |
| `scripts/setup.sh` | First-run project customization helper |
| `scripts/verify-env.sh` | Environment & `TEMPLATE_PLACEHOLDER` sanity check |
| `scripts/db-reset.sh` | Optional database reset stub |

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
| `lint-and-format.yml` | Markdown + script lint/format | None |
| `keep-warm.yml` | Ping backend every 14 min | Set `BACKEND_URL` secret |
| `validate-connections.yml` | Daily connectivity check | Set `BACKEND_URL` secret |
| `claude.yml` | Claude Code triggers (`@claude` mention, auto-review on PR) | Set `ANTHROPIC_API_KEY` secret |
| `agent-assign-copilot.yml` | Gated Copilot PR assignment when issues are labeled `copilot:ready` | Set `CLAUDE_PAT` secret |
| `agent-auto-merge.yml` | Opt-in auto-merge when CI green + threads resolved (`auto-merge` label) | Set `CLAUDE_PAT` secret |
| `agent-auto-ready.yml` | Mark Copilot PRs ready for review when implementation completes | None |
| `agent-coordination-sync.yml` | Reconcile `.context/state/coordination.md` with live PR/issue state | None |
| `agent-fix-reviews.yml` | Trigger Claude to run `pr-resolve-all.md` on review feedback | Set `ANTHROPIC_API_KEY` |
| `agent-multi-dispatch.yml` | Parallel Copilot fan-out (multi-issue dispatch with overlap safety) | Set `CLAUDE_PAT` secret |
| `agent-parallelism-report.yml` | Cross-PR overlap classifier; posts comment on each open PR | None |
| `agent-relay-reviews.yml` | Relay bot review comments to Copilot via `@copilot follow` | Set `CLAUDE_PAT` secret |
| `agent-release-slot.yml` | Release Copilot slot + drain queue on PR close | Set `CLAUDE_PAT` secret |
| `auto-rebase-on-merge.yml` | Opt-in auto-rebase of overlapping PRs after merge (`auto-rebase` label) | Set `CLAUDE_PAT` secret |
| `backlog-to-issues.yml` | Materialize `.context/backlog.yaml` entries as GitHub issues | Set `CLAUDE_PAT` secret |
| `agent-heartbeat.yml.template` | Optional: stale-lock surfacer | Rename to `.yml` to enable |

## Setup

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
5. Replace README.md with project-specific content, including
   `## Limitations`, `## Future Improvements`, and a `## FAQ` section
   (or link to docs/FAQ.md — replace the template's FAQ entries with
   project-specific ones).
6. Regenerate AI_REPO_GUIDE.md for THIS repo
7. Replace or customize docs/FAQ.md for the project (template-specific
   entries prefixed with "Template:" should be removed)
8. Do not modify .context/** unless instructed
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

1. **Fill in `.context/00_INDEX.md`** - Document your project's purpose and current state
2. **Define roadmap phases** - Use `.context/roadmap.md` to plan work
3. **Create domain rules** - Add constraints to `.context/rules/`
4. **Start with mockups** - Add design artifacts to `.context/vision/` before coding
5. **Create task files** - Use `state/task_*.md` for cognitive handoff between sessions
6. **Keep AGENTS.md as the canonical agent instructions** - Per [`docs/decisions/adr-002-agents-md-ownership.md`](docs/decisions/adr-002-agents-md-ownership.md), AGENTS.md is read by most AI tools (Copilot, Cursor, Gemini, Claude Code via `CLAUDE.md`) and references `AI_REPO_GUIDE.md` for structured detail. Edit it directly when agent-facing rules change; do not strip it down to a pointer.
7. **Customize CI pipeline** - Update `ci-tests.yml` for your tech stack
8. **Run tests** - Use `./test.sh` to verify your customizations

## Limitations

Known constraints of this template. Agent-facing detail (environment variables, tool-specific path rules, workflow placeholders) lives in [`AI_REPO_GUIDE.md` § Gotchas / Known Issues](AI_REPO_GUIDE.md#gotchas--known-issues).

- **Opinionated scaffolding.** The 10-role multi-agent model, `.context/` lazy-loading pattern, and dual agent registries (`.github/agents/` + `.claude/agents/`) reflect specific design choices recorded in `docs/decisions/`. Forks that disagree should strip rather than bend.
- **No runtime code.** This is a docs/config template, not a language-specific starter. Your project brings its own build, test, and deploy toolchain; `ci-tests.yml` ships with placeholder commands you must replace.
- **Codespaces-centric bootstrap.** `install.sh` is wired to the GitHub Codespaces "Dotfiles" feature (via the `$DOTFILES` env var). It falls back to its own directory elsewhere, but some convenience features (extension install, prompt copy) assume a Codespace.
- **Template placeholders are text, not schema.** The `TEMPLATE_PLACEHOLDER` marker is grep-discoverable but not validated for correctness. Running `scripts/verify-env.sh` lists them; the agent still has to make the judgement call on replacement content.
- **Copilot instructions are length-capped.** Per GitHub's constraint, `.github/copilot-instructions.md` must stay ≤ 2 pages and non-task-specific. See [`.github/prompts/copilot-onboarding.md`](.github/prompts/copilot-onboarding.md).

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
