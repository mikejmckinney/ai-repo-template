# AI_REPO_GUIDE.md

> Canonical command and layout reference for agents working in this template.
> Last verified: 2026-08-03.

## Overview

This repository is a Codespaces-first template for AI-assisted software delivery.
ADR-031 defines the active execution model:

- one monolithic implementing agent;
- CI and lint as blocking pre-merge controls;
- normal `ai-review:live` advisory snapshots during eligible PR implementation;
- automatic daily post-merge and weekly full-repository review;
- OpenCode `multi-model-consensus` as the sole opt-in multi-model mechanism.

## Commands

```bash
scripts/verify-local.sh
scripts/verify-local.sh --full
./test.sh
bats --jobs 12 scripts/tests/
scripts/install-codespace-tools.sh --profile core --verify-only
scripts/codespace-post-create.sh
scripts/codespace-post-start.sh
scripts/cleanup-codespace-caches.sh
scripts/sync-opencode-oauth-secret.sh
scripts/create-derived-repo.sh --repo OWNER/PROJECT
.agents/skills/repo-onboarding/scripts/create-design-contract.sh --repo "$PWD"
scripts/format.sh --check <changed-files...>
python3 scripts/check-markdown-links.py <changed-markdown-files...>
python3 scripts/skill-supply-chain.py validate-lock --repo "$PWD" --lock skills-lock.json
python3 scripts/skill-supply-chain.py render-license-inventory --repo "$PWD" --lock skills-lock.json --check
scripts/diagnose-opencode-session.sh
scripts/archive-opencode-database.sh
git diff --check
```

Use `scripts/verify-local.sh` for fast local feedback. It verifies prerequisites,
then runs `./test.sh` without a full Bats suite or the derived-repository Bats
copy. Use `scripts/verify-local.sh --full` for the intentional complete gate: it
runs the full Bats suite once alongside `./test.sh`; copied-repository lifecycle
checks remain structural and never rerun Bats. Both modes print elapsed summaries
and remove successful logs. If a suite fails, the runner retains complete logs under
`.artifacts/local-verification/`.
Override timeouts with `VERIFY_LOCAL_BATS_TIMEOUT_SECONDS` and
`VERIFY_LOCAL_REPO_TIMEOUT_SECONDS`; both default to 300 seconds. A timeout is a
performance failure to investigate, not a reason to normalize a longer gate.
`VERIFY_LOCAL_BATS_TIMEOUT_SECONDS` applies only to `--full`. The Codespace
toolchain supplies required GNU `timeout` and `setsid`. Direct component commands
remain available for targeted diagnosis, not as a second completion procedure.

The canonical tool manifest pins Bats 1.12.0 with a 1.7.0 minimum contract. Its
pinned `uv` archive installs both the `uv` and `uvx` executables. Run
`scripts/verify-env.sh` for actionable prerequisite failures before starting
local MCP servers.

