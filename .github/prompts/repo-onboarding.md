---
description: Onboard an AI agent to a repo (template-clone or existing); produce repo brief.
agent: agent
---

# Repository Onboarding Prompt

You are an AI agent onboarding to an existing codebase. Build an accurate mental model **before** making changes, identify the correct role or dispatch path, and implement only when your role owns that slice.

## Core principles

- **Do NOT guess** APIs, file contents, or behavior. Verify in the repo.
- **Prefer small, reversible changes**. Match existing style.
- **Before editing**: summarize understanding → propose a plan → name files to touch.
- **After editing**: rationale, diff, and exact test commands.

## How to execute

| Step | When |
|---|---|
| **Step 1** — Classify mode | Always first |
| **Step 2** — Bootstrap `2.1`–`2.9` | Mode B only |
| **Step 3** — Orient `3.1`–`3.6` | All modes |
| **Step 4** - implementation (Optional) | Only if this session also assigns implementation work |

> **New project from this ai-repo-template?** Read [Template vs. Fork](../../AI_REPO_GUIDE.md#template-vs-fork-choosing-how-to-start) before classifying. "Use this template" (not Fork) is the default — a fork named `ai-repo-template` classifies as Mode A and skips bootstrap incorrectly.

---

## Step 1 — Classify mode and pick mode

Run these checks once and record the result. The mode determines whether
template info should be retained (template repo itself) or replaced (derived repo).

- **Mode A — Template repo itself.** `git remote -v` (or folder name) shows this repo *is* `ai-repo-template`. `README.md`, `AI_REPO_GUIDE.md`, are the template's canonical docs — **do not regenerate**. Skip Step 2, continue to step 3.
- **Mode B — Derived repo, bootstrap not yet run.** Any of:
  - `README.md` or `AI_REPO_GUIDE.md` contains `TEMPLATE_PLACEHOLDER`.
  - `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`.
  - `./scripts/verify-env.sh` reports `PLACEHOLDER_COUNT > 0` (line `N files still contain TEMPLATE_PLACEHOLDER` with N > 0). Catches partial-bootstrap states across `.context/**`, `docs/**`, `scripts/**`, or workflows even when README/AI_REPO_GUIDE look clear (`verify-env.sh` excludes infrastructure and three bootstrap state files via `_PLACEHOLDER_LEGIT` / `_PLACEHOLDER_EXCLUDE`).
  - Resettable live context still describes `ai-repo-template` or template-only diagrams exist (e.g. `.context/00_INDEX.md` names `ai-repo-template`, `.context/roadmap.md` starts with `# ai-repo-template Roadmap`, or `.context/vision/architecture/multi-agent-flow.md` / `state-surfaces.md` exist).
  
  This catches repos that already cleared the obvious placeholders but have not actually completed the Mode B reset/repopulation sequence. Do the work in Step 2.
- **Mode C — Derived repo, already customized.** No Mode B signals and repo is not `ai-repo-template`. Skip Step 2, continue to step 3.

If ambiguous (e.g. `ai-repo-template` remote *and* a stray `TEMPLATE_PLACEHOLDER`), prefer **Mode A** — never regenerate the template's own docs. Note ambiguity in the Step 3.1 status line.

---

## Step 2 — Bootstrap (Mode B only)

| Step | Action |
|---|---|
| **2.1** | Reset and repopulate [README.md](/README.md), [00_INDEX.md](/.context/00_INDEX.md), [roadmap.md](/.context/roadmap.md), [.context/vision/README.md](/.context/vision/README.md), and [DESIGN.md](/DESIGN.md) with project-specific content (delete template stub language, preserve useful structure), then regenerate [AI_REPO_GUIDE.md](/AI_REPO_GUIDE.md) from the repo's real assets (`.context/*`, `./docs/*`, source, etc.). This file is canonical for agents and must not retain template placeholder language. |
| **2.2** | Customize [docs/FAQ.md](/docs/FAQ.md) — remove `Template:`-prefixed entries; add project Q&A. |
| **2.3** | Delete `.context/vision/architecture/multi-agent-flow.md` and `.context/vision/architecture/state-surfaces.md` (template-only diagrams). |
| **2.4** | Reset `.context/sessions/latest_summary.md` body to a single `No sessions yet` line (keep `TEMPLATE_PLACEHOLDER` marker until first durable entry). Keep `.context/state/agent_state_comment_template.md`, `.context/sessions/feedback_template.md`, and directory `README.md` files. |
| **2.5** | Re-run `./scripts/verify-env.sh`; fix blocking issues. |
| **2.6** | Run **Bootstrap verification** (script below). On any `FAIL`, resume at the **numbered step** that owns the failure. |

### Bootstrap verification (2.6)

Skip entirely for Mode A and C. For Mode B derived repos:

```bash
REPO_ID="$(git remote get-url origin 2>/dev/null || basename "$PWD")"
if printf '%s\n' "$REPO_ID" | grep -qE '(^|[:/])(mikejmckinney/)?(ai-repo-template|dotfiles)(\.git)?$'; then
  echo "SKIP: Mode A template repo; Mode B cleanup signals do not apply"
else
  # Signal 1 - README and AI_REPO_GUIDE no longer carry the template stub.
  grep -qE 'TEMPLATE_PLACEHOLDER' README.md AI_REPO_GUIDE.md 2>/dev/null && echo "FAIL: stub README or AI_REPO_GUIDE still has TEMPLATE_PLACEHOLDER"

  # Signal 2 - issue-template config points at the real repo.
  grep -qE 'PLEASE_UPDATE_THIS/URL' .github/ISSUE_TEMPLATE/config.yml 2>/dev/null && echo "FAIL: ISSUE_TEMPLATE/config.yml still has PLEASE_UPDATE_THIS/URL"

  # Signal 3 - verify-env no longer reports unexpected repo-wide TEMPLATE_PLACEHOLDER markers.
  ./scripts/verify-env.sh 2>&1 | grep -qE '[1-9][0-9]* files still contain TEMPLATE_PLACEHOLDER' \
    && echo "FAIL: verify-env still reports unexpected TEMPLATE_PLACEHOLDER markers"

  # Signal 4 - resettable context files are no longer generic Mode B stubs.
  grep -qE 'TEMPLATE_PLACEHOLDER|\[TBD\]' .context/00_INDEX.md .context/roadmap.md .context/vision/README.md DESIGN.md 2>/dev/null \
    && echo "FAIL: resettable context files still contain generic Mode B stub markers"

  # Signal 5 - resettable context files and template-only diagrams no longer reflect ai-repo-template.
  if grep -qF '**Project Name**: `ai-repo-template`' .context/00_INDEX.md 2>/dev/null \
    || grep -qF 'A Codespaces-first repository template for AI-assisted software delivery.' .context/00_INDEX.md 2>/dev/null \
    || grep -qF '# ai-repo-template Roadmap' .context/roadmap.md 2>/dev/null \
    || grep -qF 'This repo is a process/template project, not a product UI' .context/vision/README.md 2>/dev/null \
    || grep -qF "template repo's design and workflow diagrams" .context/vision/README.md 2>/dev/null \
    || test -e .context/vision/architecture/multi-agent-flow.md \
    || test -e .context/vision/architecture/state-surfaces.md; then
    echo "FAIL: resettable context files or template-only diagrams still reflect ai-repo-template"
  fi
fi
```

If any signal fires, return to Step 2 and finish the
cleanup before continuing.

Use `grep -E` (extended regex) rather than `grep` with `\|` - the
basic-regex alternation is not portable across all `grep`
implementations.

When 2.6 passes (no `FAIL` lines), continue to **Step 3**.

---

## Step 3 — Orient (all modes)

### 3.1 — Quick context check

Do a fast sanity pass so the rest of this step has accurate state:

1. Read the assigned GitHub issue body to understand the durable task or
  feature contract.
2. Read the linked PR, if one exists, for implementation scope and
  verification state.
3. Read the latest `agent-state:v1` issue/PR comment and labels for live
  coordination, blockers, and handoff.
4. Read `.context/00_INDEX.md` to locate relevant rules and constraints.
5. Run `git status` and `./scripts/verify-env.sh` to confirm the working
   tree and environment are stable.
6. Skim `.context/sessions/latest_summary.md` for durable lessons from
  recent work.
7. Report a one-line status:
   `"Context reviewed. Onboarding Mode: <A|B|C>. Current task is <name>. Environment is <Stable|Unstable: <reason>>. Ready for instructions."`

**"Stable" means all of:**

- `git status` is clean, or only contains expected agent edits.
- `./scripts/verify-env.sh` exits 0 **and** reports no onboarding-blocking
  WARNs. In particular, treat any `TEMPLATE_PLACEHOLDER`-still-present
  WARN as **Unstable** when running in a derived (non-template) repo -
  it means docs haven't been regenerated and replaced yet (step 2 is incomplete).
  (`verify-env.sh` emits a distinct WARN for the 3 bootstrap state files;
  that warn is **non-blocking** - expected during bootstrap, actionable once
  the first real task/session has landed and those markers should be cleared.)
- Steps 1-6 above completed without missing-file errors. (`bash test.sh`
  is the deeper structural check; run it later in Step 3 if you want
  full coverage.)

Otherwise report **Unstable** and name the specific failure or blocking
WARN (e.g. `Unstable: verify-env.sh exited 1 - missing PYTHONPATH`, or
`Unstable: verify-env.sh warned TEMPLATE_PLACEHOLDER remains in 3 files`).

If any of these files are missing, note it explicitly - do not invent
content, and do not block on it. Continue with the rest of this step.

### 3.2 — Key documentation

- [ ] `README.md`
- [ ] `00_INDEX.md`
- [ ] `AI_REPO_GUIDE.md` (if present — canonical)
- [ ] `roadmap.md`
- [ ] `docs/**`

### 3.3 — Map the codebase

Use search and file exploration (not linear reading) to identify:

#### Directory Structure

```text
Top-level directories and their purposes:
|-- src/           # <purpose>
|-- tests/         # <purpose>
|-- docs/          # <purpose>
`-- ...
```

#### Entry Points

- **Web apps**: Main server file, routers, app bootstrap
- **CLI**: Bin directory, command registry
- **Libraries**: Public API surface, exports

#### Test Infrastructure

- Test framework used
- Test file locations
- How to run tests

### 3.4 — Build commands

Find and verify these commands from `package.json`, `Makefile`, `pyproject.toml`, etc.:

| Task | Command | Verified |
|------|---------|----------|
| Install dependencies | | [ ] |
| Build | | [ ] |
| Test | | [ ] |
| Lint | | [ ] |
| Type check | | [ ] |

### 3.5 — Repo brief

Output a structured summary:

```markdown
## What This Repo Does
<1-3 sentences>

## Tech Stack
- Language:
- Framework:
- Build tool:
- Test framework:

## Folder Map
- `/src` -
- `/tests` -
- `/docs` -

## Key Entry Points
- Main:
- CLI:
- API:

## Configuration Files
- Build config:
- Lint config:
- CI config:

## How to Run Locally
<commands>

## How to Test
<commands>

## Known Risks/Gotchas
- <item>
```

### 3.6 — Finalize `AI_REPO_GUIDE.md` (once)

Create or update from real repo assets (`.context/**`, `docs/**`, codebase):

If `/AI_REPO_GUIDE.md` does NOT exist, create it with:

- Overview (what this is)
- Quickstart (run/test commands)
- Folder map + key entry points
- Conventions (lint/format, branching, commit style)
- Where to add things (routes, services, components)
- Troubleshooting / common gotchas

If it exists, verify accuracy and update if needed.

Do not retain template placeholder language in derived repos. Further `AI_REPO_GUIDE.md` edits during implementation follow [`.context/rules/process_doc_maintenance.md`](../../.context/rules/process_doc_maintenance.md) triggers only.

---

## Step 4 (Optional) — Clarify, Implement, Deliver

Use only when this onboarding session **also** assigns implementation. Otherwise skip.

Start [`op-issue-workflow.md`](op-issue-workflow.md)

---

## Verification Checklist

Before considering the task complete:

- [ ] All tests pass
- [ ] Linting passes
- [ ] Build succeeds
- [ ] Changes are minimal (no unrelated modifications)
- [ ] Docs updated if behavior changed
- [ ] `AI_REPO_GUIDE.md` is accurate
