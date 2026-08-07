# Sibling Repository Sandbox Verification

> **Audience**: Maintainers and agents shipping a change that
> [`scripts/verify-pr.sh`](../../scripts/verify-pr.sh) classifies as a
> **default-branch-only workflow**. This includes dispatch-only workflows.
> See [Workflow verifiability classes](agent-pipeline.md#workflow-verifiability-classes)
> for the verification outcomes. ADR-016 is the durable rationale.

This is a specialized environment adapter. Select environments and record
material-claim artifacts with [Outcome Validation](outcome-validation.md).

For mixed changes, first separate the workflow file's structural trigger class
from the changed behavior's execution constraint. Use deterministic fixtures,
`actionlint`, ShellCheck, and a read-only same-commit `pull_request` reusable
workflow as the correction loop. The reusable path must use synthetic inputs,
verify the candidate SHA, receive no production provider or publisher secrets,
and perform no repository or external mutation.

Sandbox remains required when the changed behavior depends on real
default-branch event delivery, token permissions, secret propagation,
concurrency, environments, repository controls, provider execution, or publisher
mutation. Record the decision with evidence contract `1`,
`default-branch-constrained: yes|no`, the selected target, and a specific reason.
For default-branch-constrained changes, run one final sandbox integration canary
after local and PR-native checks pass,
unless that canary reveals a default-branch-specific defect that requires a
second run.

Editing the upstream PR body reruns the PR-native harness and revalidates its
live verification declarations before the final sandbox result is accepted.

## Why this exists

GitHub Actions runs default-branch-only workflows from the repository's
default branch ref, not from the PR branch. A change to such a workflow
on a PR branch is therefore unverifiable pre-merge in the same repo.
PR #225 paid 11 rounds of bot-review for one such change because each
fix had to be merged to `main` before the bug class could even surface
in the next iteration.

This playbook describes the surgical workaround: a sibling sandbox repository
whose `main` is force-pushable, where the exact upstream candidate commit can be
staged and the trigger event exercised end-to-end before the real PR merges.

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
Run it from your upstream checkout. When the current `gh` identity cannot
create and mirror repositories, provide the optional bootstrap token:

```bash
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
detected and skipped with a log line). Step 7 ensures pipeline labels
(including `agent-suggested`) exist on the sandbox — required for
post-merge retro umbrella issues. Re-run `./scripts/setup/ensure-pipeline-labels.sh "$SANDBOX_REPO"` anytime labels drift.

> **Codespaces note**: the auto-provisioned `GITHUB_TOKEN` in a
> Codespace is scoped to the current repo only and cannot create new
> repos. You will hit `Resource not accessible by integration
> (createRepository)` unless you set `BOOTSTRAP_GH_TOKEN` to a
> classic PAT with `repo` AND `workflow` scopes (see above).
>
> On every Codespace start, the repository-owned
> [Dev Container configuration](../../.devcontainer/devcontainer.json) runs
> [`scripts/codespace-post-start.sh`](../../scripts/codespace-post-start.sh),
> which upgrades `gh` to a Codespaces user PAT (`GH_PAT`, etc.) when set,
> installs a shell hook so new terminals prefer that PAT over
> `GITHUB_TOKEN`, and **adds the `sandbox` git remote** when missing (same
> `SANDBOX_REPO_NAME` / `SANDBOX_REMOTE` defaults as bootstrap). It also
> attempts a non-fatal access-only OpenCode OAuth sync when the current
> repository is verified as private. It does **not** create the sandbox repo or
> set sandbox secrets — run
> `sandbox-bootstrap.sh` once for those.

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

# 4. Add the sandbox remote on this checkout.
git remote add "${SANDBOX_REMOTE:-sandbox}" "https://github.com/${SANDBOX_REPO}.git"

# 5. Ensure active pipeline labels on sandbox.
./scripts/setup/ensure-pipeline-labels.sh "$SANDBOX_REPO"
```

The sandbox is intentionally private: failed runs will produce noisy
artifacts (broken workflows, half-resolved PRs, dangling branches)
that aren't worth surfacing publicly.

## Per-PR verification flow

Use this when the classifier reports `default-branch-only workflow`, or when a
`mixed` change declares that its changed behavior is default-branch constrained,
and the outcome plan selects the sibling GitHub repository adapter. A mixed
classification alone does not force this route. Record the adapter under
`Outcome environments` and capture each material claim with the canonical
evidence record.

### OpenCode runtime prerequisite

For changes to advisory, retro, or weekly OpenCode automation:

1. Configure sandbox-only `OPENCODE_GITHUB_TOKEN` with read-only repository
   access plus a non-production `OPENROUTER_API_KEY`.
2. Verify `npm ci` installs the locked OpenCode runtime on `ubuntu-latest` and
   record the runner image release from the job setup log.
3. Verify the agent cannot create or update an issue through hosted MCP, then verify the
   deterministic publisher still creates the expected comment, umbrella issue,
   or draft PR.
4. Force the primary model to fail and capture ordered fallback telemetry. For a
   fix run, also capture worktree paths and the final patch to prove the failed
   attempt was discarded.
5. Exercise Sol eligibility with synthetic access-only fixtures unless the
   maintainer explicitly approves a short-lived sandbox credential. Never copy
   a production ChatGPT refresh token into the sandbox; the expected fixture
   refresh value is `ci-refresh-disabled`.

Never reuse a production write PAT as `OPENCODE_GITHUB_TOKEN`.

> **Authentication**: the `git push` and `gh` commands below require a
> token with `repo` + `workflow` scopes on the sandbox repo. In a
> workflow step, this is available as `${{ secrets.SANDBOX_BOOTSTRAP_TOKEN }}`
> (see `docs/guides/agent-pipeline.md` § "Required secrets"). When
> running manually from a Codespace or local checkout, pass the same
> classic PAT as `BOOTSTRAP_GH_TOKEN` and use the `GIT_ASKPASS` + `-c
> credential.helper=` bypass shown in `scripts/sandbox-bootstrap.sh`
> Step 3 (mirror push), or run `gh auth login` with that token first.
>
> **Codespaces fallback**: `SANDBOX_BOOTSTRAP_TOKEN` is a **repo Actions
> secret** — it is **not** exported into Codespace shells and
> `scripts/setup.sh` does not set it. If `SANDBOX_BOOTSTRAP_TOKEN` is
> unset in your session, use a Codespaces **user secret** such as
> `GH_PAT` (see `scripts/diag-sandbox.sh`) as the bootstrap token:
> `export BOOTSTRAP_GH_TOKEN="${SANDBOX_BOOTSTRAP_TOKEN:-$GH_PAT}"`.
> Run `./scripts/diag-sandbox.sh` first when auth is unclear.
> **Portability note**: examples below reference `$SANDBOX_REPO` (set
> during the bootstrap above as `<owner>/<repo>-sandbox`). Either keep
> that variable exported in your working shell, or substitute the
> literal slug for your project. The upstream value is
> `mikejmckinney/ai-repo-template-sandbox`; derived projects will
> resolve their own owner/repo from the bootstrap step.

### 1. Keep coordination and development upstream

Create and maintain the task issue, implementation plan, draft PR, review, and
`agent-state:v1` comment only in the upstream repository. Commit every fix to
the upstream PR branch first. Do not recreate the implementation as a sandbox
commit: the sandbox must exercise the exact commit that is under review.

Run local fixtures and the read-only PR-native harness until the candidate is
stable enough for one real-event integration canary. A red sandbox canary sends
the correction back to the upstream PR branch before another exact-SHA stage.

### 2. Stage the exact candidate on sandbox `main`

Run the read-only doctor first, then stage the explicit upstream PR head. The
helper verifies that the candidate is the current branch tip published on
`origin`, refuses `origin` as the target, validates the configured remote as the
same-owner sandbox sibling, saves the prior sandbox `main` in a deterministic
backup ref, and updates `main` with an explicit force-with-lease.

```bash
./scripts/diag-sandbox.sh

candidate=$(git rev-parse HEAD)
stage_json=$(./scripts/sandbox-candidate.sh stage \
  --candidate "$candidate" \
  --remote "${SANDBOX_REMOTE:-sandbox}")

baseline=$(jq -r .baseline <<<"$stage_json")
backup_ref=$(jq -r .backupRef <<<"$stage_json")

./scripts/sandbox-candidate.sh status \
  --candidate "$candidate" \
  --baseline "$baseline" \
  --backup-ref "$backup_ref" \
  --remote "${SANDBOX_REMOTE:-sandbox}"
```

The status must be `staged` before firing the event. Keep `stage_json` in the
redacted operator transcript; it binds the upstream source ref, candidate,
baseline, backup ref, and target without exposing the remote URL or credentials.

### 3. Create only event-required sandbox fixtures

The sandbox is an execution adapter, not a second planning surface. Do not
create a sandbox issue or implementation PR unless the GitHub event itself
requires that object.

| Event under test | Disposable sandbox fixture |
|---|---|
| `workflow_dispatch`, `schedule`, or `push` | None; dispatch or observe the event with candidate code already on sandbox `main`. |
| `pull_request` or `pull_request_review` | Minimal trigger branch and PR against sandbox `main`; add only the canary change needed to fire the event. |
| `pull_request.closed` / merged | Minimal trigger PR, merged or closed only after the required pre-close events complete. |
| `issues` / `issue_comment` | Minimal sandbox issue only when that event is the behavior under test. |

Trigger-only PRs and issues contain no implementation plan, agent state, or
independent copy of the fix. Their body links the upstream PR and identifies the
candidate SHA. Ephemeral canary files belong only on the trigger branch, never
in upstream `main`.

### 4. Fire the real event and capture evidence

Exercise the trigger while sandbox `main` still points to the candidate. Wait
for the relevant run to finish before restoration, then record the run URL,
event, candidate SHA, expected result, observed result, redaction, and retention
in the upstream PR's material-claim evidence. Add the verified restore and
backup-cleanup results before marking that claim complete.

Examples:

| Workflow under test | Trigger to fire in sandbox |
|---|---|
| `agent-advisory-review.yml` | Open a draft trigger PR, apply `ai-review:live`, then push another canary commit while review runs. |
| Scheduled jobs | Invoke their `workflow_dispatch` adapter after staging candidate sandbox `main`. |
| Dispatch-only workflow | Dispatch it directly; no sandbox issue or PR is needed. |

The run must identify the staged candidate SHA. A copied branch, a green run
from the baseline workflow, or prose without an inspectable run artifact is not
outcome evidence.

### 5. Restore and clean sandbox state

Restore only when sandbox `main` still equals the staged candidate. The helper
checks that lease and verifies that the backup ref still contains the recorded
baseline. Keep the backup ref until all critical evidence has been captured,
then delete it with another explicit lease.

```bash
./scripts/sandbox-candidate.sh restore \
  --candidate "$candidate" \
  --baseline "$baseline" \
  --backup-ref "$backup_ref" \
  --remote "${SANDBOX_REMOTE:-sandbox}"

./scripts/sandbox-candidate.sh status \
  --candidate "$candidate" \
  --baseline "$baseline" \
  --backup-ref "$backup_ref" \
  --remote "${SANDBOX_REMOTE:-sandbox}"

# Run only after evidence capture.
./scripts/sandbox-candidate.sh cleanup \
  --baseline "$baseline" \
  --backup-ref "$backup_ref" \
  --remote "${SANDBOX_REMOTE:-sandbox}"
```

Close and delete any trigger-only PR, issue, or branch after its stable URLs and
critical result excerpts are retained upstream.

## Automated fix-job sandbox sync (ADR-029 §1.1)

When `FIX_JOB_SANDBOX_VERIFY=true` on the **upstream** repo (default
`false`), daily/weekly **fix** jobs may push the fix branch to sandbox
once at end-of-job via
[`scripts/workflows/lib/sandbox-sync-fix-branch.sh`](../../scripts/workflows/lib/sandbox-sync-fix-branch.sh)
using `SANDBOX_BOOTSTRAP_TOKEN`. Branch names:
`test/fix-retro-<RUN_DATE>` or `test/fix-weekly-<RUN_WEEK>`. Jobs on
`*-sandbox` repos skip automatically. Run `./scripts/diag-sandbox.sh`
before manual or agent-driven sandbox operations.

This is a separate opt-in adapter for exercising an automated fix commit under
the sandbox's existing pull-request checks. It pushes the exact fix-job `HEAD`
to a disposable trigger branch and opens or updates a trigger PR; it does not
stage sandbox `main`, prove a changed default-branch workflow definition, or
replace `sandbox-candidate.sh`. Use it only when the material claim concerns the
generated fix under existing PR checks.

## Interpret the canary result

- **Green** — record the green sandbox run in the real PR's material-claim
  evidence, including the tested SHA and actual event.
  The maintainer can now merge here with confidence.
- **Red** — capture the failure, restore sandbox `main`, fix and push the
  upstream PR branch, then stage its new exact head and rerun only the required
  event fixture. Never patch or recommit the implementation in sandbox.

## Force-reset escape hatch

If sandbox state ever becomes confusing, first retain the current refs and run
`sandbox-candidate.sh status` with the recorded stage values. Use the normal
restore path whenever its candidate and backup leases still match. Only a
maintainer who has decided to discard all sandbox execution state should use
the reset below.

```bash
# Close any open sandbox PRs.
gh pr list --repo "$SANDBOX_REPO" \
  --state open --json number --jq '.[].number' \
  | xargs -I {} gh pr close --repo "$SANDBOX_REPO" {}

# Inspect the target, then compare-and-swap main back to production.
./scripts/diag-sandbox.sh
git fetch origin main
sandbox_main=$(git ls-remote --refs sandbox refs/heads/main | cut -f1)
git push --force-with-lease="refs/heads/main:${sandbox_main}" \
  sandbox origin/main:refs/heads/main

# Optionally rotate the sandbox PAT if the prior one may have leaked.
```

## Secrets hygiene

- **Use a sandbox-only PAT for `SANDBOX_BOOTSTRAP_TOKEN`.** If sandbox is
  ever compromised (it's lower-trust by design), the blast radius stops at
  the sandbox. Repository workflows use their automatic `GITHUB_TOKEN` for
  ordinary publication and do not need a copied upstream publication secret.
- **Sandbox token scope** is Contents R/W, Pull requests R/W, Issues R/W,
  Actions R, Variables R, and Metadata R, fine-grained to the sandbox repo.
- **Don't mirror SSH keys, deploy keys, or personal tokens** into the
  sandbox. The two repos are independent; cross-pollination
  re-introduces the blast-radius risk this playbook is trying to
  contain.

## Cadence

- **Sync** — on demand, immediately before each required canary. Exact candidate
  staging guarantees that the verification result binds to the upstream PR head
  rather than a separately reconstructed sandbox commit.
- **Garbage collection** — once a quarter, prune merged sandbox
  branches and closed PRs. None of them carry semantic value.
- **Secret rotation** — rotate the sandbox token on its configured cadence or
  sooner if there is any reason to suspect leakage.

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
