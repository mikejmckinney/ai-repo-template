# Sandbox Verification Playbook

> **Audience**: Maintainers and agents shipping a change that touches a
> **default-branch-only workflow** (any `.github/workflows/*.yml` whose
> triggers include `pull_request_review`, `pull_request_review_comment`,
> `pull_request_target`, `issue_comment`, `push`, `schedule`, or
> `workflow_run`). See the
> [Workflow verifiability matrix](agent-pipeline.md#workflow-verifiability-matrix)
> for the canonical trigger list. ADR-016 is the durable rationale.

## Why this exists

GitHub Actions runs default-branch-only workflows from the repository's
default branch ref, not from the PR branch. A change to such a workflow
on a PR branch is therefore unverifiable pre-merge in the same repo.
PR #225 paid 11 rounds of bot-review for one such change because each
fix had to be merged to `main` before the bug class could even surface
in the next iteration.

This playbook describes the surgical workaround: a sibling sandbox
repository whose `main` is force-pushable, where the breaking change
can be merged and the trigger event exercised end-to-end before the
real PR merges here.

## One-time setup (maintainer)

The sandbox repo and its secrets only need to be created once. Do this
before the first sandbox-class PR lands; the rest of the playbook
assumes both exist.

```bash
# 1. Resolve the upstream repo URL from your current checkout's
#    `origin` remote. Doing it this way means this playbook works
#    unchanged in any project derived from ai-repo-template.
UPSTREAM_URL=$(git remote get-url origin)
UPSTREAM_NAME=$(basename "$UPSTREAM_URL" .git)        # e.g. ai-repo-template
UPSTREAM_OWNER=$(gh repo view --json owner -q .owner.login)
SANDBOX_REPO="${UPSTREAM_OWNER}/${UPSTREAM_NAME}-sandbox"

# 2. Create the sandbox sibling repo (private; same owner; no template).
gh repo create "$SANDBOX_REPO" \
  --private \
  --description "Sandbox for verifying default-branch-only workflow changes from ${UPSTREAM_NAME} (see ADR-016)"

# 3. Mirror this repo's main into the new sandbox.
MIRROR_DIR=$(mktemp -d)/upstream.git
git clone --bare "$UPSTREAM_URL" "$MIRROR_DIR"
git -C "$MIRROR_DIR" push --mirror "https://github.com/${SANDBOX_REPO}.git"
rm -rf "$(dirname "$MIRROR_DIR")"

# 4. Mint a sandbox-only PAT and set it as the sandbox's CLAUDE_PAT.
#    Do NOT reuse the production CLAUDE_PAT — see "Secrets hygiene" below.
#    The sandbox PAT needs the same fine-grained scopes as production
#    CLAUDE_PAT (Contents R/W, Pull requests R/W, Issues R/W, Actions R,
#    Variables R, Metadata R) but only on the sandbox repo.
gh secret set CLAUDE_PAT \
  --repo "$SANDBOX_REPO" \
  --body "<sandbox-scoped PAT value>"

# 5. (Optional) Mirror ANTHROPIC_API_KEY if you want claude.yml /
#    agent-fix-reviews.yml to be exercisable in sandbox too. A
#    separate sandbox-budget API key is recommended.
gh secret set ANTHROPIC_API_KEY \
  --repo "$SANDBOX_REPO" \
  --body "<sandbox-scoped API key>"

# 6. Configure the sandbox remote on your working clone of the real repo.
cd <your local checkout of the upstream repo>
git remote add sandbox https://github.com/mikejmckinney/ai-repo-template-sandbox.git
git remote -v   # verify both `origin` and `sandbox`
```

The sandbox is intentionally private: failed runs will produce noisy
artifacts (broken workflows, half-resolved PRs, dangling branches)
that aren't worth surfacing publicly.

## Per-PR verification flow

Use this when your Implementation Plan declares
`Change class: default-branch-only workflow` (or `mixed`) and
`Verification target: sandbox repo` (or `both`). The verbs follow the
plan template's Verification section verbatim.

> **Portability note**: examples below show the upstream
> `mikejmckinney/ai-repo-template-sandbox` slug. In any project derived
> from ai-repo-template, substitute your own
> `<owner>/<repo>-sandbox` (the slug you created in step 1 above) — or
> set `SANDBOX_REPO` in your shell and reuse the same variable everywhere.

### 1. Force-sync sandbox `main` to this repo's `main`

The sandbox `main` is *not* a long-lived branch — it tracks production's
`main` from the moment of each verification run. Predictable per-test
state matters more than history continuity.

```bash
git fetch origin main
git push --force sandbox origin/main:main
```

This is the only force-push the playbook authorizes. It runs against
the sandbox remote only, never against `origin`.

### 2. Push your PR branch to sandbox

```bash
# From your branch (e.g. feature/devops-NNN-relay-fix).
git push sandbox HEAD
```

### 3. Open and merge a sandbox PR

```bash
gh pr create \
  --repo mikejmckinney/ai-repo-template-sandbox \
  --title "[sandbox] $(git log -1 --pretty=%s)" \
  --body "Sandbox verification for ai-repo-template PR <link to real PR>. Will be merged immediately to exercise the trigger." \
  --base main \
  --head "$(git rev-parse --abbrev-ref HEAD)"

# Merge as soon as the PR is open. Sandbox PRs do not need bot review;
# the real PR is the one that goes through the canonical gate.
gh pr merge --repo mikejmckinney/ai-repo-template-sandbox \
  --squash --delete-branch <sandbox-pr-number>
```

### 4. Exercise the trigger event in sandbox

Now reproduce the trigger that the workflow depends on. Examples:

| Workflow under test | Trigger to fire in sandbox |
|---|---|
| `agent-relay-reviews.yml` | Open a sandbox PR, post a `pull_request_review` (`gh api`) carrying inline comments. |
| `agent-fix-reviews.yml` | Same; submit a `changes_requested` review. |
| `agent-coordination-sync.yml` | Open a PR that edits `.context/state/coordination.md`. |
| `auto-rebase-on-merge.yml` | Merge any PR; the workflow fires on `pull_request.closed`. |
| `keep-warm.yml` / scheduled jobs | Trigger via `gh workflow run <name>` (`workflow_dispatch` is also wired). |
| `backlog-to-issues.yml` | Edit `.context/backlog.yaml` on sandbox `main`. |

Watch the run in the sandbox repo's Actions tab. The whole point of
sandbox is that a real failure surfaces *here*, in logs you can read,
without leaving any artifact in this repo's `main`.

### 5. Decide

- **Green** — paste a one-line link to the green sandbox run into a
  comment on the real PR (`Sandbox verification: <run URL> — green`).
  The maintainer / Judge can now merge here with confidence.
- **Red** — fix the change on your PR branch, push to both `origin`
  and `sandbox`, and re-run from step 3. (Sandbox `main` is already
  fresh from step 1 unless something else has been merged in
  between; if so, redo step 1.)

## Force-reset escape hatch

If sandbox state ever becomes confusing — leftover PRs, leftover
branches, half-applied secrets — wipe and rebuild rather than try to
disentangle. The sandbox carries no permanent state worth preserving.

```bash
# Close any open sandbox PRs.
gh pr list --repo mikejmckinney/ai-repo-template-sandbox \
  --state open --json number --jq '.[].number' \
  | xargs -I {} gh pr close --repo mikejmckinney/ai-repo-template-sandbox {}

# Force-sync main from production again.
git fetch origin main
git push --force sandbox origin/main:main

# Optionally rotate the sandbox PAT if the prior one may have leaked.
```

## Secrets hygiene

- **Use a sandbox-only PAT.** Do not reuse the production `CLAUDE_PAT`.
  If sandbox is ever compromised (it's lower-trust by design — anyone
  who needs to verify a default-branch-only workflow has push access),
  the blast radius stops at the sandbox.
- **Sandbox PAT scope** matches production CLAUDE_PAT (Contents R/W,
  Pull requests R/W, Issues R/W, Actions R, Variables R, Metadata R)
  but is fine-grained to the sandbox repo only.
- **No copy of `ANTHROPIC_API_KEY` if you can avoid it.** If the
  workflow under test calls Anthropic, mint a separate API key on a
  sandbox-budget account so a sandbox runaway can't drain production
  budget.
- **Don't mirror SSH keys, deploy keys, or personal tokens** into the
  sandbox. The two repos are independent; cross-pollination
  re-introduces the blast-radius risk this playbook is trying to
  contain.

## Cadence

- **Sync** — on demand, immediately before each verification run
  (step 1 above). The sandbox is not auto-synced; explicit sync
  guarantees the verification result reflects the *current*
  production `main`, not a stale snapshot.
- **Garbage collection** — once a quarter, prune merged sandbox
  branches and closed PRs. None of them carry semantic value.
- **Secret rotation** — rotate the sandbox PAT at the same cadence as
  the production `CLAUDE_PAT` (or sooner if there's any reason to
  suspect leakage).

## When sandbox is *not* required

The matrix in `agent-pipeline.md` is authoritative; in practice:

- Code-only PRs (no `.github/workflows/*.yml` touched) — sandbox is
  not required. Default verification on the PR branch is sufficient.
- Workflows whose only triggers are `pull_request` or
  `workflow_dispatch` — sandbox is not required. CI on the PR branch
  already runs the new workflow file. (Note: `pull_request_target`
  does **not** belong in this set — it loads the workflow from the
  base branch, so PR-branch changes are unverifiable.)
- Pure docs / ADRs / role-file edits (no scripts, no workflows) —
  sandbox is not required.

If you're unsure, run `bash scripts/verify-pr.sh` locally — it will
print the detected class and tell you whether the sandbox playbook
applies.

## See also

- ADR-016 — Pre-merge verification gate
- `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix"
- `scripts/verify-pr.sh` — the classifier this playbook composes with
- `.github/PLAN_TEMPLATE.md` — the `Change class` / `Verification
  target` fields
