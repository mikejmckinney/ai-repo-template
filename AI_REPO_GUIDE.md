<!-- TEMPLATE_PLACEHOLDER: Regenerate this guide for a derived project. -->

# AI_REPO_GUIDE.md

> Canonical command and layout reference for agents working in this template.
> Last verified: 2026-07-14.

## Overview

This repository is a Codespaces-first template for AI-assisted software delivery.
ADR-031 defines the active execution model:

- one monolithic implementing agent;
- CI and lint as blocking pre-merge controls;
- optional `ai-review:live` advisory snapshots during implementation;
- automatic daily post-merge and weekly full-repository review;
- OpenCode `local-consensus` as the sole opt-in multi-model mechanism.

## Commands

```bash
./test.sh
bats --jobs 4 scripts/tests/
bash scripts/lint-shell-conventions.sh scripts/
git diff --check
```

Run `bash install.sh` only when testing the Codespaces bootstrap/install surface.

## Repository Layout

| Path | Purpose |
|---|---|
| `AGENTS.md` | Always-loaded operating contract |
| `README.md` | Human-facing overview and setup |
| `.context/` | Current project state, roadmap, benchmark results, and design context |
| `docs/decisions/` | Durable architecture decisions; ADR-031 owns the execution model |
| `docs/guides/agent-pipeline.md` | Active workflow and trigger behavior |
| `.github/prompts/shared-review-lenses.md` | Canonical criteria for advisory and retro review |
| `.github/prompts/pr-advisory-review.md` | Optional in-progress PR advisory output contract |
| `.github/prompts/post-merge-retro.md` | Daily merged-PR review contract |
| `.github/prompts/weekly-repo-review.md` | Weekly full-repository review contract |
| `.github/workflows/agent-advisory-review.yml` | Label-gated, non-blocking sticky advisory comment |
| `.github/workflows/agent-postmerge-retro.yml` | Scheduled daily retro and draft-fix lifecycle |
| `.github/workflows/agent-weekly-review.yml` | Scheduled weekly scan and draft-fix lifecycle |
| `.github/agent-runtime/` | Locked OpenCode dependencies and review/fix permission profiles |
| `.opencode/skills/local-consensus/` | Explicit independent advisor/consensus mechanism |
| `scripts/workflows/advisory-review/` | Advisory provider adapters and comment upsert |
| `scripts/workflows/postmerge-retro/` | Daily evidence, analysis, umbrella, and fix adapters |
| `scripts/workflows/weekly-review/` | Weekly scan, umbrella, and fix adapters |
| `scripts/workflows/lib/` | Shared provider, evidence, priority, and lifecycle helpers |
| `scripts/checks/` | Numbered modules sourced by `test.sh` |
| `scripts/tests/` | Focused Bats tests |
| `install.sh` | Codespaces bootstrap and template-file copy inventory |

## Review Lifecycle

### Advisory

Apply `ai-review:live` to an open same-repository PR to opt in. Draft PRs are
supported. Each qualifying push cancels an older in-flight run and updates one
comment marked `<!-- ai-advisory-review:v1 -->`. Advisory cannot submit a formal
review, push commits, mutate labels, resolve threads, change readiness, or block
merge. `ai-review:full` increases context depth but does not change authority.

### Daily Retro

The daily workflow reviews PRs merged to `main` in its evidence window, creates or
updates one dated umbrella issue, and may open a draft fix PR. It is not a
pre-merge gate.

### Weekly Review

The weekly workflow scans current `main`, creates or updates one ISO-week umbrella,
and may open a draft fix PR. It remains a full-repository scan rather than a
weekly aggregation of merged PRs.

### Local Consensus

Use the `local-consensus` skill only when requested or when consequential
uncertainty warrants independent model perspectives. It is not the default
implementation path.

## Workflow Verification

Changes to `schedule`, `workflow_dispatch`, `push`, `workflow_run`,
`pull_request_target`, review, issue-comment, or other default-branch-only
triggers require sandbox verification. Follow
`docs/guides/sandbox-verification.md` and record real run/artifact links.

## Authentication

Inside Codespaces, the injected `GITHUB_TOKEN` may not access the sibling sandbox.
Use command-local `GH_TOKEN="$GH_PAT"` with `GITHUB_TOKEN` unset when the configured
user PAT is required. Never commit tokens.

OpenCode workflow agents use only `OPENCODE_GITHUB_TOKEN`, a dedicated read-only
fine-grained token. Set `OPENROUTER_API_KEY` for the public-CI model cascade.
Interactive OpenCode may use ChatGPT Plus/Pro authentication for Sol, but that
personal OAuth credential is not forwarded to public GitHub Actions. Workflows
install the pinned OpenCode runtime from `.github/agent-runtime/package-lock.json`
on GitHub-managed `ubuntu-latest`.

## Documentation Synchronization

- Build, test, install, layout, and troubleshooting changes update this guide.
- Review lifecycle changes update ADR-031 and `docs/guides/agent-pipeline.md`.
- Workflow trigger changes update the pipeline and sandbox guides plus tests.
- File inventory changes update `install.sh` and the owning check module.

## Known Warnings

`./test.sh` may report advisory warnings for stale session summaries or downstream
template placeholders. A non-zero failure count is blocking; warnings must still
be reviewed for relevance to the active task.