`.devcontainer/devcontainer.json` owns automatic Codespaces setup. Its
post-create hook installs the default profile: repository quality tools, enabled
local MCP prerequisites, OpenCode, Claude Code, Cursor Agent, and Codex. Use
`scripts/install-codespace-tools.sh --profile core` explicitly for the minimal
quality/runtime set. Other development environments invoke that installer
directly; this repository has no account-level dotfiles bootstrap.
Use `scripts/create-derived-repo.sh --repo OWNER/PROJECT` to preview remote
creation and allowlisted credential synchronization. Pass `--apply` only after
reviewing the redacted plan. The bootstrap grants the new repository access to
allowlisted existing Codespaces user secrets without publishing provider keys to
Actions. Dry-run lists planned names but remains offline; `--apply` resolves and
reports each secret's resulting disposition during the mutation run. No mode
previews the resolved grant set before mutation. See
`docs/guides/derived-repository-bootstrap.md`.
Run `scripts/cleanup-codespace-caches.sh` to preview reproducible package and
build caches when Codespace storage is low. Pass `--apply` explicitly to clean
them. Active uv runtimes are skipped; agent databases, history, credentials,
installed tools, and editor extensions are outside the cleanup scope.
Use `scripts/format.sh --write <files...>` for deterministic local shfmt and
markdownlint fixes. CI remains read-only and never commits formatting changes.
Run `scripts/diagnose-opencode-session.sh` instead of bare `opencode` when
capturing an unexpected interactive process restart; see
`docs/guides/opencode-termination-diagnostics.md`.
Run `scripts/archive-opencode-database.sh` first in dry-run mode when a large
OpenCode database prevents startup. Apply mode requires every OpenCode process
to be stopped, creates and verifies a coherent backup, and preserves the raw
DB/WAL/SHM generation before leaving the active path empty for a fresh start.
For an unfamiliar repository, run the `repo-onboarding` skill before repository
action. Its descriptive modes are `ai-repo-template`, `template-seed`, and
`complete`; the versioned state is `.context/onboarding-state.json`. Resumed or
post-compaction work uses `session-recovery` first instead of repeating
onboarding. Explicitly authorized `template-seed` onboarding runs
`scripts/setup.sh` after project-specific adaptation and before marking the
lifecycle complete; canonical and already-complete orientation remains
read-only.
Root `DESIGN.md` is conditional. Generate it from the canonical onboarding asset
only when verified project files or the assigned user outcome establish UI work;
then replace bracketed prompts from product evidence before frontend
implementation. Backend-only, infrastructure-only, and documentation
repositories do not need the file.
For implementation work, fill the issue plan, create and push an empty bootstrap
commit, and open a draft PR before meaningful edits. Commit and push each
changed turn before updating `agent-state:v1`; stage only task-owned paths.

OpenCode workflow calls use `OPENCODE_TIMEOUT_MS` for both the Node HTTP
transport and the outer abort, defaulting to `900000` (15 minutes). Set a larger
positive millisecond value only when a review legitimately needs a longer
end-to-end budget.
Run `scripts/sync-opencode-oauth-secret.sh` from an OAuth-authenticated
Codespace to preview the local OpenAI access-token expiration. Pass `--apply`
to replace the private repository's `OPENCODE_OPENAI_AUTH` Actions secret with
an access-only bundle. Codespace startup attempts that sync after PAT setup only
when repository visibility is verified as private, and falls back non-fatally
when visibility, auth, or authorization is unsuitable. The script never uploads
the real refresh token.
Daily Claude and Cursor attempts use
`POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS`, defaulting to `900` seconds. Weekly
Claude attempts use `WEEKLY_REVIEW_PROVIDER_TIMEOUT_SECONDS` with the same
default. A timeout terminates the stuck candidate and advances the existing
provider cascade instead of consuming the 90- or 120-minute workflow budget.

## Repository Layout

