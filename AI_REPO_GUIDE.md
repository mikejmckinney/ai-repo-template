<!-- TEMPLATE_PLACEHOLDER: This file must be regenerated for the actual project repo. -->
<!-- Run .github/prompts/repo-onboarding.md to rebuild this guide from real repo assets. -->

# AI_REPO_GUIDE.md

> **Purpose**: Canonical reference for AI agents working with this template repository.  
> **Last verified**: 2026-06-15
>
> **Note**: This file is for agents. For human documentation, see `README.md`.

## Overview

This is the **AI repo template** (`mikejmckinney/ai-repo-template`) for GitHub
Codespaces and AI-assisted development. It plugs into the GitHub Codespaces
"Dotfiles" feature (which runs an install script at Codespace startup) to
bootstrap a multi-agent development kit. It
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

```text
/
├── AI_REPO_GUIDE.md          # This file - canonical AI reference
├── AGENTS.md                 # Root agent instructions (always read first)
├── AGENT.md                  # Deprecated redirect to AGENTS.md
├── README.md                 # User-facing documentation
├── DESIGN.md                 # Root design contract for UI tools + frontend handoff
├── install.sh                # Codespace bootstrap script
├── requirements.txt          # Python dependency pin for local validation helpers
├── test.sh                   # Verification script
│
├── .context/                 # Project context (canonical truth)
│   ├── 00_INDEX.md           # Context entry point
│   ├── benchmarks/           # Benchmark protocol docs and templates
│   │   └── model-roi/        # Phase A model ROI benchmark surfaces (issue #374)
│   │       └── tasks/        # Benchmark task injections and sealed reference metadata
│   ├── backlog.yaml          # Machine-readable task list (dispatched into issues)
│   ├── backlog.schema.json   # JSON Schema for backlog.yaml
│   ├── roadmap.md            # Phase-by-phase plan
│   ├── rules/                # Canonical domain constraints + process rules
│   │   ├── README.md         # Rule catalog and read profiles
│   │   ├── process_session_start.md
│   │   ├── process_*.md      # Work style, gates, doc maintenance, etc.
│   │   ├── domain_code_quality.md
│   │   └── repo_orchestration_patterns.md
│   ├── sessions/             # Durable retrospectives + feedback records
│   │   ├── README.md
│   │   ├── feedback_template.md  # Stakeholder feedback template
│   │   └── latest_summary.md
│   ├── state/                # Reference artifacts for the GitHub-first live-state baton
│   │   ├── README.md
│   │   └── agent_state_comment_template.md # GitHub live-state comment template
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
│   ├── decisions/            # Architecture Decision Records, index, and template
│   ├── guides/               # How-to guides (agent-best-practices, agent-pipeline, agents-md-section-redirects, context-files-explained, design-patterns* splits, multi-agent-coordination, opportunity-feedback-examples, repo-orchestration-patterns-reference, subagent-bootstrap-reference, multi-model-consensus, optional-skills)
│   ├── postmortems/          # Postmortems (template + project-specific)
│   ├── reference/            # Specs, external docs
│   └── research/             # Analyst output (analysis artifacts)
│
├── scripts/                  # Bootstrap + verification scripts
│   ├── README.md
│   ├── checks/               # Numbered test.sh check modules (issue #255 Phase 4d)
│   │   ├── README.md
│   │   └── <NNN>-*.sh        # Sourced by test.sh in lexical order (3-digit zero-padded prefix)
│   ├── lib/                  # Shared shell helpers (issue #255 Phase 4a)
│   │   ├── logging.sh        # Color vars + log_info/warn/error/step
│   │   ├── assertions.sh     # PASS/FAIL/WARN counters + pass/fail/warn
│   │   ├── bot-allowlist.txt # Canonical normalized bot identities for pr-resolve-all / Phase 4 (issue #326)
│   │   └── jq/               # Extracted jq filters + fixtures (issue #229)
│   ├── setup/                # Numbered setup.sh modules (issue #255 Phase 4c)
│   │   ├── README.md
│   │   └── <NN>-*.sh         # Sourced by scripts/setup.sh in lexical order
│   ├── tests/                # Bats test suite for script checks and fixtures
│   │   ├── README.md
│   │   └── *.bats            # One file per concern; current script tests run via bats
│   ├── benchmark/            # Phase A model ROI benchmark runner/prototype (issue #374)
│   ├── workflows/            # AP8 workflow logic extracted from .github/workflows
│   │   ├── advisory-review/  # agent-advisory-review.yml dispatch, providers, comment upsert
│   │   ├── pr-feedback/      # agent-review-finalize.yml collect + consolidate dispatch
│   │   ├── postmerge-retro/  # agent-postmerge-retro.yml daily batch + fix PR
│   │   ├── weekly-review/    # agent-weekly-review.yml full-repo scan + fix PR
│   │   └── lib/              # shared prompt helpers, fix-branch checkout, SDK version pin, fix PR linker
│   ├── setup.sh              # First-run project customization (thin orchestrator over scripts/setup/)
│   ├── verify-env.sh         # Environment & placeholder sanity check
│   ├── diag-sandbox.sh       # Read-only sandbox auth/access doctor (issue #365)
│   ├── verify-pr.sh          # Plan-template Change-class classifier (issue #227, ADR-016)
│   ├── validate-compliance-examples.py # ADR-026 docs YAML example validator
│   ├── validate-compliance-fixtures.py # ADR-026 fixture validator
│   ├── db-reset.sh           # Optional DB reset stub
│   ├── auto-rebase-overlapping.sh    # Auto-rebase library (ADR-010)
│   ├── multi-dispatch-safety.sh      # Parallel-dispatch safety classifier
│   ├── parse-ownership-table.sh      # Ownership-table parser used by workflows
│   ├── pr-iteration-stats.sh         # Rolling PR review-loop metrics (issue #229)
│   ├── pr-resolve-all-poll.sh        # Pre-#321 settle-window poll helper for pr-resolve-all (issue #326)
│   └── lint-shell-conventions.sh     # Project-specific shell rules (RULE-01/02, issue #229)
│
├── config/                   # Deployment config templates (see table below)
│
├── .agents/                  # Canonical role contracts and shared definitions
│   ├── README.md             # Canonical/overlay split rationale
│   ├── _TEMPLATE.md          # Canonical role-contract template
│   └── <role>.md             # 10 canonical role definitions used by all overlays
│
├── .codex/
│   └── agents/               # Codex custom-agent TOML overlays for the 10 canonical roles
├── .claude/
│   └── agents/               # Claude Code subagent overlays for the 10 canonical roles (see ADR-003)
├── .cursor/
│   ├── agents/               # Cursor agent overlays for the 10 canonical roles
│   └── BUGBOT.md             # Cursor Bugbot PR review rules
├── .gemini/
│   └── styleguide.md         # Gemini Code Assist review style
├── .pre-commit-config.yaml           # Template repo's own hooks: shellcheck + actionlint (ADR-017)
├── .pre-commit-config.yaml.template  # Heavyweight scaffold for derived repos (ADR-013, opt-in)
├── .cursorignore             # Files Cursor should not index
└── .github/
    ├── copilot-instructions.md   # Pointer to AGENTS.md (auto-read by Copilot)
    ├── pull_request_template.md  # Default PR body skeleton (Plan pointer [advisory] + Doc-sync checklist + ADR-029 Sandbox dogfood evidence section required)
    ├── agents/                   # Copilot SDK overlays: 10 canonical roles + 3 consensus candidates
    │   ├── analyst.agent.md
    │   ├── architect.agent.md
    │   ├── critic.agent.md
    │   ├── judge.agent.md
    │   ├── pm.agent.md
    │   ├── frontend.agent.md
    │   ├── backend.agent.md
    │   ├── qa.agent.md
    │   ├── devops.agent.md
    │   ├── docs.agent.md
    │   ├── consensus-candidate-claude.agent.md
    │   ├── consensus-candidate-gemini.agent.md
    │   └── consensus-candidate-gpt.agent.md
    ├── prompts/
    │   ├── README.md             # Prompt catalog
    │   ├── capture-postmortem.md # Postmortem capture workflow prompt
    │   ├── expand-backlog-entry.md # Backlog → issue expansion prompt
    │   ├── handshake-and-shape-smoke.md # No-edit smoke: handshake positional contract + response shape (4 scenarios)
    │   ├── instruction-compliance-smoke.md # No-edit ADR-026 compliance smoke prompt
    │   ├── judge-mode-smoke.md   # No-edit smoke prompt for Judge PLAN-GATE/DIFF-GATE mode selection
    │   ├── mirror-postmortem.md  # Postmortem mirror/sync workflow prompt
    │   ├── model-roi-benchmark-candidate.md # Canonical prompt for the model ROI benchmark (issue #374)
    │   ├── multi-model-consensus-plan.md # Optional three-planner consensus prompt
    │   ├── op-issue-workflow.md  # OP end-to-end issue to merge playbook
    │   ├── outcome-validation-smoke.md # No-edit Judge/Critic outcome-theater smoke prompt
    │   ├── pre-push-review.md    # Critic/lint/test pre-push checklist prompt
    │   ├── pr-advisory-review.md # Non-blocking advisory snapshot (ai-review:live)
    │   ├── pr-final-feedback-consolidation.md # Final Feedback Inbox (implementation-complete)
    │   ├── pr-resolve-all.md     # PR-review resolution procedure
    │   ├── repo-onboarding.md         # Repo onboarding procedure prompt
    ├── ISSUE_TEMPLATE/           # bug_report, feature_request, agent_init, config.yml
    ├── templates/                # Automation-rendered bodies (scripts/workflows); not GitHub chooser UI
    │   ├── postmerge-retro-umbrella.md  # Daily retro umbrella issue body
    │   └── postmerge-retro-fix-pr.md    # Daily retro draft fix PR body (slim; not full pull_request_template)
    └── workflows/
        ├── ci-tests.yml
        ├── claude.yml
        ├── keep-warm.yml
        ├── lint-and-format.yml
        ├── validate-connections.yml
        ├── agent-assign-copilot.yml
        ├── agent-auto-merge.yml
        ├── agent-auto-ready.yml
        ├── agent-advisory-review.yml
        ├── agent-review-finalize.yml
        ├── agent-fix-reviews.yml
        ├── agent-multi-dispatch.yml
        ├── agent-parallelism-report.yml
        ├── agent-relay-reviews.yml
        ├── agent-release-slot.yml
        ├── auto-rebase-on-merge.yml
        ├── backlog-to-issues.yml
```

