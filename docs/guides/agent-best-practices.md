# Agent Best Practices

> **Purpose**: Guidance for working effectively with AI coding agents, including known limitations and mitigations.

## Issue and PR Granularity

Splitting many small follow-ups into separate issues and PRs is more expensive than the engineering work they wrap. Bundle by default; split only when there's a real reason.

### Bundle into one issue / one PR when **all** of these hold

- Same files or same subsystem.
- Same reviewer or same review pass surfaced them.
- Each piece is small (~50 lines of diff or less).
- They would land in the same week regardless of how they're filed.

### Split into separate issues / PRs when **any** of these hold

- Different domains (e.g. workflow internals vs. user-facing docs).
- Independently mergeable — one might be rejected on its own merits without blocking the other.
- Different blast radius (one is a pure refactor, one changes behavior).
- Likely to take more than a few days each.
- Want a separate paper trail (ADR, release note, security advisory).

### Worked example

PR #113's reviewer surfaced two medium findings about the ownership-table parser (extract shared script + sync-check role list). Both were ~50-line diffs in the same files from the same reviewer on the same theme. They were filed as #118 and #119 and shipped as PRs #123 and #124 — two issue overheads, two PR overheads, two CI rounds, two review passes. Per the bundling rule above they should have been **one** issue with two checkboxes and **one** PR. The split was correct for #114 / #115 / #116 (different subsystems, independently mergeable).

## Smoke-test PR convention

