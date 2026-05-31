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

### Fix-only commits when resolving PR feedback

When resolving items from a PR review pass, **each commit must address only one review item** (one `ISS-NN` entry from the `pr-resolve-all.md` Issue/Suggestion Index) — no refactoring, renaming, or style improvements in the same commit. Note improvements in the Resolution Report under "Additional Observations" and commit them separately or file a follow-up issue.

**Why**: PR #228 Round 5 refactored `grep | wc -l` → `grep -c` in the same commit as a real fix. The refactor changed exit-code semantics under `set -e` and caused the Round 7 regression — 2 of 8 rounds were self-inflicted by the in-fix scope creep.

Note: this is consistent with `pr-resolve-all.md`'s "Classify before fixing" Round discipline Rule 3 (issue #220), which keeps substantive fixes in separate commits; this rule applies the same single-concern discipline per commit.

### Pre-push review (local Critic + lint + tests)

Run [`.github/prompts/pre-push-review.md`](../../.github/prompts/pre-push-review.md) before `git push` on any non-trivial diff. The prompt produces a single Markdown summary with three sections — Critic findings (MAJOR CONCERN or higher only), lint (`shellcheck` + `shfmt` + `actionlint` + `lint-shell-conventions.sh`) on changed files, and `./test.sh`. Push only when every section reports PASS.

- **SHOULD** for any non-trivial diff (>50 LOC OR any `scripts/*.sh`, `.github/workflows/*.yml`, role file, or `AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md` change).
- **MUST** for the DevOps role on shell/workflow changes — see `.agents/devops.md` Do list.
- **Why**: shifts subjective-quality findings from the post-push bot-review loop (which costs an agent round each time) to a single local pass. Phase 1 (`lint-and-format.yml`) handles the static class in CI; this prompt handles the subjective class locally before push.
- **Out of scope (deliberate)**: a pre-push git hook is *not* installed in v1 (per ADR-013-style local-friction concerns) — the SHOULD/MUST in role files plus the runnable prompt is the lever.

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

## Cross-check guards (CI)

**Rule**: when two artifacts in the same repo encode a shared invariant — the same set of identifiers, route names, env-var names, schema fields, etc. — the cross-check guard ships in **the same PR as the second artifact**, not bolted on later when drift is noticed.

The failure mode is structural: each artifact is edited by a different agent or workflow, and without a guard that asserts `set(A) == set(B)`, drift stays invisible until something downstream breaks. By then it's a postmortem, not a code review.

**Sequencing rule**:

1. PR adds artifact A → no guard needed yet.
2. PR adds artifact B that shares an invariant with A → the guard ships **in this PR**, before merge. Reviewers should block on a missing guard.
3. PR adds artifact C that shares the same invariant → extend the existing guard, don't add a parallel one.

**Where the guard lives**: a standalone script under `scripts/` (any language appropriate to the repo) wired into CI. Don't bury cross-check logic inside one of the generators — the guard must be runnable independently to be debuggable. When parsing structured data formats (CSV, YAML, etc.), use a format-aware parser rather than field-splitting with `awk`/`cut`/`IFS` — silent miss-parses defeat the guard.

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
2. Check the assigned issue/PR and latest agent-state:v1 comment (current work)
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

- `AGENTS.md` and `.agents/*.md` change rarely; behavioral overrides go in role-scoped sections rather than rewriting the canonical text. Platform overlays (`.github/agents/`, `.claude/agents/`) are thin shims and only carry platform-specific frontmatter (ADR-023).
- Role files cite shared rules by reference (`.context/rules/domain_code_quality.md` H1–H8, etc.) instead of copy-pasting them. Copy-paste defeats caching because each call inlines a slightly different snapshot.
- The `description:` frontmatter line is byte-identical between the canonical `.agents/<role>.md` and every platform overlay (`.github/agents/`, `.claude/agents/`) — enforced by `scripts/checks/050-agent-mirror.sh` — so multi-runner setups dispatch on the same hashable string.

### What would *hurt* caching (don't do this)

- Inlining the full text of a shared rule file into a role file "for convenience." It defeats reuse, drifts on edit, and is a known cache-buster.
- Adding timestamps, run IDs, or git SHAs to the system prompt prefix. Anything that changes per-call invalidates the cache.
- Reordering top-level sections of `AGENTS.md` without a strong reason. Even semantically equivalent reorderings break the cache hash.

### When to revisit

If a future runner becomes the primary one and exposes new caching knobs (e.g., named cache breakpoints, longer TTLs), document the call-site recipe here. Repo content should not change to chase caching behavior.

## Live-State Conflict Prevention

> **Primary mechanism**: role-based path ownership (`.context/rules/agent_ownership.md`). The mitigations below are secondary defenses for conflicts within a single role. For the full parallel-agent workflow, see [docs/guides/multi-agent-coordination.md](multi-agent-coordination.md).

### The Problem

If multiple agents work simultaneously (or a human and agent), they can overwrite or miss each other's live state unless the state surface is explicit and owner-keyed.

### Mitigations

#### 0. Role-Based Path Ownership (Primary)

The strongest defense is role-based path ownership. Each role in `.agents/<role>.md` (with platform overlays in `.github/agents/` and `.claude/agents/`) is assigned path globs in `.context/rules/agent_ownership.md`, and conflicts are greatly reduced when those globs are kept non-overlapping. In practice a few cases still need coordination: some path patterns may overlap (colocated test files, generated artifacts, lockfiles), and some files are intentionally shared or contested (for example, `.context/rules/**`). Any cross-role edit must be coordinated through PM and recorded in GitHub live state. This is the primary mechanism — the fallbacks below mainly apply when two sessions of the **same role** overlap, or when work touches one of those shared/overlapping exceptions.

#### 1. One Active Task at a Time

The simplest solution: only one task should be in progress at once. Complete the current task before starting a new one.

#### 2. Owner-keyed live comments (for parallel work)

If you need parallel task tracking, use separate issues/PRs or clearly owner-keyed `agent-state:v1` comments:

```markdown
<!-- agent-state:v1 issue:123 pr:pending branch:feature/backend-auth role:backend -->

**Status:** in_progress
```

#### 3. Claim Before Working

Update the latest live-state comment and labels before editing:

```markdown
**Status:** in_progress

## Blockers / awaiting
- None

## Next 1–3 actions
1. ...
```

Agents should check existing claims before modifying.

#### 4. Use Git Branches

For significant parallel work, use feature branches. Each branch has its own state:

```bash
# Branch: feature/user-auth
# Live state: latest agent-state:v1 comment on the auth issue/PR

# Branch: feature/api-refactor  
# Live state: latest agent-state:v1 comment on the API issue/PR
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

1. **Update the latest `agent-state:v1` comment** with:
   - What was accomplished
   - What's left to do
   - Any blockers or open questions
   - Who should pick up next, if anyone

2. **Update `sessions/latest_summary.md` only for durable lessons** at PR merge/closeout:
   - What shipped
   - What was harder than expected
   - What generalizes

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
   Assigned GitHub issue/PR + latest agent-state:v1 comment
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
   - Current task: [Task Name from issue/PR]
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
