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

**Prerequisites**: `gh` (≥ 2.40) installed and authenticated against an
account that can create repos under the upstream repo's owner. Run
`gh auth status` first; if it reports "not logged in," run `gh auth
login` before continuing. The bootstrap below will fail fast with
clear errors if `gh` isn't authenticated, but checking up front saves
a round trip.

### Bootstrap script

The procedure is automated in [`scripts/sandbox-bootstrap.sh`](../../scripts/sandbox-bootstrap.sh).
Set the required environment variables and run it from your upstream
checkout:

```bash
# Required: a fine-grained PAT scoped to the sandbox repo only.
# Do NOT reuse production CLAUDE_PAT — see "Secrets hygiene" below.
# Required scopes: Contents R/W, Pull requests R/W, Issues R/W,
# Actions R, Variables R, Metadata R.
export SANDBOX_PAT="<sandbox-scoped PAT value>"

# Optional: separate sandbox-budget Anthropic key. Skip to defer
# claude.yml / agent-fix-reviews.yml exercise in sandbox.
export SANDBOX_ANTHROPIC_KEY="<sandbox-scoped Anthropic API key>"

# Optional: override the default sandbox slug
# (defaults to "<upstream-owner>/<upstream-name>-sandbox").
# export SANDBOX_REPO_NAME="my-org/my-custom-sandbox"

# Optional: override the local git remote name (default: "sandbox").
# export SANDBOX_REMOTE="sandbox"

# Optional: separate token used ONLY for the repo-create + mirror-push
# steps. Set this when your default `gh auth` is a Codespaces or
# Actions token that can't create repos under your owner namespace.
#
# RECOMMENDED: a classic personal token (ghp_...) with 'repo' AND
# 'workflow' scopes. Generate at: https://github.com/settings/tokens/new
# ('workflow' is required to push .github/workflows/ files;
# 'repo' alone is not sufficient.)
# export BOOTSTRAP_GH_TOKEN="ghp_<classic PAT>"

./scripts/sandbox-bootstrap.sh
```

The script is idempotent: re-running on an already-bootstrapped sandbox
is safe (existing repo, existing remote, and existing secrets are
detected and skipped with a log line).

> **Codespaces note**: the auto-provisioned `GITHUB_TOKEN` in a
> Codespace is scoped to the current repo only and cannot create new
> repos. You will hit `Resource not accessible by integration
> (createRepository)` unless you set `BOOTSTRAP_GH_TOKEN` to a
> classic PAT with `repo` AND `workflow` scopes (see above).

### What the script does (for reference)

```bash
# 1. Resolve the upstream repo URL from your current checkout's
#    `origin` remote. Doing it this way means the script works
#    unchanged in any project derived from ai-repo-template.
UPSTREAM_URL=$(git remote get-url origin)
UPSTREAM_NAME=$(basename "$UPSTREAM_URL" .git)        # e.g. ai-repo-template
UPSTREAM_OWNER=$(gh repo view --json owner -q .owner.login)
SANDBOX_REPO="${SANDBOX_REPO_NAME:-${UPSTREAM_OWNER}/${UPSTREAM_NAME}-sandbox}"

# 2. Create the sandbox sibling repo (private; same owner; no template).
gh repo create "$SANDBOX_REPO" \
  --private \
  --description "Sandbox for verifying default-branch-only workflow changes from ${UPSTREAM_NAME} (see ADR-016)"

# 3. Mirror this repo's main into the new sandbox.
MIRROR_DIR=$(mktemp -d)/upstream.git
git clone --bare "$UPSTREAM_URL" "$MIRROR_DIR"
git -C "$MIRROR_DIR" push --mirror "https://github.com/${SANDBOX_REPO}.git"
rm -rf "$(dirname "$MIRROR_DIR")"

# 4. Set the sandbox CLAUDE_PAT secret from $SANDBOX_PAT.
printf '%s' "$SANDBOX_PAT" | gh secret set CLAUDE_PAT \
  --repo "$SANDBOX_REPO"

# 5. (Optional) Set ANTHROPIC_API_KEY from $SANDBOX_ANTHROPIC_KEY.
printf '%s' "$SANDBOX_ANTHROPIC_KEY" | gh secret set ANTHROPIC_API_KEY \
  --repo "$SANDBOX_REPO"

# 6. Add the sandbox remote on this checkout.
git remote add "${SANDBOX_REMOTE:-sandbox}" "https://github.com/${SANDBOX_REPO}.git"
```