| Path | Purpose |
|---|---|
| `AGENTS.md` | Always-loaded operating contract |
| `README.md` | Human-facing overview and setup |
| `.context/` | Current project state, roadmap, and design context |
| `.context/onboarding-state.json` | Versioned template-seed/complete lifecycle state |
| `docs/decisions/` | Durable architecture decisions; ADR-031 owns the execution model |
| `docs/benchmarks/` | Published benchmark result records used for decisions |
| `docs/guides/model-roi-benchmark-runbook.md` | Canonical benchmark campaign procedure |
| `docs/guides/problem-framing.md` | Conditional problem, audience, alternatives, and impact analysis |
| `docs/guides/outcome-validation.md` | Outcome-equivalent environment selection and auditable evidence contract |
| `docs/guides/agent-pipeline.md` | Active workflow and trigger behavior |
| `.github/prompts/shared-review-lenses.md` | Canonical criteria for advisory and retro review |
| `.github/prompts/pr-advisory-review.md` | Normally applied, label-gated PR advisory output contract |
| `.github/prompts/post-merge-retro.md` | Daily merged-PR review contract |
| `.github/prompts/weekly-repo-review.md` | Weekly full-repository review contract |
| `.github/workflows/agent-advisory-review.yml` | Label-gated, non-blocking sticky advisory comment |
| `.github/workflows/agent-postmerge-retro.yml` | Scheduled daily retro and draft-fix lifecycle |
| `.github/workflows/agent-weekly-review.yml` | Scheduled weekly scan and draft-fix lifecycle |
| `.github/agent-runtime/` | Locked OpenCode dependencies and review/fix permission profiles |
| `.agents/skills/` | Canonical skills, including multi-model consensus and nested provider skill sets |
| `.agents/skills/repo-onboarding/assets/DESIGN.md` | Canonical on-demand design-contract source for verified UI projects |
| `skills-lock.json` | Immutable provenance, destinations, and hashes for external and repository-owned skills |
| `docs/guides/skill-supply-chain.md` | Skill lock, refresh, review, recovery, source onboarding, and license inventory |
| `docs/guides/cloud-provider-tooling.md` | AWS, Azure, GCP, OCI, Render, and Colyseus setup and smoke tests |
| `docs/guides/derived-repository-bootstrap.md` | Template creation, Actions secret sync, and Codespaces visibility |
| `scripts/workflows/advisory-review/` | Advisory provider adapters and comment upsert |
| `scripts/workflows/postmerge-retro/` | Daily evidence, analysis, umbrella, and fix adapters |
| `scripts/workflows/weekly-review/` | Weekly scan, umbrella, and fix adapters |
| `scripts/workflows/lib/` | Shared provider, evidence, priority, and lifecycle helpers |
| `scripts/checks/` | Numbered modules sourced by `test.sh` |
| `scripts/tests/` | Focused Bats tests |
| `.devcontainer/devcontainer.json` | Canonical repository-owned Codespaces lifecycle |
| `.config/codespace-tools.json` | Canonical Codespaces tool versions, release integrity, and profiles |
| `scripts/install-codespace-tools.sh` | Idempotent core/agents profile installer and verifier |
| `scripts/codespace-post-create.sh` | Dev Container creation hook for the default tool profile |
| `scripts/codespace-post-start.sh` | Non-fatal per-start PAT, OAuth, and sandbox hook |

### Nested Provider Skills

All 28 official Phaser 4 skills are pinned in `skills-lock.json` and grouped at
`.agents/skills/phaser/<name>/SKILL.md`. OpenCode, Cursor, Codex, and current
GitHub Copilot discover this recursive layout. Gemini CLI and `npx skills list`
only scan direct skill children, so they do not expose nested skills. Anthropic,
Vercel, Netlify, Supabase, and Cloudflare skills are likewise grouped under
provider parents; AWS, Azure, OCI, and Render use the same provider-parent layout.
Singleton providers and repository-owned skills remain direct children. Use
`python3 scripts/skill-supply-chain.py validate-lock --repo "$PWD" --lock
skills-lock.json` to inspect the authoritative nested inventory. Do not treat
`npx skills add . --list --full-depth` as complete; it omits some provider-parent
layouts. Do not use `npx skills experimental_install` to restore the layout: the
lock records upstream `skillPath` and explicit nested destinations. External
package trees with more than one skill declare sorted `skillEntrypoints` so
validation can discover nested skills without overlapping refresh records.
An external record may carry a bounded `localOverride` only for a tracked
temporary correctness fix. Validation hashes the corrected package, while
source checks and updates fail closed until the override is removed after an
equivalent upstream fix is verified. Scheduled aggregate refresh reports the
affected source as blocked rather than failed while preserving the direct
command guard; see `docs/guides/skill-supply-chain.md`.

## Review Lifecycle

### Advisory