## Key Files by Purpose

### Agent Instructions (read by AI assistants automatically)

| File | Tool/Platform | Purpose |
|------|--------------|---------|
| `AGENTS.md` | Most AI tools (Copilot, Cursor, Gemini, Claude Code, etc.) | Root startup contract and read-profile routing |
| `.github/copilot-instructions.md` | GitHub Copilot | Pointer to AGENTS.md + Copilot-specific rules (e.g., `@copilot follow`) |
| `.cursor/BUGBOT.md` | Cursor Bugbot | PR review rules |
| `.gemini/styleguide.md` | Gemini Code Assist | PR review style guide |
| `.github/agents/{judge,critic,architect,analyst,pm,frontend,backend,qa,devops,docs}.agent.md` | GitHub Copilot SDK | Copilot subagent registration overlays for the 10 canonical repo roles (frontmatter only) |
| `.github/agents/consensus-candidate-*.agent.md` | GitHub Copilot SDK | Copilot-only consensus-planning candidate overlays pinned to Claude, Gemini, and GPT models for `multi-model-consensus-plan.md` |
| `.claude/agents/*.md` | Claude Code | Claude Code subagent registration overlays (frontmatter only) |
| `.cursor/agents/*.md` | Cursor | Cursor agent registration overlays (`model`, `readonly`, `is_background`) plus a pointer to the canonical role body |
| `.codex/agents/*.toml` | Codex | Codex custom-agent overlays (`name`, `description`, `model`, `model_reasoning_effort`, `sandbox_mode`, `developer_instructions`) pointing to the canonical role body |
| `.agents/<role>.md` | Multi-tool (canonical) | Platform-agnostic role definition (responsibilities, Do/Don't, output format) per ADR-023 — read by every overlay above |
| `.agents/_TEMPLATE.md` | Multi-tool (template) | Canonical role-contract template for ADR-026 `role_contract_version` and `subagent_compliance` return guidance; not a dispatchable role |

Canonical role behavior lives only in `.agents/<role>.md`. Overlay-local fields stay in the platform folders: Copilot and Claude carry platform-specific `model` strings, Cursor adds `readonly` and `is_background`, and Codex uses TOML plus `model_reasoning_effort` and `sandbox_mode`. ADR-019 keeps those model tiers platform-specific, and `scripts/checks/050-agent-mirror.sh` enforces per-platform allowlists.

### Root Docs and Workflow Files

| File | Tool/Platform | Purpose |
|------|--------------|---------|
| `README.md` | Humans + AI agents | User-facing repository overview |
| `DESIGN.md` | AI agents + design tools (OpenDesign, Claude Design, etc.) | Root design contract — tokens, UX, a11y floor, mockup workflow; customize during Mode B onboarding |
| `requirements.txt` | Python tooling | Dependency pin for local validation helpers |

### Context Pack (project memory)

| File | Purpose |
|------|---------|
| `.context/00_INDEX.md` | Entry point, project summary |
| `.context/backlog.yaml` | Machine-readable task list. Planned for dispatch into issues by `.github/workflows/backlog-to-issues.yml` once that workflow lands (added in PR 3 of the backlog-pipeline series). Validate with `pip install check-jsonschema && check-jsonschema --schemafile .context/backlog.schema.json .context/backlog.yaml` |
| `.context/backlog.schema.json` | JSON Schema for `backlog.yaml` (Draft-07) |
| `.context/benchmarks/model-roi/README.md` | Durable protocol and artifact contract for the agent/model ROI benchmark tracked in issue `#374` |
| `.context/benchmarks/model-roi/benchmark-runbook.md` | Repeatable benchmark setup/run/grading/telemetry procedure, including known issues and future candidate backlog |
| `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md` | Scored benchmark record, cost source register, and ROI tables used to support repo-local ROI/performance revisions |
| `.context/benchmarks/model-roi/tasks/opfit-281-class-a.md` | Class A operational-fit benchmark task from issue `#281` / reference PR `#288`; runner injects only its candidate-safe task body |
| `.context/benchmarks/model-roi/tasks/opfit-326-class-b.md` | Class B reasoning/code benchmark task from issue `#326` / reference PR `#358`; runner injects only its candidate-safe task body |
| `.context/benchmarks/model-roi/context-packs/` | Stage 1E targeted context-pack manifests; use `CONTEXT_VARIANT=pack:<pack-id>` with `RUN_GROUP` for variant matrix runs (issue `#378`) |
| `.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example` | CP-1 pack screen candidate manifest (`ctx-cur`, `ctx-gem`) |
| `.context/benchmarks/model-roi/result-template.md` | Per-alias blind-safe plus sealed benchmark result template |
| `.context/benchmarks/model-roi/summary-template.md` | Task-level Stage 1 summary and shortlist template for the same benchmark |
| `.context/roadmap.md` | Phase-by-phase plan |
| `.context/rules/` | Domain constraints and process rules (catalog in `README.md`) |
| `.context/rules/process_session_start.md` | Startup handshake, read credit, and context receipt |
| `.context/rules/domain_code_quality.md` | Built-in language-neutral SOLID/TDD/clean-code floor |
| `.context/rules/process_doc_maintenance.md` | Doc-sync triggers (which companion files must update together); enforced by Judge at diff-gate |
| `.context/rules/process_opportunity_feedback.md` | Opportunity feedback channel (9-field `opportunity_notes` contract); examples in `docs/guides/opportunity-feedback-examples.md` |
| `.context/rules/repo_orchestration_patterns.md` | Normative orchestration patterns (`P1`–`P9`) and anti-patterns (`AP1`–`AP9`) for Critic/Judge; long-form reference in `docs/guides/repo-orchestration-patterns-reference.md` (ADR-020, P9 in ADR-024) |
| `.agents/<role>.md` | Role-specific gates, ownership hints, and dispatch behavior when subagents are used |
| `docs/guides/subagent-bootstrap-reference.md` | ADR-026 dispatch packet and pass-back narrative (historical; monolithic default per ADR-031) |
| `docs/guides/agent-pipeline.md` | Workflow gates, labels, and review/fix automation |
| Assigned GitHub issue / linked PR / latest `agent-state:v1` comment | Primary live coordination state for GitHub-connected work (ADR-025). May embed an optional `opportunity_notes` YAML block (v1.2; ADR-027) for out-of-scope improvement notes — see `docs/compliance_schemas.md` § "agent-state:v1". |
| `.context/sessions/feedback_template.md` | Stakeholder feedback capture template |
| `.context/sessions/latest_summary.md` | Durable retrospective lessons; not the live coordination baton |
| `.context/state/README.md` | Reference contract for the in-repo live-state artifacts |
| `.context/state/agent_state_comment_template.md` | Copy/paste template for live coordination comments |
| `.context/vision/` | Mockups and architecture diagrams |

### Prompts (user-triggered, not auto-loaded)

| File | Purpose |
|------|---------|
| `.github/prompts/README.md` | Prompt catalog and usage notes |
| `.github/prompts/capture-postmortem.md` | Capture a postmortem from a completed issue/PR into the docs postmortem workflow |
| `.github/prompts/expand-backlog-entry.md` | Expand a backlog entry into an issue-ready task description |
| `.github/prompts/handshake-and-shape-smoke.md` | No-edit smoke prompt: handshake positional contract and response-shape verification (parent vs subagent, Judge/Critic exact-output first-line, receipt-section placement — 4 scenarios) |
| `.github/prompts/instruction-compliance-smoke.md` | No-edit smoke prompt for startup pointer loading, role-dispatch reasoning, and ADR-026 evidence shape |
| `.github/prompts/judge-mode-smoke.md` | No-edit smoke prompt: Judge PLAN-GATE/DIFF-GATE mode selection and output-format heading conformance |
| `.github/prompts/mirror-postmortem.md` | Mirror a postmortem into the repo's postmortem surfaces after capture/review |
| `.github/prompts/model-roi-benchmark-candidate.md` | Canonical prompt for monolithic agent/model ROI benchmark candidates tracked in issue `#374`; pairs with `.context/benchmarks/model-roi/README.md` and `.context/benchmarks/model-roi/benchmark-runbook.md` |
| `.github/prompts/multi-model-consensus-plan.md` | Optional opt-in multi-model consensus planning prompt for high-risk / architectural / ADR-worthy issues; produces 3 candidate plans + 1 synthesized final plan before Judge plan-gate (ADR-024). See `docs/guides/multi-model-consensus.md`. |
| `.github/prompts/op-issue-workflow.md` | Parent Orchestrator issue-to-merge playbook for the default agent |
| `.github/prompts/outcome-validation-smoke.md` | No-edit smoke prompt that verifies Judge/Critic catch outcome-theater PRs (generic-verification-only and empty-outcome-checklist failure modes) — see issue #311 |
| `.github/prompts/pre-push-review.md` | Run Critic + lint + `./test.sh` against the working-tree diff before push on non-trivial changes |
| `.github/prompts/pr-advisory-review.md` | Non-blocking four-lens advisory snapshot (`agent-advisory-review.yml`, `ai-review:live`) |
| `.github/prompts/pr-final-feedback-consolidation.md` | Final Feedback Inbox consolidation (`agent-review-finalize.yml`, `implementation-complete`) |
| `.github/prompts/post-merge-retro.md` | Per-PR post-merge retrospective JSON (`run-postmerge-retro.sh`) |
| `.github/prompts/post-merge-retro-fix.md` | Daily retro fix implementation prompt |
| `docs/decisions/adr-030-non-blocking-review-pipeline.md` | Non-blocking LLM review pipeline (advisory → finalize → daily post-merge retro v2) |
| `.github/templates/postmerge-retro-umbrella.md` | Daily umbrella issue body (automation; canonical) |
| `.github/templates/postmerge-retro-fix-pr.md` | Daily retro draft fix PR body (automation; slim PR-template shape) |
| `.github/prompts/pr-resolve-all.md` | PR-review resolution procedure |
| `.github/prompts/repo-onboarding.md` | Repo onboarding procedure prompt (Mode B bootstrap inlined in Step 2) |

### Compliance Contracts

| File | Purpose |
|------|---------|
| `docs/compliance_schemas.md` | ADR-026 schema reference for `plan_compliance`, `parent_compliance`, and `subagent_compliance` evidence blocks |
| `docs/decisions/adr-026-compliance-contracts.md` | Decision record for role contract versioning, exact-output receipt coexistence, and staged compliance enforcement |
| `docs/guides/subagent-bootstrap-reference.md` | Parent dispatch packet and subagent return contract reference (ADR-026) |

### Setup Scripts

| File | Purpose |
|------|---------|
| `install.sh` | Runs on Codespace start; installs extensions, copies the multi-agent kit / prompt files into the workspace, then runs [`scripts/codespace-post-start.sh`](scripts/codespace-post-start.sh) (non-fatal `gh` PAT upgrade + sandbox remote advisory) |
| `test.sh` | Template-integrity entry point (see Verification Commands below for live check count). Thin orchestrator (~95 lines) that sources `scripts/checks/[0-9][0-9][0-9]-*.sh` modules (3-digit zero-padded prefix so lexical sort matches numeric order) (issue #255 Phase 4d) |
| `scripts/checks/*.sh` | Per-concern check modules (issue #255 Phase 4d): structural file checks, content/invariant checks, ADR/phase invariants, and parser unit-test smokes. See `scripts/checks/README.md` for the convention and how to add a new module. |
| `scripts/setup.sh` | First-run project customization helper. Thin orchestrator that sources `scripts/setup/[0-9][0-9]-*.sh` modules in lexical order (issue #255 Phase 4c) |
| `scripts/setup/*.sh` | Per-phase setup modules (issue #255 Phase 4c): `00-detect-repo`, `10-env-file`, `20-install-dependencies`, `30-build`, `40-ensure-labels`, `50-ensure-variables`, `60-check-secrets`, `70-verify-env`. See `scripts/setup/README.md` for the module table and how to run a single module. |
| `scripts/verify-env.sh` | Environment & placeholder sanity check; run with `--fix` to auto-install missing tools (bounded allowlist: `rg`, `shellcheck`, `jq`) |
| `scripts/diag-sandbox.sh` | Read-only sandbox auth/access doctor (issue #365): checks auth source, remote reachability, and stale branch inventory; makes no writes. `DIAG_GIT_TIMEOUT` (default 10 s; `0` disables timeout). Run before sandbox operations or when `gh` auth is unclear. See `docs/guides/sandbox-verification.md` § "Sandbox Doctor" |
| `scripts/verify-pr.sh` | Plan-template Change-class classifier (ADR-016 / issue #227); run: `bash scripts/verify-pr.sh --declared "<class>"` |
| `scripts/benchmark/Makefile` | Model ROI benchmark runner: `doctor`, `base`, `run`, `suite`, `worktree`, `record`, `collect`, `unseal`, and `grade-*` (standardized grading). See `.context/benchmarks/model-roi/grading/README.md`. |
| `scripts/benchmark/regrade-stage.sh` | Unified canonical regrade driver (`1` \| `1c` \| `1d` \| `pipeline` \| `1e`): `prepare`, `grade`, `record`, `compile`. Shared config in `regrade-stage-lib.sh`. |
| `scripts/benchmark/llm_grade_subjective.py` | LLM blind subjective grader (Cursor agent + `model-roi-grader-v1`); batch via `blind_grade_stage.py` (stages `1` \| `1c` \| `1d` \| `pipeline`). |
| `scripts/benchmark/stage-*-llm-responses-v1/` | Recorded subjective JSON for `cursor-llm-blind-v1` regrades (Stage 1 / 1C / 1D / pipeline / 1E). **Not on `main`** (gitignored); tracked on branch `benchmark/roi` and tag `benchmark/phase-a-artifacts-20260608`. Deferred follow-ups: `.context/benchmarks/model-roi/FOLLOW_UPS.md`. |
| `scripts/benchmark/update-benchmark-results.py` | Refresh `agent-roi-benchmark-results.md` canonical columns, ROI, and table sort order (`scores` \| `roi` \| `sort` \| `all`). |
| `.context/benchmarks/model-roi/grading/` | Rubric v1 + pipeline v1, JSON schemas, task grading specs, and score-set comparability rules for script-first benchmark grading. |
| `scripts/validate-compliance-examples.py` | Validates fenced YAML examples in `docs/compliance_schemas.md` against ADR-026 v1 shape |
| `scripts/validate-compliance-fixtures.py` | Validates ADR-026 valid/invalid fixtures under `scripts/tests/fixtures/compliance/` |
| `scripts/db-reset.sh` | Optional database reset stub |
| `scripts/pr-iteration-stats.sh` | Rolling 14-day PR review-loop metrics (total/fix/rejected rounds, threads); `--window <days>`, `--json` |
| `scripts/pr-resolve-all-poll.sh` | Pre-#321 settle-window poll helper for `pr-resolve-all.md`; emits `RESULT=...` and, when the current PR head is available, `HEAD=...`; uses `INTERVAL`, `QUIET_WINDOW`, and `MAX_WAIT` overrides |
| `scripts/lint-shell-conventions.sh` | Project-specific shell linting (RULE-01: `grep -c` without `\|\| true`; RULE-02: unanchored `grep -E` alternation patterns); run: `bash scripts/lint-shell-conventions.sh scripts/` |
| `scripts/lib/logging.sh` | Shared color vars + `log_info`/`log_warn`/`log_error`/`log_step` printf helpers (issue #255 Phase 4a). Sourced by `setup.sh`, `verify-env.sh`, `db-reset.sh`, `sandbox-bootstrap.sh` |
| `scripts/lib/assertions.sh` | Shared `PASS`/`FAIL`/`WARN` counters + `pass`/`fail`/`warn` helpers (issue #255 Phase 4a). Depends on `logging.sh` color vars. Sourced by `test.sh`, `verify-env.sh` |
| `scripts/lib/bot-allowlist.txt` | Canonical normalized bot identities for `pr-resolve-all.md` settle polling and Phase 4 auto-resolution (issue #326) |
| `scripts/lib/jq/*.jq` | Extracted jq filters (e.g. `relay-cycle-count.jq`); each has matching fixture pairs in `scripts/lib/jq/fixtures/` and is tested by `scripts/tests/jq-filters.bats` |
| `scripts/tests/*.bats` | Bats test suite (issue #255 Phase 4b, expanded by issue #280); each `.bats` file inlines the legacy test logic as a `_legacy_body()` shell function and invokes it via bats `run` inside a single `@test` block. No `scripts/test-*.sh` delegate layer remains. Run: `bats scripts/tests/`. CI installs bats via `apt-get` in `ci-tests.yml`. |

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
| `.pre-commit-config.yaml` | Template repo's own pre-commit hooks (shellcheck + actionlint; install once via `pre-commit install`). See ADR-017. |
| `.pre-commit-config.yaml.template` | Heavyweight scaffold for derived repos (linting, secrets); opt-in per ADR-013 |
| `docs/decisions/README.md` | ADR index, supersession discipline, what a well-documented ADR looks like |
| `docs/decisions/adr-template.md` | Architecture Decision Record template (with "When to write" header) |
| `docs/postmortems/README.md` | Postmortem index, when to write, ADR-vs-postmortem split, "What generalizes" promotion gate |
| `docs/postmortems/postmortem-template.md` | Postmortem / lessons-learned template (Trigger, Expected vs Actual, Root cause, What generalizes, Action items) |
| `.github/pull_request_template.md` | PR template with `## Plan` pointer (permalinks to original plan and revisions + 1–2 sentence summary; advisory per ADR-011), `## Plan revision sync` checkbox (advisory), required doc-sync checklist, and `## Sandbox dogfood evidence` section (two labels: `Sandbox issue:`, `Sandbox PR:`) required by ADR-029 for PRs that modify agent contracts, gate predicates, compliance schemas, or `.agents/.context/.github/agents` loaders |
| `docs/guides/agent-best-practices.md` | Token limits, session handoff, secrets, prompt caching, issue/PR granularity |
| `docs/guides/agents-md-section-redirects.md` | ADR-021 section-anchor redirect table (post-decomposition `AGENTS.md` citations) |
| `docs/guides/opportunity-feedback-examples.md` | Worked opportunity-note examples and 9-field schema rationale (pairs with `process_opportunity_feedback.md`) |
| `docs/guides/repo-orchestration-patterns-reference.md` | Long-form `P*` / `AP*` reference detail (pairs with slim `repo_orchestration_patterns.md` rule) |
| `docs/guides/subagent-bootstrap-reference.md` | Pass-back narrative, ghost-success, schema-variance detail (ADR-026; monolithic default per ADR-031) |
| `docs/guides/design-patterns.md` | Lead index for advisory code-layer design-pattern catalogs (`CAP`, `CP`, `CCP`, `CDP`, `CIP`) |
| `docs/guides/design-patterns-concurrency.md` | Concurrency pattern catalog with stable `CCP1`-`CCP8` citation handles |
| `docs/guides/design-patterns-data.md` | Data / persistence pattern catalog with stable `CDP1`-`CDP14` citation handles |
| `docs/guides/design-patterns-gof.md` | Gang of Four pattern catalog with stable `CP2`-`CP24` citation handles |
| `docs/guides/design-patterns-integration.md` | Integration / messaging pattern catalog with stable `CIP1`-`CIP11` citation handles |
| `docs/guides/design-patterns-post-gof.md` | Post-GoF pattern catalog with stable `CP25`-`CP34` citation handles |
| `docs/guides/multi-agent-coordination.md` | Multi-agent workflow guide |
| `docs/guides/optional-skills.md` | Optional external Claude Code skills (SOLID, everything-claude-code) |

### CI/CD Workflows

| File | Purpose | Customization Required |
|------|---------|------------------------|
| `ci-tests.yml` | Build, lint, test pipeline (customize for project) | Yes — add your commands |
| `lint-and-format.yml` | Markdown + script lint/format pass | None |
| `keep-warm.yml` | Prevents free-tier backend suspension | Set `BACKEND_URL` secret |
| `validate-connections.yml` | Daily backend/DB connectivity check | Set `BACKEND_URL` secret |
| `claude.yml` | Claude Code triggers (`@claude` mention + auto-review on PR open) | Set `ANTHROPIC_API_KEY` secret |
| `agent-assign-copilot.yml` | Gated Copilot PR assignment for `copilot:ready` issues | Set `CLAUDE_PAT` secret |
| `agent-auto-merge.yml` | Opt-in auto-merge via `auto-merge` label (CI green + threads resolved), with default bounded bot-review settle window and `auto-merge-fast` bypass label | Set `CLAUDE_PAT` secret |
| `agent-auto-ready.yml` | Marks Copilot PRs ready for review when implementation completes | None |
| `agent-advisory-review.yml` | Rolling advisory snapshots on draft/WIP PRs (`ai-review:live`); Cursor / Antigravity / Gemini | `CURSOR_API_KEY` and/or `GEMINI_API_KEY`; optional `ADVISORY_ANTIGRAVITY_ENABLED=true` |
| `agent-review-finalize.yml` | Final Feedback Inbox after implementation (`implementation-complete`); Cursor / Gemini | `CURSOR_API_KEY` and/or `GEMINI_API_KEY` (reuses advisory LLM runners) |
| `agent-postmerge-retro.yml` | Daily post-merge retro (06:00 UTC + dispatch): umbrella issue + draft fix PR; Cursor / Gemini | `CURSOR_API_KEY` and/or `GEMINI_API_KEY`; fix job adds `contents` + PR write |
| `agent-weekly-review.yml` | Weekly full-repo review (Sunday 07:00 UTC + dispatch): umbrella issue + draft fix PR; Cursor / Gemini | `CURSOR_API_KEY` and/or `GEMINI_API_KEY`; fix job adds `contents` + PR write |
| `agent-fix-reviews.yml` | Triggers Claude to run `pr-resolve-all.md` on review feedback | Set `ANTHROPIC_API_KEY` secret |
| `agent-multi-dispatch.yml` | Parallel Copilot fan-out with overlap-safety classifier | Set `CLAUDE_PAT` secret |
| `agent-parallelism-report.yml` | Cross-PR overlap classifier; posts a comment on every open PR | None |
| `agent-relay-reviews.yml` | Relays bot review comments to Copilot via `@copilot follow` | Set `CLAUDE_PAT` secret |
| `agent-release-slot.yml` | Releases Copilot slot + drains queue on PR close | Set `CLAUDE_PAT` secret |
| `auto-rebase-on-merge.yml` | Opt-in auto-rebase of overlapping PRs via `auto-rebase` label | Set `CLAUDE_PAT` secret |
| `backlog-to-issues.yml` | Materializes `.context/backlog.yaml` entries as GitHub issues | Set `CLAUDE_PAT` secret |
## Truth Hierarchy

See `AGENTS.md` §"Truth hierarchy" for the canonical definition. Summary:
`.context/**` > `docs/**` > codebase.

For live agent coordination on GitHub-connected work, ADR-025 narrows the
source-of-truth order to: issue body → PR body → latest `agent-state:v1`
comment → labels. In-tree `.context/**` remains canonical for rules,
decisions, durable lessons, and process constraints.

## Conventions

### GitHub template surfaces

Three locations — different consumers; do not duplicate across them:

| Location | Consumer | Purpose |
|---|---|---|
| `.github/ISSUE_TEMPLATE/*.md` | Human issue chooser (GitHub UI) | Structured issue intake (`bug_report`, `feature_request`, `agent_init`) |
| `.github/pull_request_template.md` | Human PR opener (GitHub UI) | Full Judge-gated PR body (plan pointer, compliance, doc sync, sandbox evidence) |
| `.github/templates/*.md` | Workflow scripts (`gh issue create` / `gh pr create`) | Slim automation bodies with `{{placeholders}}` (post-merge retro umbrella + fix PR) |
| `.github/PLAN_TEMPLATE.md` | Issue/PR comments | Implementation plan pasted before coding (ADR-011) |

Agents creating issues/PRs via API use the matching surface per [`.github/pull_request_template.md`](.github/pull_request_template.md) and [`.github/prompts/pr-resolve-all.md`](.github/prompts/pr-resolve-all.md). Retro automation uses `.github/templates/` only — not mirrored into `ISSUE_TEMPLATE/`.

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

# Check environment and placeholder sanity
./scripts/verify-env.sh

# Validate shell scripts (if shellcheck installed)
shellcheck install.sh test.sh

# Local pre-commit run (template repo only — ADR-017). One-time:
#   pip install pre-commit && pre-commit install
pre-commit run --all-files

# PR review-loop rolling metrics (last 14 days)
bash scripts/pr-iteration-stats.sh --window 14

# Pre-push review (Critic + lint + ./test.sh on the working-tree diff)
# SHOULD before `git push` on non-trivial diffs; MUST for DevOps on
# shell/workflow changes. See `.context/rules/process_work_style.md` and
# .agents/devops.md.
#
# This is a Markdown prompt — not a shell script — so it must be
# consumed by an agent runtime, not executed with bash. To dispatch:
#   - In Claude Code:  @claude follow .github/prompts/pre-push-review.md
#   - In Copilot:      @copilot follow .github/prompts/pre-push-review.md
#   - In Cursor:       open the prompt and run it manually
# To preview the procedure locally without dispatching an agent:
cat .github/prompts/pre-push-review.md

# List all markdown files
find . -name "*.md" -not -path "./.git/*" | head -20

# Verify context pack structure
ls -la .context/

# Verify config templates
ls -la config/
```

## Using This Template

### Template vs. Fork: choosing how to start

**Default: "Use this template" → Create new repository.**

- Gives the new repo a fresh git history; no perpetual "X commits behind" UI clutter.
- Doesn't pollute `ai-repo-template`'s fork count.
- Mode classification uses [`.github/prompts/repo-onboarding.md`](.github/prompts/repo-onboarding.md) Step 1 — "Use this template" create a repo with a new name, so Mode B bootstrap fires correctly. A fork keeps the name `ai-repo-template` unless explicitly renamed, which can cause Mode A misclassification.
- A POC or new project isn't conceptually a fork — a fork relationship implies intent to merge changes back upstream.

**Use fork only when:**

- Contributing a fix or feature back upstream to `ai-repo-template`, or
- Maintaining a long-lived "downstream variant" that explicitly wants to track upstream commits semi-automatically.

**Pulling future template improvements into a template-created repo:**

Add the upstream remote and fetch once:

```bash
git remote add upstream https://github.com/mikejmckinney/ai-repo-template.git
git fetch upstream
```

Browse available commits with `git log --oneline --cherry-pick --right-only HEAD...upstream/main`, then cherry-pick specific ones (e.g., `git cherry-pick <commit-hash>`). Most template changes will be project-specific noise to a downstream project — selective cherry-picking is safer than a full merge (which can re-introduce template placeholders or overwrite project-specific customizations).

### For new repositories

1. Create the repo with "Use this template" (or copy files if you need a one-off starting point).
2. Run [`.github/prompts/repo-onboarding.md`](.github/prompts/repo-onboarding.md).

### For Codespaces

1. Link this repo in GitHub Codespaces settings
2. Extensions install automatically via `install.sh`
3. AI prompts copied to workspace

### First-time repo initialization

After creating a repo from this template, paste this prompt into a GitHub issue and assign it to your AI agent:

```markdown
Truth hierarchy:
1) ./.context/** (canonical project direction)
2) ./docs/** (supporting detail)
3) codebase (implementation reality)

read and follow .github/prompts/repo-onboarding.md
```

### New agent session (continue work on an existing repo)

Use this prompt to onboard a fresh agent session onto in-flight work:

```markdown
read and follow .github/prompts/repo-onboarding.md
```

This protocol keeps live task state in GitHub while preserving in-tree rules and durable retrospective lessons.

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
