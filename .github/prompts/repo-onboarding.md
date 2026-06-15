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

## How to execute (linear — no yo-yo)

Read top to bottom. Do not jump between unrelated sections.

| Step | When |
|---|---|
| **Step 1** — Classify mode, pick track | Always first |
| **Track B** — Bootstrap `B1`–`B9` | Mode B only |
| **Track A** — Orient `A1`–`A7` | All modes (after Track B when Mode B) |
| **Clarify / Implement / Deliver** | Only if this session also assigns implementation work |

**Canonical references** (read from disk when a step names them):

| Concern | Canonical file |
|---|---|
| Mode A / B / C rules | [`.context/rules/process_template_detection.md`](../../.context/rules/process_template_detection.md) |
| Mode B stub file contents | [`.github/prompts/repo-onboarding-stubs.md`](repo-onboarding-stubs.md) |
| Repo map / commands / conventions (output) | `AI_REPO_GUIDE.md` — finalize **once** at **A6** |
| Issue work after onboarding | [`op-issue-workflow.md`](op-issue-workflow.md) **Workflow Phase 0 — Session bootstrap** |

> **New project from this template?** Read [Template vs. Fork](../../AI_REPO_GUIDE.md#template-vs-fork-choosing-how-to-start) before classifying. "Use this template" (not Fork) is the default — a fork named `ai-repo-template` classifies as Mode A and skips bootstrap incorrectly.

---

## Step 1 — Classify mode and pick track

Run once. Record the mode in the **A1** status line.

- **Mode A — Template repo itself.** `git remote -v` (or folder name) shows this repo *is* `ai-repo-template` (or legacy `dotfiles`). README, `AI_REPO_GUIDE.md`, and `CLAUDE.md` are the template's canonical docs — **do not regenerate**. → **Track A** at A1.
- **Mode B — Derived repo, bootstrap not yet run.** Any of:
  - `README.md` or `AI_REPO_GUIDE.md` contains `TEMPLATE_PLACEHOLDER`.
  - `.github/ISSUE_TEMPLATE/config.yml` contains `PLEASE_UPDATE_THIS/URL`.
  - `./scripts/verify-env.sh` reports `PLACEHOLDER_COUNT > 0` (line `N files still contain TEMPLATE_PLACEHOLDER` with N > 0). Catches partial-bootstrap states across `.context/**`, `docs/**`, `scripts/**`, or workflows even when README/AI_REPO_GUIDE look clear (`verify-env.sh` excludes infrastructure and three bootstrap state files via `_PLACEHOLDER_LEGIT` / `_PLACEHOLDER_EXCLUDE`).
  - Resettable live context still describes `ai-repo-template` or template-only diagrams exist (e.g. `.context/00_INDEX.md` names `ai-repo-template`, `.context/roadmap.md` starts with `# ai-repo-template Roadmap`, or `.context/vision/architecture/multi-agent-flow.md` / `state-surfaces.md` exist).
  → **Track B** at B1, then **Track A** at A1.
- **Mode C — Derived repo, already customized.** No Mode B signals and repo is not `ai-repo-template`. → **Track A** at A1.

If ambiguous (e.g. `ai-repo-template` remote *and* a stray `TEMPLATE_PLACEHOLDER`), prefer **Mode A** — never regenerate the template's own docs. Note ambiguity in the A1 status line.

---

## Track B — Bootstrap (Mode B only)

Read [`.context/rules/process_template_detection.md`](../../.context/rules/process_template_detection.md) first. Bullets below are a **non-canonical recap**; stubs are **only** in [`repo-onboarding-stubs.md`](repo-onboarding-stubs.md).

| Step | Action |
|---|---|
| **B1** | Replace `README.md` with project-specific content (delete template stub language; preserve useful structure). |
| **B2** | Replace `TEMPLATE_PLACEHOLDER` repo-wide **except** `.context/sessions/latest_summary.md` (keeps marker until first retrospective; `verify-env.sh` excludes it). Replace `PLEASE_UPDATE_THIS/URL` in `.github/ISSUE_TEMPLATE/config.yml` with `owner/repo` from `git remote -v`. |
| **B3** | Extend [`.context/rules/agent_ownership.md`](../../.context/rules/agent_ownership.md) with real source paths. **Keep** template-governance roles (Analyst / Architect / PM / QA / DevOps / Docs / Judge / Critic). |
| **B4** | Customize `docs/FAQ.md` — remove `Template:`-prefixed entries; add project Q&A. |
| **B5** | Restore four resettable files from [`repo-onboarding-stubs.md`](repo-onboarding-stubs.md): `.context/00_INDEX.md`, `.context/roadmap.md`, `.context/vision/README.md`, `DESIGN.md`. Delete `.context/vision/architecture/multi-agent-flow.md` and `.context/vision/architecture/state-surfaces.md` (template-only diagrams). |
| **B6** | Repopulate those four files with project-specific content — including product design direction in `DESIGN.md` — before frontend work or **A6** `AI_REPO_GUIDE.md` finalization. Bootstrap is not complete until `DESIGN.md` is customized and mockups or architecture artifacts exist under `.context/vision/`. |
| **B7** | Reset `.context/sessions/latest_summary.md` body to a single `No sessions yet` line (keep `TEMPLATE_PLACEHOLDER` marker until first durable entry). Keep `.context/state/agent_state_comment_template.md`, `.context/sessions/feedback_template.md`, and directory `README.md` files. Do not recreate repo-local claim boards. |
| **B8** | Re-run `./scripts/verify-env.sh`; fix blocking issues. |
| **B9** | Run **Bootstrap verification** (script below). On any `FAIL`, resume at the **numbered B step** that owns the failure — do not use unnamed "Phase 0" jumps. |

### Bootstrap verification (B9)

Skip entirely for Mode A. For Mode B / C derived repos:

```bash
REPO_ID="$(git remote get-url origin 2>/dev/null || basename "$PWD")"
if printf '%s\n' "$REPO_ID" | grep -qE '(^|[:/])(mikejmckinney/)?(ai-repo-template|dotfiles)(\.git)?$'; then
  echo "SKIP: Mode A template repo; Mode B cleanup signals do not apply"
else
  grep -qE 'TEMPLATE_PLACEHOLDER' README.md AI_REPO_GUIDE.md 2>/dev/null && echo "FAIL: stub README or AI_REPO_GUIDE still has TEMPLATE_PLACEHOLDER"
  grep -qE 'PLEASE_UPDATE_THIS/URL' .github/ISSUE_TEMPLATE/config.yml 2>/dev/null && echo "FAIL: ISSUE_TEMPLATE/config.yml still has PLEASE_UPDATE_THIS/URL"
  ./scripts/verify-env.sh 2>&1 | grep -qE '[1-9][0-9]* files still contain TEMPLATE_PLACEHOLDER' \
    && echo "FAIL: verify-env still reports unexpected TEMPLATE_PLACEHOLDER markers"
  grep -qE 'TEMPLATE_PLACEHOLDER|\[TBD\]' .context/00_INDEX.md .context/roadmap.md .context/vision/README.md DESIGN.md 2>/dev/null \
    && echo "FAIL: resettable context files still contain generic Mode B stub markers"
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

Do **not** use `grep -RIl 'TEMPLATE_PLACEHOLDER|PLEASE_UPDATE_THIS' .` — those markers appear intentionally in template-detection surfaces (`.github/prompts/**`, `AGENTS.md`, role files, `*.template` samples). Use `grep -E` for alternation (portable extended regex).

When B9 passes (no `FAIL` lines), continue to **Track A** at A1.

---

## Track A — Orient (all modes)

### A1 — Quick context check

1. Read assigned GitHub issue body (durable task contract).
2. Read linked PR, if any.
3. Read latest `agent-state:v1` comment and labels.
4. Read `.context/00_INDEX.md`.
5. Run `git status` and `./scripts/verify-env.sh`.
6. Skim `.context/sessions/latest_summary.md`.
7. Emit status line:

   `"Context reviewed. Onboarding Mode: <A|B|C>. Current task is <name>. Environment is <Stable|Unstable: <reason>>. Ready for instructions."`

**Stable** means: clean or expected `git status`; `verify-env.sh` exits 0 with no onboarding-blocking WARNs (in derived repos, `TEMPLATE_PLACEHOLDER` WARN → **Unstable** = bootstrap incomplete); steps 1–6 completed without inventing missing files. Optional deeper check: `bash test.sh`.

### A2 — Key documentation

- [ ] `README.md`, `CONTRIBUTING.md` (if present)
- [ ] `AI_REPO_GUIDE.md` (if present — repo reference, not procedure driver)
- [ ] `.github/copilot-instructions.md` (if present)
- [ ] `docs/**`, `ARCHITECTURE.md`, `SECURITY.md` (if present)

### A3 — Map the codebase

Search and explore (not linear reading): top-level directories, entry points (server/CLI/library), test framework and locations.

### A4 — Build commands

Verify from `package.json`, `Makefile`, `pyproject.toml`, etc.: install, build, test, lint, typecheck.

### A5 — Repo brief

Structured summary: what the repo does, tech stack, folder map, entry points, config files, run/test commands, known risks.

### A6 — Finalize `AI_REPO_GUIDE.md` (once)

Single terminal step for onboarding. Create or update from real repo assets (`.context/**`, `docs/**`, codebase):

- Overview, quickstart, folder map, conventions, where to add things, troubleshooting.

Do not retain template placeholder language in derived repos. Further `AI_REPO_GUIDE.md` edits during implementation follow [`.context/rules/process_doc_maintenance.md`](../../.context/rules/process_doc_maintenance.md) triggers only.

### A7 — Onboarding complete

Start [`op-issue-workflow.md`](op-issue-workflow.md) at **Workflow Phase 0 — Session bootstrap** (not "onboarding Phase 0").

---

## Optional — Clarify, Implement, Deliver

Use only when this onboarding session **also** assigns implementation. Otherwise stop at **A7**.

### Clarify

Ask at most **3** targeted questions. If none needed, proceed.

### Implement

1. Propose a plan (files, tests, risks, verification commands) before edits.
2. Make changes; follow style; add tests for behavior changes.
3. Update docs when behavior changes. Update `AI_REPO_GUIDE.md` only if `process_doc_maintenance.md` triggers fire — not as a default re-read step.

### Deliver

Summary, files changed, test commands, expected outcome, follow-ups.

### Verification checklist

- [ ] Tests, lint, build pass
- [ ] Minimal diff; docs updated if behavior changed
- [ ] `AI_REPO_GUIDE.md` accurate (per A6 or doc-sync triggers)