Agents apply `ai-review:live` to every eligible same-repository task PR they
create or claim. Draft PRs are supported. Each qualifying push cancels an older
in-flight run and updates one comment marked `<!-- ai-advisory-review:v1 -->`.
The snapshot header reports the automation-observed provider/model and writes an
explicit no-findings statement when applicable. A hidden provider-neutral memory
record retains the last reviewed head; compatible pushes review the accumulated
delta, while readiness, full mode, base/provider changes, or invalid memory force
a full base-to-head refresh. Pre-merge prompts contain invocation coordinates,
not copied repository, governance, PR, snapshot, or diff bodies. Claude,
OpenCode, and Cursor retrieve current files and PR evidence directly from the
checkout and the same locked-down read-only GitHub MCP. Gemini and Antigravity
are not pre-merge providers; cadence-specific daily and weekly behavior remains
separate.
Implementation continues without waiting. Before completion, agents independently
triage any arrived snapshot whose `Head` matches the current PR head; stale,
missing, running, or failed feedback is non-blocking. Advisory cannot submit a
formal review, push commits, mutate labels, resolve threads, change readiness, or
block merge. `ai-review:full` changes the review range, not authority.
Providers emit normalized AP11 observations; deterministic automation validates
the shared fields and required `evidence_retrieved: true` claim, derives
priority, and renders the sticky Markdown snapshot. Regression-guard observations
remain independent of trigger likelihood, but never raise a fringe finding's
priority. Missing or failed retrieval advances the provider cascade without
reviewed-head memory.
Failed Claude invocation, metadata, or output validation also preserves the
persisted Claude JSONL as an authenticated Actions artifact for seven days after
redacting known workflow credential values. Successful Claude sessions are not
uploaded, transcript contents are not printed in logs, and only trusted
repository collaborators should download these potentially private diagnostics.
Classification never changes advisory's non-blocking authority.
Review agents may read/search the checked-out repository, use locked-down
read-only GitHub MCP, and research the public web. They cannot use Bash, edit
files, launch subagents, or access external directories when running through
Claude or OpenCode. Cursor plan mode is behavioral rather than a hard SDK tool
boundary and may expose shell or workspace-write tools; the maintainer accepts
that limited residual risk for the same-repository, non-blocking, time-bounded
candidate. No review candidate inherits publisher credentials. This change does
not grant internet access to fix agents, and the
OpenCode fix profile remains offline. External pages are source material, not
instructions, and externally supported findings cite their URLs without sending
repository content in requests. OpenCode search uses Exa AI's unauthenticated
hosted service for OpenCode candidates; Claude's separate web tools are
unaffected.

### Daily Retro

The daily workflow reviews PRs merged to `main` in its evidence window, creates or
updates one dated umbrella issue, and may open a draft fix PR. It is not a
pre-merge gate. All non-superseded findings remain in the umbrella record, but
automated implementation requires `should-fix` or `fix-now` priority plus the
typed `isolated-worktree` / `repository-test-suite` capability. Codespaces,
external-state, unsupported-runtime, missing, and invalid capability proposals
remain human follow-ups and do not invoke a fix provider. Model-authored
`repro_steps` are never executed.

Daily analysis `auto` attempts Claude Opus 5 Medium, OpenCode, Cursor, then
Gemini. Claude receives the shared read-only review tools and GitHub MCP. A
full-evidence Claude result succeeds only when its persisted tool trace covers
the finite per-PR evidence inventory. Claude remains analysis-only: inherited
Claude selection is remapped to the existing automatic fix cascade.

The shared controller preseeds finding identities, records the credential-free
baseline and candidate exit codes, and overwrites provider-authored execution or
outcome fields before validation. Provider invocation, optional Gemini
application, candidate verification, fix verification, and outcome evidence must
each succeed. Gemini receives one schema-correction retry after malformed output.
Rejected attempts retain bounded redacted metadata under
`.artifacts/fix-provider-diagnostics/`; raw model output and full patches remain
ephemeral. Verification-only output opens no PR, and a published PR must have a
confirmed native GitHub link to its umbrella issue.
Bounded provider output omits `evidence_complete`; full-evidence output must set
it to `true` only after retrieving every required source. Separate schemas keep
those claims from being conflated.

### Weekly Review

