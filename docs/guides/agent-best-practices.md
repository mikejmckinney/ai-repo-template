# Agent Best Practices

> **Purpose**: Guidance for working effectively with AI coding agents, including known limitations and mitigations.

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

## State File Conflict Prevention

### The Problem

If multiple agents work simultaneously (or a human and agent), task files can have merge conflicts.

### Mitigations

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

---

## Multi-Agent Collaboration

> For detailed rules, see `.context/rules/domain_multi_agent.md` and `.context/rules/domain_orchestration.md`.  
> For role definitions, see `.context/vision/architecture/agent-roles.md`.

### When to Use Multiple Agents

| Complexity | Approach |
|-----------|----------|
| **Simple** (bug fix, doc update, config change) | Solo agent — coordination overhead isn't worth it |
| **Moderate** (single feature, 2-5 files) | 1-2 agents + 1 reviewer |
| **Complex** (multi-component feature, new system) | 3-5 agents + adversary reviewer |
| **Critical** (security, data migration, breaking changes) | Full team with mandatory adversarial review |

**Rule of thumb**: If you're unsure, start with one agent. Add more only if the work clearly decomposes into independent streams.

### File-Ownership Model for Conflict Prevention

The single biggest source of multi-agent failure is **merge conflicts from overlapping file edits**. Prevent this with explicit file ownership:

1. Each agent's task file declares `Owned Files/Dirs` — these are the *only* files that agent may modify
2. No two agents may own the same file
3. Shared files (types, interfaces, configs) are listed under `Shared Interfaces` — read-only by default
4. If an agent needs a shared file changed, it adds a coordination note and waits for acknowledgment

### Interface-First Design

When multiple agents will build interacting components, **define the interfaces before implementation**:

1. The architect (or first agent) defines API contracts, type definitions, and schemas
2. These are committed to a shared branch or merged to main
3. Implementer agents code against these contracts
4. Changes to contracts require coordination across all dependent agents

This mirrors the real-world practice of "API-first" development and is critical for parallel work.

### The Adversarial Review Pattern

For complex or critical work, assign one agent the **Adversary** role:

- The adversary does **not** implement features
- Instead, it actively tries to **break** other agents' implementations
- It tests edge cases, invalid inputs, race conditions, and security vulnerabilities
- Findings are documented in PR reviews
- Implementer agents must address all findings before merge

This catches bugs that self-review misses and produces significantly higher-quality output.

### Coordination Overhead Trade-offs

Multi-agent work has real costs:

| Benefit | Cost |
|---------|------|
| Parallelism (faster completion) | Coordination time (defining interfaces, reviewing) |
| Specialization (deeper expertise) | Context switching (reading other agents' state) |
| Quality (adversarial review) | Merge complexity (integrating branches) |

**When coordination cost > benefit**: Stick to a single agent. This is usually the case for:
- Changes to fewer than 5 files
- Work that doesn't cross system boundaries
- Tasks with tight deadlines where setup time matters

---

## Agent Session Hooks

> Inspired by the hook patterns from [Everything Claude Code](https://github.com/affaan-m/everything-claude-code). Adapted here as a tool-agnostic protocol.

### Session Start Hook

When an agent session begins, it should automatically:

1. **Load context**: Read `_active.md` → task file → `00_INDEX.md`
2. **Check for stale locks**: If a task file shows "In Progress" but was last updated > 2 hours ago, treat it as potentially abandoned
3. **Verify environment**: Run the project's verification command (e.g., `./test.sh`, `npm test`)
4. **Report readiness**: Output a brief status confirming context was loaded (see Session Handoff Protocol above)

### Session Stop Hook

When a session ends (normally or due to timeout):

1. **Save progress**: Update the task file with completed/remaining items
2. **Record lessons**: Update `sessions/latest_summary.md` with decisions and failures
3. **Commit WIP**: Push work-in-progress to the feature branch
4. **Release locks**: If using the lock mechanism in `_active.md`, clear the lock

### Checkpoint Verification

Don't wait until the end to verify — validate at each intermediate step:

```markdown
## Checkpoint Verification

| Checkpoint | Command | Status |
|-----------|---------|--------|
| Dependencies installed | `npm install` | ✅ |
| Unit tests pass | `npm test` | ✅ |
| New feature works | `npm run test:feature-x` | ⏳ |
| Lint clean | `npm run lint` | ❌ (fixing) |
| Build succeeds | `npm run build` | ⬜ |
```

This catches issues early, when they're cheap to fix, rather than discovering a cascade of failures at the end.

---

## Parallelization with Git Worktrees

> For significant parallel work, git worktrees offer an alternative to branch switching.

### What Are Worktrees?

Git worktrees let you check out multiple branches simultaneously in separate directories. Each worktree is a full working copy sharing the same `.git` history.

### When to Use Worktrees

- Multiple agents need to work on the same repo at the same time
- You want to avoid the overhead of `git stash` / `git switch` between branches
- Each agent needs its own filesystem context

### Setup

```bash
# From the main repo:
git worktree add ../project-frontend feature/frontend
git worktree add ../project-backend feature/backend
git worktree add ../project-tests feature/tests

# Each directory is a full checkout of its branch
# Run different agents in different directories
```

### Cleanup

```bash
# After merging branches:
git worktree remove ../project-frontend
git worktree remove ../project-backend
```

### Trade-offs vs. Branches

| Approach | Pros | Cons |
|----------|------|------|
| **Branches** (one checkout) | Simple, familiar | Must switch context to check other work |
| **Worktrees** (multiple checkouts) | True parallelism, no switching | Uses more disk space, more setup |

For most multi-agent template work, **branches are sufficient**. Use worktrees when agents are literally running simultaneously on the same machine.