The sandbox is intentionally private: failed runs will produce noisy
artifacts (broken workflows, half-resolved PRs, dangling branches)
that aren't worth surfacing publicly.

## Per-PR verification flow

Use this when your Implementation Plan declares
`Change class: default-branch-only workflow` (or `mixed`) and
`Verification target: sandbox repo` (or `both`). The verbs follow the
plan template's Verification section verbatim.

> **Authentication**: the `git push` and `gh` commands below require a
> token with `repo` + `workflow` scopes on the sandbox repo. In a
> workflow step, this is available as `${{ secrets.SANDBOX_BOOTSTRAP_TOKEN }}`
> (see `docs/guides/agent-pipeline.md` § "Required secrets"). When
> running manually from a Codespace or local checkout, pass the same
> classic PAT as `BOOTSTRAP_GH_TOKEN` and use the `GIT_ASKPASS` + `-c
> credential.helper=` bypass shown in `scripts/sandbox-bootstrap.sh`
> Step 3 (mirror push), or run `gh auth login` with that token first.
> **Portability note**: examples below reference `$SANDBOX_REPO` (set
> during the bootstrap above as `<owner>/<repo>-sandbox`). Either keep
> that variable exported in your working shell, or substitute the
> literal slug for your project. The upstream value is
> `mikejmckinney/ai-repo-template-sandbox`; derived projects will
> resolve their own owner/repo from the bootstrap step.

### 1. Prepare sandbox state — fresh test branches (default)

The sandbox `main` ref is shared across PRs and may carry head-branch
references from prior merged sandbox PRs (e.g. PR descriptions in this
repo's history that link `mikejmckinney/ai-repo-template-sandbox#NNN`
rely on those head branches still existing). The default per-PR
workflow therefore creates fresh test branches off `sandbox/main`
rather than force-resetting `sandbox/main` itself.

```bash
git fetch origin main
git fetch sandbox

# (Recommended) Tag the current sandbox/main HEAD before any test work,
# so a force-reset is recoverable if you need it later.
tag="pre-op-playbook-test-$(date +%Y-%m-%d-%H%M%S)"
git tag -a "$tag" sandbox/main -m "Pre-test sandbox/main snapshot"
git push sandbox "$tag"

# Create a per-PR mirror of upstream main as the sandbox base for the test PR.
git push sandbox origin/main:test/playbook-mainline

# Push your PR branch under a test-prefixed name so it can't collide with
# any production sandbox branch the upstream history still references.
git push sandbox HEAD:test/sandbox-<short-slug>
```

Open the sandbox PR with `--base test/playbook-mainline --head test/sandbox-<short-slug>`
in step 3 below. `sandbox/main` is left untouched, so PR descriptions
elsewhere that cite sandbox PR head branches keep resolving.

### 1-alt. Force-reset sandbox `main` (explicit override)

Use this only when the sandbox is genuinely empty (no PR-history
references worth preserving) or when the maintainer has explicitly
decided to discard prior sandbox state. The fresh-branches default
above is safer for any sandbox that has carried a real PR.

```bash
git fetch origin main
git push --force sandbox origin/main:main
```

This is the only force-push the playbook authorizes. It runs against
the sandbox remote only, never against `origin`. Document the choice
in the PR body's `parent_compliance.deviations[]` so a future Judge
can see why the safer default was overridden.

### 2. Push your PR branch to sandbox

Already done in step 1 (default flow) under the `test/sandbox-<short-slug>`
name. If you used the force-reset override path in step 1-alt, push your
branch now under any name; in that case PR creation in step 3 uses
`--base main --head <branch>`.

```bash
# Only needed if you used the force-reset override path.
git push sandbox HEAD
```

### 3. Open the sandbox PR (merge optional)

```bash
# Default flow (test/playbook-mainline base):
gh pr create \
  --repo "$SANDBOX_REPO" \
  --title "[sandbox] $(git log -1 --pretty=%s)" \
  --body "Sandbox verification for ai-repo-template PR <link to real PR>." \
  --base test/playbook-mainline \
  --head "test/sandbox-<short-slug>"

# Force-reset override flow:
#   --base main --head "$(git rev-parse --abbrev-ref HEAD)"
```

Whether to merge the sandbox PR depends on what trigger you need to
exercise (step 4). Triggers like `pull_request_review` /
`workflow_dispatch` / `schedule` fire without merge; triggers like
`pull_request.closed` require it. Only merge sandbox PRs that need it
for trigger reproduction; leaving a sandbox PR open is also fine and
is useful as a test artifact reviewers can inspect.

