# Context Files Explained

> **Purpose**: Understand the different documentation files in this template and when to use each.

## Overview

This template has multiple documentation files that serve different audiences and purposes. This guide explains how they relate.

## File Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    For Humans                                │
│  README.md                                                   │
│  "What is this project? How do I set it up?"                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    For AI Agents                             │
│  AI_REPO_GUIDE.md                                           │
│  "Quick reference: commands, structure, conventions"        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Context Pack (.context/)                    │
│                                                              │
│  00_INDEX.md ─────── The Map (start here)                   │
│       │                                                      │
│       ├── roadmap.md ─────── The Plan (project phases)      │
│       ├── rules/ ─────────── Constraints (never violate)    │
│       ├── state/ ─────────── Current Work (tasks)           │
│       ├── sessions/ ───────── History (lessons learned)     │
│       └── vision/ ─────────── Design (mockups, diagrams)    │
└─────────────────────────────────────────────────────────────┘
```

## File Comparison

### Project Documentation

| File | Audience | Purpose | Update Frequency |
|------|----------|---------|------------------|
| `README.md` | Humans | Project intro, setup, features, badges | When features change |
| `AI_REPO_GUIDE.md` | Agents | Commands, structure, conventions | When structure changes |
| `docs/**` | Humans | Deep documentation, guides, ADRs | As needed |

**Key Distinction**: README.md can be verbose with images and badges. AI_REPO_GUIDE.md is concise to save tokens.

### Context Pack Files

| File | Question It Answers | Scope | Update Frequency |
|------|---------------------|-------|------------------|
| `00_INDEX.md` | "What's in this context pack?" | Project overview | When context structure changes |
| `roadmap.md` | "What are we building and in what order?" | Project phases | When phases complete/change |
| `rules/*.md` | "What rules must I follow?" | Domain constraints | Rarely |
| `state/task_*.md` | "What am I working on?" | Current tasks | During development |
| `sessions/*.md` | "What happened before?" | Session history | End of each session |
| `vision/**` | "What should this look like?" | Design artifacts | When designs change |

### The Key Distinction: Tasks vs Sessions

| `state/task_*.md` | `sessions/*.md` |
|-------------------|-----------------|
| **What** you're doing | **What happened** and **what you learned** |
| Task-scoped (tracks one task) | Session-scoped (tracks one work session) |
| Progress checklist | Decisions and failures |
| "Continue from step 3" | "Don't try approach X, it failed" |
| May span multiple sessions | Captured at end of each session |

**Example**:
- A task "Implement auth" might take 3 sessions
- `task_auth.md` tracks cumulative progress across all 3
- `sessions/` captures what happened in each individual session

## Subdirectory READMEs

These are NOT redundant with project docs—they explain their specific directories:

| File | Purpose |
|------|---------|
| `.context/state/README.md` | How to create and manage task files |
| `.context/sessions/README.md` | How to create session summaries |
| `scripts/README.md` | Available scripts and usage |
| `config/README.md` | Platform recommendations |
| `docs/README.md` | Documentation structure |

## Reading Order for Agents

1. `AI_REPO_GUIDE.md` — Quick reference
2. `.context/00_INDEX.md` — Project overview
3. `.context/state/` — Find active task(s)
4. `.context/sessions/latest_summary.md` — Recent history
5. Load other files on-demand (rules, vision) as needed

## Why some things look duplicated but aren't

A recurring question is whether duplicated-looking docs should be merged, or whether root-level scripts and `CLAUDE.md` should move into subdirectories. Some of these layouts are load-bearing; others are convention. Here's the breakdown:

### Hard constraints (moving would break something)

| File / location | Why it has to stay |
|-----------------|--------------------|
| `README.md` + `AI_REPO_GUIDE.md` (not merged) | Different audiences. README is verbose human onboarding; AI_REPO_GUIDE is token-optimized for agents. Merging was explicitly rejected in `docs/decisions/adr-001-context-pack-structure.md` as "unwieldy". |
| `docs/` + `.context/` (not merged) | Different audiences **and** a truth hierarchy. `AGENTS.md` codifies `.context/** > docs/** > codebase` for conflict resolution. `.context/` is canonical project memory for agents; `docs/` is human reference. ADR-001 rejected reusing `docs/` for agent context because it "mixes human docs with agent context, no clear priority." |
| `install.sh` at the repo root | GitHub Codespaces' "Dotfiles" feature expects the bootstrap script at the repo root and runs it automatically when a Codespace starts. Platform convention, not a repo choice. |
| `test.sh` at the repo root | Invoked by `.github/workflows/ci-tests.yml` as `./test.sh`, referenced from `README.md`, `AI_REPO_GUIDE.md`, `CLAUDE.md`, `.context/rules/agent_ownership.md`, and the devops role files. `scripts/` is scoped to **post-clone project customization** (`setup.sh`, `verify-env.sh`) — a different role from template-level bootstrap and integrity tooling. |

### Soft convention (could move, we keep it where it is)

| File / location | Why we keep it where it is |
|-----------------|---------------------------|
| `CLAUDE.md` at the repo root | Claude Code's memory loader auto-discovers **either** `./CLAUDE.md` **or** `./.claude/CLAUDE.md` — see the ["Choose where to put CLAUDE.md files" table in the memory docs](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files). Both locations work for the standalone CLI and for `anthropics/claude-code-action@v1` (the Action runs the CLI under the hood). We keep it at the root because it's the `/init` default and it sits visibly next to `AGENTS.md` / `AI_REPO_GUIDE.md` / `README.md`. Moving it to `.claude/CLAUDE.md` would be functionally equivalent; `.claude/agents/**` (the 9 role subagent registrations from ADR-003) is a separate slot and can coexist with a `.claude/CLAUDE.md`. |

**Rule of thumb**: before merging or moving `docs/`, `.context/`, `README.md`, `AI_REPO_GUIDE.md`, `install.sh`, or `test.sh`, read ADR-001 and ADR-003 first. `CLAUDE.md` is flexible — move it if it helps your repo, but confirm the chosen location is on Anthropic's [CLAUDE.md location table](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files).

## When to Update Each File

| Event | Files to Update |
|-------|-----------------|
| Project structure changes | `AI_REPO_GUIDE.md`, `README.md` |
| Starting a new task | Create `state/task_<id>.md` |
| Making progress on task | Update `state/task_<id>.md` |
| Ending a coding session | Update `sessions/latest_summary.md` |
| Making a design decision | Add to `sessions/`, optionally create ADR |
| Phase complete | Update `roadmap.md` |
| Adding a domain constraint | Create `rules/domain_<area>.md` |