The weekly workflow scans current `main`, creates or updates one ISO-week umbrella,
and may open a draft fix PR. It remains a full-repository scan rather than a
weekly aggregation of merged PRs. The review job has a 120-minute budget and an
8,100-second OAuth minimum lifetime; the separate fix job remains at 60 minutes
and 4,500 seconds.

Weekly analysis `auto` attempts Claude Opus 5 Medium, OpenCode, Cursor, optional
Antigravity, then Gemini. Claude output must include observed repository reads or
content searches,
and finding evidence must resolve to existing repository paths. This proves
retrieval occurred and findings are path-backed without claiming every cited or
repository file was read. Weekly fix routing remains Claude-free.

### Multi-Model Consensus

Use the `multi-model-consensus` skill only when requested or when consequential
uncertainty warrants independent model perspectives. It is not the default
implementation path.
Fusion accepts a panel only when it ends with the injected completion marker.
A provider/process success with partial research or `finish=unknown` is rejected,
preserved for diagnosis, and replaced through the normal fallback chain.
Fusion stores raw panels and the judge result under ignored
`.artifacts/multi-model-consensus/<title>/` by default. Resume an interrupted
round with explicit `--panel-session SLOT:ENGINE:SESSION_ID` and
`--judge-session ENGINE:SESSION_ID` arguments. Add `--reuse-completed` with the
same output directory to adopt validated panel files whose session sidecars
match, rather than invoking those panels again. Never rediscover sessions from
recency after child sessions exist. The runner atomically persists accepted
panels and `result.json`, including accepted/requested session provenance,
checksums, and output paths.

## Canonical Generated Sources

Edit the source for a governed concept, then run its generator. Do not edit the
generated consumer directly.

| Governed concept | Canonical source | Generator |
|---|---|---|
| Concise P/AP catalog | `docs/guides/repo-orchestration-patterns-reference.md` | `python3 scripts/generate-pap-catalog.py --repo .` |
| Issue implementation-plan block | `.github/templates/issue-implementation-plan.md` | `python3 scripts/generate-issue-plans.py --repo .` |
| Review/fix runtime profiles | `.github/agent-runtime/base.json` plus overlays | `python3 scripts/generate-agent-runtime.py --repo .` |
| Development MCP host forms | `.config/mcp-inventory.json` | `python3 scripts/generate-mcp-configs.py --repo .` |

Pass `--check` to any generator for read-only freshness validation. `test.sh`
runs all four checks plus bounded structured-label validation. Runtime security
assertions remain direct tests even though the profiles are generated.

### Problem Framing And Critical Review

The monolithic implementing agent applies the risk-based trigger in `AGENTS.md`
before designing consequential or ambiguous work. Use
`docs/guides/problem-framing.md` only when deeper audience, competitive, or
impact analysis could change the decision; routine deterministic maintenance
does not require the full scaffold. Reviews must identify a concrete failure
mode and proportionate correction, and supporting checks never replace the
issue's user-outcome test. Choose the most representative practical validation
environment; cost and speed may distinguish equally representative options but
never justify omitting the affected user's action or required result. Obtain
explicit approval before paid or destructive validation and keep the outcome
blocked until that action is performed.

## Workflow Verification

Run `scripts/verify-pr.sh` to classify the changed paths; its fixtures own the
trigger rules. A workflow with `pull_request` and optional `workflow_dispatch`
is PR-branch verifiable when it has no default-only trigger. Dispatch-only and
other default-branch-only workflow changes require sandbox-default verification.
For `mixed` changes, structural trigger class and changed-behavior execution
constraint are separate decisions. Record evidence contract `1`,
`default-branch-constrained: yes|no`, the verification target, and a specific
reason. The PR smoke harness validates those fields against the detected class;
run `scripts/validate-verification-evidence.py` locally before completion. Use
`yes` when the changed behavior requires default-branch event
delivery, permissions, secrets, concurrency, environments, provider execution,
or publication. Use `no` when deterministic fixtures or the read-only
same-commit PR workflow exercise the changed behavior. Local and PR-native checks
are the correction loop; sandbox is one final integration canary when those
default-branch conditions remain load-bearing.
Use `docs/guides/outcome-validation.md` to select every required environment and
record material-claim artifacts. Follow `docs/guides/sandbox-verification.md`
for the specialized default-branch GitHub adapter and fire the real event.