```bash
# Only when the trigger requires it:
gh pr merge --repo "$SANDBOX_REPO" \
  --squash --delete-branch <sandbox-pr-number>
```

### 4. Exercise the trigger event in sandbox

Now reproduce the trigger that the workflow depends on. Examples:

| Workflow under test | Trigger to fire in sandbox |
|---|---|
| `agent-relay-reviews.yml` | Open a sandbox PR, post a `pull_request_review` (`gh api`) carrying inline comments. |
| `agent-fix-reviews.yml` | Same; submit a `changes_requested` review. |
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
- **Red** — fix the change on your PR branch, push the new tip to
  `sandbox` under the same `test/sandbox-<short-slug>` name (or to your
  PR branch under the override flow), and re-run from step 3 if the
  sandbox PR was merged or step 4 if it's still open. The
  `test/playbook-mainline` base does not need to be re-pushed unless
  upstream `origin/main` has moved.

## Force-reset escape hatch

If sandbox state ever becomes confusing — leftover PRs, leftover
branches, half-applied secrets — wipe and rebuild rather than try to
disentangle. The sandbox carries no permanent state worth preserving.

```bash
# Close any open sandbox PRs.
gh pr list --repo "$SANDBOX_REPO" \
  --state open --json number --jq '.[].number' \
  | xargs -I {} gh pr close --repo "$SANDBOX_REPO" {}

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

## Sandbox Doctor (`diag-sandbox.sh`)

Run `./scripts/diag-sandbox.sh` before the verification flow above whenever
the auth state is unclear, `gh` fails unexpectedly, or sandbox `git push`
returns a 403. It is also useful after initial bootstrap to confirm the
sandbox remote is reachable.

### Non-mutation contract

`diag-sandbox.sh` makes **no writes** of any kind: no force-pushes, no branch
creates or deletes, no remote modifications. It is safe to run at any time
without side effects.

### Auth-source behavior

**Inside Codespaces** (`CODESPACES=true`): the auto-injected `GITHUB_TOKEN` is
scoped to the current repo and typically lacks write access to the sandbox
repo. The doctor detects this condition by inspecting `gh auth status` for the
`(GITHUB_TOKEN)` token-source string. If found, it probes the PAT upgrade
variables in this order: `GH_PAT`, `GH_TOKEN_PAT`, `CODESPACES_GH_PAT`,
`GITHUB_PAT`. When a variable is set the doctor prints the upgrade command;
otherwise it tells you which variable to set as a Codespaces user secret.

If `gh` is already authenticated via a non-`GITHUB_TOKEN` source (e.g., you
ran `gh auth login` with a PAT), the doctor reports the active identity and
skips the PAT upgrade path.

**Outside Codespaces**: the doctor reports the active `gh` identity and token
source, and notes any PAT variable that is set (optional upgrade path). If
`gh auth status` fails and no active identity is reported, the doctor exits 1
and prints a `gh auth login` reminder.

### Sandbox remote reachability and `DIAG_GIT_TIMEOUT`

The doctor resolves the remote URL from the local git config (remote name
defaults to `sandbox`; override with `SANDBOX_REMOTE`), then probes it with a
read-only `git ls-remote`. A timeout wrapper enforces the budget.

| Env var | Default | Effect |
|---|---|---|
| `SANDBOX_REMOTE` | `sandbox` | Local git remote name for the sandbox |
| `DIAG_GIT_TIMEOUT` | `10` | Seconds before the `git ls-remote` probe times out. Set to `0` to skip the timeout wrapper entirely. |

If the `sandbox` remote is not configured, the doctor emits a `git remote add`
advisory and exits 2. See [One-time setup](#one-time-setup-maintainer) above.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | All checks passed; sandbox is reachable with usable auth |
| `1` | Hard failure (script logic error or auth configuration is broken) |
| `2` | Warning: sandbox unreachable or sandbox remote not configured |

### PAT variable list — maintenance anchor

The probe list (`GH_PAT`, `GH_TOKEN_PAT`, `CODESPACES_GH_PAT`, `GITHUB_PAT`)
must stay in sync with `scripts/setup/40-ensure-labels.sh`.
Both files must be updated together whenever a new PAT alias is added.

## See also

- ADR-016 — Pre-merge verification gate
- `docs/guides/agent-pipeline.md` § "Workflow verifiability matrix"
- `scripts/verify-pr.sh` — the classifier this playbook composes with
- `.github/PLAN_TEMPLATE.md` — the `Change class` / `Verification
  target` fields