Workflow-validation / smoke-test PRs (the kind we ran for #114, #116) exist to *observe* what the workflows do, not to ship behavior. They must NOT have their behavior modified mid-test by the auto-fix or auto-merge pipelines.

**Rule**: any PR whose purpose is to exercise CI/workflow behavior must carry the `smoke-test` label.

**What the label does** (enforced in workflow `if:` gates):

- `agent-auto-merge.yml` skips eligibility — the smoke PR will not auto-merge
- `agent-relay-reviews.yml` skips both `relay` and `copilot-stall-watcher` jobs — Copilot won't be summoned to "fix" comments
- `agent-fix-reviews.yml` skips — Claude won't be summoned either

**Naming convention** (in addition to the label): smoke PR titles should start with `smoke(...)` so they're searchable and obvious in PR lists. The label is the enforcement gate; the title is the convenience.

**Cleanup**: smoke-test PRs are typically closed-without-merge after the validation completes. Branches deleted, issue smoke-test report posted to the relevant tracking issue (see #116 §"smoke test" comment for the canonical shape).

If you forget the label and a smoke PR auto-merges or gets a Claude fix during the test, that test is contaminated — close it, file a new one, label correctly.

## Token Limits and Context Management

### The Problem

AI models have limited context windows (measured in tokens). Large codebases or verbose documentation can exceed these limits, causing:
- Truncated context (agent misses important information)
- Degraded performance (too much irrelevant context)
- Higher costs (more tokens = more cost)
- "Lost in the Middle" problem where content in the middle of long documents is poorly attended to

### The 200-Line Rule

**If a single instruction file exceeds ~200 lines, split it into sub-modules.**

This prevents the "Lost in the Middle" attention issue where LLMs struggle to attend to content in the middle of long documents. Long files should be broken into focused sub-files that can be loaded on-demand.

Example:
```
# Instead of one 500-line rules file:
.context/rules/all_rules.md (500 lines) ❌

# Split into focused modules:
.context/rules/domain_auth.md (100 lines) ✓
.context/rules/domain_api.md (120 lines) ✓
.context/rules/domain_ui.md (80 lines) ✓
.context/rules/coding_standards.md (90 lines) ✓
```

### Mitigations

#### 1. Keep Individual Files Small

| File Type | Target Size | Maximum |
|-----------|-------------|---------|
| Context files (`.context/`) | < 200 lines | 500 lines |
| Documentation | < 300 lines | 1000 lines |
| Code files | < 400 lines | 800 lines |

If a file exceeds these limits, split it:
```
# Instead of one large file:
.context/rules.md (800 lines)

# Split into focused files:
.context/rules/domain_auth.md (150 lines)
.context/rules/domain_data.md (200 lines)
.context/rules/domain_api.md (180 lines)
```

#### 2. Use Clear File Names

Agents can selectively load files based on names. Use descriptive names:

```
# Good - agent knows what to load
.context/rules/domain_authentication.md
.context/state/active_task_user_registration.md

# Bad - agent must read to understand
.context/rules/misc.md
.context/state/current.md
```

#### 3. Provide a Context Summary (Optional for Large Projects)

For large projects with many context files, consider creating a summary file that agents can read first. This is **optional** - the template's `00_INDEX.md` already serves as the primary entry point:

```markdown
# .context/SUMMARY.md (optional - create if needed)

## Quick Reference
- Auth: See rules/domain_auth.md
- API: See rules/domain_api.md
- Current task: Implementing user registration
- Blocked by: Waiting for design review

## What to Read
1. Start with 00_INDEX.md (the default entry point)
2. Check state/_active.md or task_*.md (current work)
3. Only load rules/* files when making changes to those domains
```

**Note:** For most projects, `00_INDEX.md` is sufficient. Only add `SUMMARY.md` if your context grows large enough to need an additional quick-reference layer.

#### 4. Use the Priority Hierarchy

Don't duplicate information across files. Reference instead:

```markdown
# Good - reference, don't duplicate
See .context/rules/domain_auth.md for authentication requirements.

# Bad - duplicated content that may get out of sync
Authentication must use bcrypt with cost factor 12...
(same content copied to multiple files)
```

---

## Prompt Caching (Provider-Level)

> **TL;DR**: Caching is a runner/provider concern, not a repo-content concern. The repo is already structured to benefit (stable `AGENTS.md` + role files cited by reference, not copy-pasted). No repo changes are needed to opt in. This section just documents what callers *can* do.

### What it is

Modern LLM providers offer prompt caching: long, stable prefixes (e.g., a full system prompt) can be hashed and reused across calls within a TTL window, so the model only re-processes the *new* portion. This cuts both latency and per-token cost on repeat reads.

### Provider-by-provider

| Provider / runner | Caching mechanism | Repo-side action |
|---|---|---|
| **Anthropic API / Claude Code (direct API use)** | Mark stable prefixes with `cache_control: { type: "ephemeral" }` in the request. TTL ~5 min (rolling). | None — opt in at the call site. |
| **GitHub Copilot Chat** | Opaque/automatic. No user-facing knob. | None. |
| **Claude Code CLI (via `anthropic/claude-code-action`)** | Caching applied automatically by the CLI for the system prompt + `CLAUDE.md` chain. | None — already benefits from this repo's stable `AGENTS.md` / `CLAUDE.md`. |
| **Custom orchestrators / SDK callers** | Use the provider's caching primitive when assembling `AGENTS.md` + role file + task context. Cache the first two; leave task context uncached. | None. |

### What helps caching at the repo level

The single biggest cache-friendliness lever is **stability of long prefixes**. This repo already does the right things:

- `AGENTS.md` and `.github/agents/*.agent.md` change rarely; behavioral overrides go in role-scoped sections rather than rewriting the canonical text.
- Role files cite shared rules by reference (`.context/rules/domain_code_quality.md` H1–H8, etc.) instead of copy-pasting them. Copy-paste defeats caching because each call inlines a slightly different snapshot.
- The `description:` frontmatter line is byte-identical between `.github/agents/` and `.claude/agents/` mirrors (gated by `test.sh`), so multi-runner setups dispatch on the same hashable string.

### What would *hurt* caching (don't do this)

- Inlining the full text of a shared rule file into a role file "for convenience." It defeats reuse, drifts on edit, and is a known cache-buster.
- Adding timestamps, run IDs, or git SHAs to the system prompt prefix. Anything that changes per-call invalidates the cache.
- Reordering top-level sections of `AGENTS.md` without a strong reason. Even semantically equivalent reorderings break the cache hash.

### When to revisit

If a future runner becomes the primary one and exposes new caching knobs (e.g., named cache breakpoints, longer TTLs), document the call-site recipe here. Repo content should not change to chase caching behavior.

## State File Conflict Prevention

> **Primary mechanism**: role-based path ownership (`.context/rules/agent_ownership.md`). The mitigations below are secondary defenses for conflicts within a single role. For the full parallel-agent workflow, see `docs/guides/multi-agent-coordination.md`.

### The Problem

If multiple agents work simultaneously (or a human and agent), task files can have merge conflicts.

### Mitigations

#### 0. Role-Based Path Ownership (Primary)

The strongest defense is role-based path ownership. Each role in `.github/agents/*.agent.md` is assigned path globs in `.context/rules/agent_ownership.md`, and conflicts are greatly reduced when those globs are kept non-overlapping. In practice a few cases still need coordination: some path patterns may overlap (colocated test files, generated artifacts, lockfiles), and some files are intentionally shared or contested (for example, `.context/state/coordination.md` and `.context/rules/**`). Any cross-role edit must be claimed through the PM agent in `.context/state/coordination.md`. This is the primary mechanism — the fallbacks below mainly apply when two sessions of the **same role** overlap, or when work touches one of those shared/overlapping exceptions.

#### 1. One Active Task at a Time

The simplest solution: only one task should be in progress at once. Complete the current task before starting a new one.

#### 2. Multiple Task Files (for parallel work)

If you need parallel task tracking, use separate files:

```
.context/state/
├── _active.md               # Points to priority task
├── task_feature_auth.md     # Task 1 details
├── task_bugfix_api.md       # Task 2 details
└── task_refactor_ui.md      # Task 3 details
```

#### 3. Lock Before Working

Add a simple lock mechanism:

```markdown
# _active.md

## Lock Status
**Locked By**: agent-cursor-session-abc123
**Locked At**: 2025-01-25T14:30:00Z
**Expected Duration**: 30 minutes

## Current Task
...
```

Agents should check the lock before modifying.

#### 4. Use Git Branches

For significant parallel work, use feature branches. Each branch has its own state:

```bash
# Branch: feature/user-auth
.context/state/task_auth.md  # Auth work

# Branch: feature/api-refactor  
.context/state/task_api.md   # API work
```

Merge conflicts only occur when branches merge.

---

## Workflow Secrets Configuration

### Required Secrets

The CI workflows in this template require these GitHub repository secrets:

| Secret | Required By | How to Get It |
|--------|-------------|---------------|
| `BACKEND_URL` | `keep-warm.yml`, `validate-connections.yml` | Your deployed backend URL (e.g., `https://myapp.onrender.com`) |
| `DATABASE_URL` | Optional for `validate-connections.yml` | Connection string from your database provider |

### How to Set Secrets

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:
   - Name: `BACKEND_URL`
   - Value: `https://your-backend-url.com`
5. Click **Add secret**

### Optional Secrets for Deployment

If you add deployment workflows, you may need:

| Secret | Purpose | Where to Get |
|--------|---------|--------------|
| `VERCEL_TOKEN` | Vercel deployments | [Vercel Dashboard](https://vercel.com/account/tokens) |
| `VERCEL_ORG_ID` | Vercel org identifier | Vercel project settings |
| `VERCEL_PROJECT_ID` | Vercel project identifier | Vercel project settings |
| `RAILWAY_TOKEN` | Railway deployments | [Railway Dashboard](https://railway.app/account/tokens) |
| `RENDER_API_KEY` | Render deployments | [Render Dashboard](https://dashboard.render.com/u/settings) |

### Secrets Best Practices

1. **Never commit secrets** to the repository
2. **Use environment-specific secrets** (different values for staging vs. production)
3. **Rotate secrets regularly** (especially after team member departures)
4. **Use secret scanning** (pre-commit hooks or GitHub's built-in scanning)
5. **Limit access** (only give secrets to workflows that need them)

---

## Session Handoff Protocol

When an agent session ends (or a new agent takes over), follow this protocol:

### Ending a Session

1. **Update your task file** (`task_*.md`) with:
   - What was accomplished
   - What's left to do
   - Any blockers or open questions
   - Files that were modified

2. **Update `sessions/latest_summary.md`** with:
   - Key decisions made and their rationale
   - What didn't work (to prevent repeating mistakes)
   - Next session recommendations

3. **Commit work in progress**:
   ```bash
   git add .
   git commit -m "WIP: [task description] - session handoff"
   ```

4. **Leave clear next steps**:
   ```markdown
   ## Next Session Should
   1. Run tests to verify current state: `npm test`
   2. Continue with step 3 of implementation plan
   3. Address the TODO in src/auth.ts:42
   ```

### Starting a Session (The Onboarding Protocol)

Follow these steps in order:

1. **Read the current task**:
   ```
   .context/state/_active.md  # or task_*.md
   ```
   This tells you the immediate goal.

2. **Read the context index**:
   ```
   .context/00_INDEX.md
   ```
   This tells you where to find relevant rules/constraints.

3. **Check session history** (optional but recommended):
   ```
   .context/sessions/latest_summary.md
   ```
   This tells you what was tried, what worked, what didn't.

4. **Verify environment stability**:
   ```bash
   git status
   ./scripts/verify-env.sh  # or npm run verify
   ```

5. **Check recent decisions** (if available):
   - Skim the last closed PR
   - Review `sessions/latest_summary.md`

6. **Report readiness** (The Report Step):
   
   Before proceeding, output a status report:
   ```
   "I have reviewed the context.
   - Current task: [Task Name from task file]
   - Environment: [Stable/Unstable based on verify-env output]
   - Last session: [Brief summary from sessions/latest_summary.md]
   - Ready for instructions."
   ```
   
   This confirms context was loaded correctly and prevents silent failures.

---

## Common Pitfalls

### 1. Assuming Instead of Verifying

**Wrong**: "The API probably uses REST"
**Right**: Check `AI_REPO_GUIDE.md` or search for API patterns in the codebase

### 2. Making Sweeping Changes

**Wrong**: "Let me refactor the entire auth system while fixing this bug"
**Right**: Make minimal, focused changes. Create separate tasks for refactoring.

### 3. Ignoring CI Failures

**Wrong**: Mark task complete even though CI is red
**Right**: Read CI logs, fix issues, verify green before completing

### 4. Not Updating Documentation

**Wrong**: Change behavior without updating docs
**Right**: Update `AI_REPO_GUIDE.md` if commands, structure, or conventions change

### 5. Duplicating Context

**Wrong**: Copy the same information to multiple files
**Right**: Put it in one authoritative place and reference it elsewhere