Daily post-merge and weekly review JSON persist automation-owned provider
provenance: resolved provider, requested model, observed model or `unknown`, and
ordered fallback attempts. Their umbrella issues render the same bounded
metadata. Failed fix attempts upload bounded redacted diagnostics with provider,
model, failed stage, exit status, changed paths, diff statistics, failing checks,
and a capped excerpt. Configured model values are never substituted for an
unavailable observed identity.

## Authentication

GitHub creates a short-lived `GITHUB_TOKEN` for each workflow job. Workflows
declare the minimum job permissions and use `github.token` for repository API
writes. Automated merges intentionally do not trigger duplicate `push` CI/lint
runs; the strict main ruleset requires both checks against the current base
before merge.
Actions-created draft PRs require the repository setting **Allow GitHub Actions
to create and approve pull requests**. Because GitHub exposes no create-only
variant, `.github/CODEOWNERS` and the `main` ruleset require maintainer
code-owner approval before merge. Skill-refresh and review-fix publication stay
draft and do not opt into auto-merge.
Template-derived repositories inherit `.github/CODEOWNERS`. During
`template-seed` onboarding, replace the template maintainer with the user or
team that will provide required approval, especially for organization-owned
repositories.

Inside Codespaces, the injected `GITHUB_TOKEN` may not access the sibling sandbox.
Use command-local `GH_TOKEN="$GH_PAT"` with `GITHUB_TOKEN` unset when the configured
user PAT is required. Never commit tokens.

OpenCode workflow agents use `OPENCODE_GITHUB_TOKEN`, a dedicated read-only
fine-grained token, and `OPENROUTER_API_KEY` for Kimi K3. A trusted private
repository may additionally set `OPENCODE_OPENAI_AUTH` through the synchronization
script above. Invocation steps map that secret to `OPENCODE_AUTH_CONTENT`, enable
Sol only when its access token outlives the job timeout plus 15 minutes, and
otherwise start with Kimi. The stored `refresh` value is the inert
`ci-refresh-disabled` placeholder, so hosted runners never refresh or write back
personal OAuth credentials. Workflows install the pinned OpenCode runtime from
`.github/agent-runtime/package-lock.json` on GitHub-managed `ubuntu-latest`.
The label-gated pre-merge advisory attempts Claude Opus 5 Medium, Sol 5.6
Medium, Cursor Grok 4.5 Medium, then Kimi K3. Daily and weekly analysis also
attempt Claude first before their existing cadence-specific fallbacks. Generate
a one-year subscription token with `claude setup-token`, then store it manually with
`gh secret set CLAUDE_OAUTH_SECRET --repo OWNER/REPO` or the GitHub repository
settings. Anthropic prints but does not save the token, so provision and rotate
it as an annual secret rather than copying refresh-enabled login credentials.
The workflows map that secret back to `CLAUDE_CODE_OAUTH_TOKEN` only in analysis
execution steps and run pinned Claude Code `2.1.220` with repository reads, web
research, and strict locked-down read-only GitHub MCP tools. Provider isolation
removes it from non-Claude candidates, and neither recurring fix cascade
enumerates Claude or receives the secret.
Skill-refresh readiness uses a separate `SKILL_REFRESH_PR_TOKEN`, restricted to
the target repository with `Contents: read` and `Pull requests: write`. Provision
it manually after repository creation; the derived-repository bootstrap does not
copy it because a repository-scoped token cannot authorize a repository that does
not yet exist.

