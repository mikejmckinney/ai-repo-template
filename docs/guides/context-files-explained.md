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
│       ├── roadmap.md ─────── Completed phases + future work │
│       ├── state/ ─────────── GitHub live-state reference    │
│       ├── sessions/ ───────── Historical records only       │
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
| `roadmap.md` | "What phases shipped and what issue-backed work remains?" | Program history and future work | When phases or tracked work change |
| GitHub issue/PR + latest `agent-state:v1` comment | "What am I working on?" | Live coordination | During development |
| `state/*.md` | "How is GitHub live state represented?" | Reference guidance and comment template | When coordination policy changes |
| `sessions/*.md` | "What historical retrospective records remain?" | Historical evidence only | Not updated for normal task state |
| `vision/**` | "What should this look like?" | Design artifacts | When designs change |

### The Key Distinction: GitHub State vs Durable Knowledge

| GitHub issue/PR + `agent-state:v1` comment | Repository durable knowledge |
|---------------------------------------------|------------------------------|
| Task contract, implementation evidence, and mutable baton | ADRs, postmortems, and operating policy |
| Status, blockers, next actions, handoff, and completed outcome | Decisions or incidents that generalize beyond one task |
| Updated during development and closeout | Updated only when the durable artifact is justified |

**Example**:
- A task "Implement auth" might span several agent sessions.
- The latest `agent-state:v1` comment tracks cumulative live progress.
- The PR records the completed outcome; an ADR or postmortem captures only
  knowledge that generalizes beyond that PR.

## Subdirectory READMEs

These are NOT redundant with project docs—they explain their specific directories:

| File | Purpose |
|------|---------|
| `.context/state/README.md` | ADR-025 live-state split, legacy compatibility, and comment template |
| `.context/sessions/README.md` | Historical archive policy and GitHub-state pointer |
| `scripts/README.md` | Available scripts and usage |
| `docs/README.md` | Documentation structure |

## Reading Order for Agents

1. `AI_REPO_GUIDE.md` — Quick reference
2. `.context/00_INDEX.md` — Project overview
3. Assigned GitHub issue/PR + latest `agent-state:v1` comment — Find active task(s)
4. Load roadmap, vision files, or historical archives only when their domain
   intersects the task

## Why some things look duplicated but aren't

A recurring question is whether duplicated-looking docs should be merged, or whether root-level scripts and `CLAUDE.md` should move into subdirectories. Some of these layouts are load-bearing; others are convention. Here's the breakdown:

### Hard constraints (moving would break something)

| File / location | Why it has to stay |
|-----------------|--------------------|
| `README.md` + `AI_REPO_GUIDE.md` (not merged) | Different audiences. README is verbose human onboarding; AI_REPO_GUIDE is token-optimized for agents. Merging was explicitly rejected in `docs/decisions/adr-001-context-pack-structure.md` as "unwieldy". |
| `docs/` + `.context/` (not merged) | Different audiences **and** a truth hierarchy. `AGENTS.md` codifies `.context/** > docs/** > codebase` for conflict resolution. `.context/` is canonical project memory for agents; `docs/` is human reference. ADR-001 rejected reusing `docs/` for agent context because it "mixes human docs with agent context, no clear priority." |
| `install.sh` at the repo root | GitHub Codespaces' "Dotfiles" feature expects the bootstrap script at the repo root and runs it automatically when a Codespace starts. Platform convention, not a repo choice. |
| `test.sh` at the repo root | Invoked by `.github/workflows/ci-tests.yml` as `./test.sh` and referenced from `README.md`, `AI_REPO_GUIDE.md`, and the DevOps specialty guidance. `scripts/` is scoped to post-clone project customization and supporting automation. |

### Soft convention (could move, we keep it where it is)

| File / location | Why we keep it where it is |
|-----------------|---------------------------|
| `CLAUDE.md` at the repo root | Claude Code's memory loader auto-discovers **either** `./CLAUDE.md` or `./.claude/CLAUDE.md`. Root is the `/init` default and keeps the pointer visible next to `AGENTS.md`, `AI_REPO_GUIDE.md`, and `README.md`. |

**Rule of thumb**: before merging or moving `docs/`, `.context/`, `README.md`, `AI_REPO_GUIDE.md`, `install.sh`, or `test.sh`, read ADR-001 and ADR-003 first. `CLAUDE.md` is flexible — move it if it helps your repo, but confirm the chosen location is on Anthropic's [CLAUDE.md location table](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files).

## When to Update Each File

| Event | Files to Update |
|-------|-----------------|
| Project structure changes | `AI_REPO_GUIDE.md`, `README.md` |
| Starting a new task | Post or update the latest `agent-state:v1` issue/PR comment |
| Making progress on task | Update the latest `agent-state:v1` issue/PR comment |
| PR merge/closeout | Finalize the PR body and latest `agent-state:v1` comment |
| Durable technical decision or formal incident | Add an ADR or postmortem |
| Making a design decision | Add to `docs/design/` or a project-specific equivalent; optionally create an ADR |
| Phase complete | Update `roadmap.md` |
| Adding a repository-wide constraint | Update `AGENTS.md`; keep domain-specific rules near the code or durable docs they govern |