Interactive provider MCPs support write/deploy capabilities. Vercel, Netlify,
Supabase, Railway, and Cloudflare read credentials from `VERCEL_API_KEY`,
`NETLIFY_API_KEY`, `SUPABASE_API_KEY`, `RAILWAY_API_KEY`, and
`CLOUDFLARE_API_KEY`; never commit these values. Limit the Cloudflare token to
the accounts and developer-platform resources needed by the project.
Supabase is account-wide by default. Add `?project_ref=<id>` to its MCP URL when
one-project scope is preferred; project scope also disables account-management
tools. Cloudflare docs does not require account access.
ElevenLabs and Mureka read `ELEVENLABS_API_KEY` and `MUREKA_API_KEY` through
pinned local MCP launchers. ElevenLabs writes generated files under ignored
`.artifacts/audio/`; Mureka uses its documented API endpoint and a 300-second
generation timeout. Mureka and Suno also force `mcp==1.29.0` because their
current packages use MCP Python SDK v1 imports that were removed in v2. Starting
either server does not generate media, but provider generation tool calls
consume account credits.
The repository-owned `suno` skill uses Ace Data Cloud's third-party MCP, not an
official Suno API. Its exact local package reads `ACEDATACLOUD_API_TOKEN` from the
environment and calls Ace's hosted API. The reviewed upstream release workflow
injects its CalVer into `pyproject.toml` before building `mcp-suno==2026.7.4.0`,
but does not commit that generated version or expose artifact attestation. Keep
the exact package pin and re-review provenance before upgrades. Model/action
discovery and task lookup are supporting checks; generation and transformation
calls may consume credits and require explicit approval.
Railway uses its hosted MCP with `RAILWAY_API_KEY` as a bearer account token.
Netlify uses pinned `mcp-remote` in OpenCode because OpenCode 1.17.20's native
remote transport closes the hosted stream unexpectedly. Generated OpenCode MCP
entries default to a 60-second timeout so cold `npx`/`uvx` package resolution,
OAuth discovery, and proxy startup have enough headroom. Keep bridge logs silent
because verbose
diagnostics expand the authorization header. Pass its environment placeholder
directly to `mcp-remote`; shell expansion would expose the token in process
arguments. Cursor reads the direct-HTTP root
configuration through `.cursor/mcp.json`, a tracked symlink; Windows Git
checkouts require symlink support.

AWS uses `AWS_PROFILE` and `AWS_REGION` through pinned `mcp-proxy-for-aws`;
Azure uses Azure CLI / `DefaultAzureCredential`; OCI uses
`OCI_CONFIG_PROFILE` and remains disabled by default; Render uses the broadly
scoped `RENDER_API_KEY`. GCP and Colyseus have repository-owned skills but no
configured MCPs. Follow `docs/guides/cloud-provider-tooling.md` for
least-privilege setup, opt-in boundaries, and non-destructive smoke tests.
Enabled local browser MCPs use exact npm package versions from
`.config/mcp-inventory.json` through `scripts/browser-mcp.sh`. The core
Codespaces profile installs checksum-verified Chrome for Testing and its
artifact-declared Debian dependencies, then both Playwright and Chrome DevTools
launch that executable headlessly. Open Design uses its repository-owned lock
and bootstrap under `.agents/skills/open-design/`; its daemon checkout is also
part of the default core profile. The profile also installs the locked
`.github/agent-runtime` npm dependencies required by the local Bats suite and
OpenCode workflow helpers. Run the core profile with `--verify-only` to preflight
these prerequisites without downloading or changing packages.
The 19 AWS core skills come from the current Agent Toolkit for AWS successor
repository. All 26 Azure package trees are vendored; supported Azure plugin
installs also include the skills plus Azure and Foundry MCP configuration, but
host plugins do not replace the repository's immutable cross-agent lock.

## Documentation Synchronization

- Build, test, install, layout, generated-source ownership, and troubleshooting
  changes update this guide.
- Review lifecycle changes update ADR-031 and `docs/guides/agent-pipeline.md`.
- Workflow trigger changes update the pipeline and sandbox guides plus tests.
- File inventory changes update the owning check module and relevant template contracts.

## Known Warnings

`./test.sh` may report advisory warnings for downstream environment differences.
A non-zero failure count is blocking; warnings must still be reviewed for
relevance to the active task.
