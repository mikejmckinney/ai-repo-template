# Model ROI Benchmark Runbook

This guide is the canonical operator entry point for the repository's occasional
agent/model ROI campaigns. Benchmark apparatus is an evaluation lab, not part of
the reusable template shipped from `main`.

## Canonical Surfaces

| Surface | Location | Purpose |
|---|---|---|
| Operator guide | This file on `main` | Campaign preparation, execution, and publication |
| Model-ROI results | [`docs/benchmarks/agent-roi-benchmark-results.md`](../benchmarks/agent-roi-benchmark-results.md) | Published score sets, costs, and conclusions |
| Retro results | [`docs/benchmarks/retro-execution-447-results.md`](../benchmarks/retro-execution-447-results.md) | Published retro execution comparison |
| Evaluation workspace | [`benchmark/roi`](https://github.com/mikejmckinney/ai-repo-template/tree/benchmark/roi) | Harness, tasks, prompts, schemas, graders, and local run inputs |
| Completed apparatus snapshot | [`8c296458`](https://github.com/mikejmckinney/ai-repo-template/tree/8c2964583af04b3352561410e22511304001ec21) | Immutable reference for the last mainline apparatus state |
| Locked Phase A artifacts | [`benchmark/phase-a-artifacts-20260608`](https://github.com/mikejmckinney/ai-repo-template/tree/benchmark/phase-a-artifacts-20260608) | Subjective grader output and raw retained evidence |

ADR-031 owns benchmark policy and current execution recommendations. Results on
`main` are decision evidence; the mutable lab branch is never itself a published
result citation.

## Prerequisites

- A clean clone with `origin` pointing to this repository.
- Git, Bash, Python 3, `jq`, and the agent CLIs selected for the campaign.
- Authentication for each selected provider.
- An approved issue and plan defining task classes, candidate matrix, spending
  limit, frozen bases, grading rubric, and user-outcome test.
- Explicit maintainer approval before any paid candidate invocation.

Never commit provider credentials, unsealed candidate mappings, generated
worktrees, raw prompts containing secrets, or local billing exports.

## Synchronize The Lab

Synchronize `benchmark/roi` immediately before a campaign. A normal merge would
apply `main`'s deliberate apparatus deletions to the lab branch, so preserve the
lab-owned paths from the branch tip while accepting all other `main` changes.

```bash
git fetch origin --tags
git switch benchmark/roi
git pull --ff-only origin benchmark/roi

lab_tip="$(git rev-parse HEAD)"
git merge --no-commit --no-ff origin/main

git restore --source="$lab_tip" -- \
  .context/benchmarks/model-roi \
  .github/prompts/06-implement-class-c-framework-benchmark.md \
  .github/prompts/model-roi-adjudicator-v1.md \
  .github/prompts/model-roi-benchmark-candidate.md \
  .github/prompts/model-roi-duo-implementer.md \
  .github/prompts/model-roi-duo-planner.md \
  .github/prompts/model-roi-grader-v1.md \
  .github/prompts/model-roi-orchestration-pipeline-candidate.md \
  .github/prompts/model-roi-pairwise-grader-v1.md \
  scripts/benchmark \
  scripts/checks/165-verify-benchmark-candidate.sh \
  scripts/checks/166-benchmark-ignores.sh \
  scripts/checks/167-context-pack-manifests.sh \
  scripts/checks/168-benchmark-grading.sh

git add -f \
  .context/benchmarks/model-roi \
  .github/prompts/06-implement-class-c-framework-benchmark.md \
  .github/prompts/model-roi-*.md \
  scripts/benchmark \
  scripts/checks/165-verify-benchmark-candidate.sh \
  scripts/checks/166-benchmark-ignores.sh \
  scripts/checks/167-context-pack-manifests.sh \
  scripts/checks/168-benchmark-grading.sh

git commit -m "Merge main into benchmark/roi for campaign"
```

If the merge reports conflicts outside the listed lab paths, stop and resolve
them as normal repository changes. Do not use `git merge -s ours`: that would
hide rather than integrate `main` changes.

After synchronization, update stale protocol references on `benchmark/roi` to
point to this guide and `docs/benchmarks/`. The old branch-local runbook is not a
second canonical copy. Before the next campaign, update any harness paths that
still target branch-local results, then remove the old runbook and result copies
from `benchmark/roi` in that campaign's preparation commit.

## Prepare A Campaign

1. Create a feature branch from the synchronized `benchmark/roi` tip.
2. Select committed task specs and record their task class.
3. Freeze or explicitly reuse base SHAs. Never mix rows from different bases
   without a comparability warning.
4. Copy an example candidate manifest to its ignored local filename and keep
   alias-to-model mappings sealed until grading is locked.
5. Verify requested model identifiers against observed runtime telemetry.
6. Run the non-spending doctor gate before invoking a candidate.

### Task-parallelism Phase 0A

Issue #545 has a stricter argument-free readiness gate before its feasibility
campaign. Run it only from the synchronized feature branch:

```bash
python3 -c 'import importlib.metadata as m; assert m.version("jsonschema") == "4.26.0"'
make -C scripts/benchmark/task-parallelism assets-check
make -C scripts/benchmark/task-parallelism preflight
jq '{status, campaign, freeze_state, assets, isolation, phase_0b}' \
  .artifacts/task-parallelism/preflight-report.json
bats --tap scripts/tests/task-parallelism-preflight.bats
```

The target accepts no campaign argument and always validates tracked
`campaign.phase-0a.json`. It requires FFmpeg `6.1.1-3ubuntu5`, JSON Schema Draft
2020-12 through `jsonschema==4.26.0`, and `unshare -Urn`. It clears inherited
credentials, blocks network and named child-process paths through the isolated
launcher, validates exact tracked asset hashes, and leaves Phase 0B blocked.
Unsupported hosts or version mismatches fail closed; preflight never installs
packages or invokes a provider.

Passing Phase 0A does not authorize candidate runs. The original Phase 0B pilot
used five Stage 1 repetitions for each arm under a separate approval. That pilot
is complete and cannot be rerun from this preparation contract. Polished media,
Cloudflare, deployment, publication, A2A, portability, and policy changes remain
behind later gates.

### Task-parallelism Phase 0B preparation

Harness preparation remains non-executing. Validate the tracked freeze and emit
the reviewable plan:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-validate
make -C scripts/benchmark/task-parallelism phase-0b-plan
jq '{execution_status, candidate_processes_started, assignments, gate_0}' \
  .artifacts/task-parallelism/phase-0b-run-plan.json
bats --tap scripts/tests/task-parallelism-phase-0b.bats
```

The preparation contract freezes Codex `gpt-5.6-luna` at observed `max` effort,
the exact scaffold lock and file hashes, arm-specific prompts, five
counterbalanced `AB`/`BA` blocks, sequential execution, and bounded retries. The
rendered plan must report `execution_status: blocked` and
`candidate_processes_started: 0`.

Before later execution approval, create the candidate base from the tracked
scaffold and replace `base_status: creation-deferred` with its exact branch and
commit. Candidate execution is not authorized by preparation or plan rendering.
During an approved run, retain every attempt separately. Candidate defects are
terminal without retry; one verified provider or harness failure may consume the
single bounded retry, and its original elapsed time and telemetry remain part of
harness-reliability evidence.
When pilot results exist, evaluate Gate 0 with:

```bash
python3 scripts/benchmark/task-parallelism/prepare-phase-0b.py \
  --evaluate-gate <phase-0b-pilot-summary.json>
```

Gate 0 is a feasibility gate, not an adoption claim. It requires ten terminal
assignments, complete required telemetry, at least 90% harness reliability, and
at least two Arm B fan-out elections. Confirmatory design and any polished media
remain separately gated.

The 2026-08-04 Phase 0B pilot reached a no-go: all ten assignments were terminal,
schema-required telemetry was complete, and Arm B recorded two fan-out
elections, but harness reliability was 81.8% across eleven retained attempts.
Eight assignments retained candidate-measured coordination telemetry; two
timeout records used the schema's explicit zero-filled failure fallback. Do not
start a confirmatory campaign from that result. Revise and separately approve
the feasibility harness before any rerun.

### Task-parallelism Phase 0B revision

The no-go follow-up is non-executing. Validate and render it with:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-revision-validate
make -C scripts/benchmark/task-parallelism phase-0b-revision-plan
make -C scripts/benchmark/task-parallelism phase-0b-diagnostic-validate
```

The revised plan contains one sequential assignment per arm. Candidate timeout,
partial, and failed outcomes are retained as results. Only a verified provider or
harness-invalid attempt may receive one replacement. Do not repeat a candidate
failure until it succeeds.

The blocked plan gives candidates explicit `--sandbox danger-full-access` and
requires build, unit, and browser checks with Playwright or Chrome DevTools. The
parent evaluator independently repeats those checks. The planner records an
instruction digest for each arm; activation renders the selected body as root
`AGENTS.override.md`. Arm A remains monolithic, while Arm B may use as many native
subagents as needed for the task. GitHub-only branch, PR, advisory-label, and
live-state duties are inert in the evaluator-owned checkout. Codex gives the
override precedence at project scope; see the
[Codex instruction guide](https://developers.openai.com/codex/agent-configuration/agents-md).

Activation must create candidates as standalone temporary clones with no shared
control-repository object database. This non-executing revision does not add an
execution state or parameterize the completed pilot runner. Those changes require
the separate candidate-execution approval. Activation must use a revision-specific
candidate-report schema without the completed pilot v1 schema's two-worker cap.
Do not treat the rendered plan as an executable campaign state.

The retained-branch diagnostic is explicitly non-confirmatory and does not alter
the merged pilot scores. The maintainer approved activation and one assignment
per arm on 2026-08-05. Validate the separate execution state before any process:

```bash
make -C scripts/benchmark/task-parallelism phase-0b-revision-execution-validate
```

The revision runner requires a frozen activation implementation SHA and creates
each candidate in a standalone, single-branch clone with no object alternates.
It disables candidate fetch/push access after cloning, injects and verifies the
arm-specific root override, then removes that harness-owned file before taking
the candidate snapshot. Run Arm A first and do not start Arm B until Arm A has a
terminal final result:

```bash
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --run-id vs-p0b-next-a
python3 scripts/benchmark/task-parallelism/run-phase-0b-revision.py \
  --run-id vs-p0b-next-b
make -C scripts/benchmark/task-parallelism phase-0b-revision-summary
```

Candidate timeout, partial completion, failure, and low quality are terminal
without retry. At most one verified provider-transient or harness-invalid
attempt may be replaced, and the original attempt remains durable. Every
checkout that produced work receives the same independent install, browser,
unit, build, and end-to-end evaluation regardless of candidate self-report.

Raw model transcripts and temporary clones remain ignored. The bounded tracked
record under `results/phase-0b-revision/` contains attempt and final results,
candidate reports, redacted process metadata, evaluator results and transcripts,
and the paired summary. That summary must state that official pilot scores are
unchanged and that the pair is directional, non-confirmatory, and not adoption
evidence. If the selected runtime emits only aggregate turn usage, record that
scope and mark parent/worker token splitting unavailable rather than estimating
a split.

Typical preflight:

```bash
make -C scripts/benchmark doctor STAGE=1 BASE=<base-sha>
```

The doctor must validate the task, prompt, manifest, base, required binaries,
authentication heuristics, writable artifact directories, and remote state.

## Run Candidates

Use the same candidate prompt, task body, frozen base, effort policy, and run
index convention for every comparable row.

```bash
make -C scripts/benchmark suite \
  TASK=<task-id> \
  BASE=<base-sha> \
  STAGE=1
```

Run one alias while diagnosing an adapter:

```bash
make -C scripts/benchmark run \
  TASK=<task-id> \
  BASE=<base-sha> \
  ALIAS=<candidate-alias>
```

Prefer sequential execution when wall-clock comparisons matter. Parallel runs
introduce host-load and provider-rate-limit noise. Record manual fallbacks as
manual; never relabel a blocked automated run as automated success.

## Collect And Grade

Keep grader-facing and sealed artifacts separate. Blind bundles use neutral
evaluation IDs and must not expose provider, model, framework condition, or
candidate aliases.

```bash
make -C scripts/benchmark collect TASK=<task-id>
./scripts/benchmark/regrade-stage.sh <stage> prepare
./scripts/benchmark/regrade-stage.sh <stage> grade <grader-id>
./scripts/benchmark/regrade-stage.sh <stage> record <grader-id> <responses-dir>
./scripts/benchmark/regrade-stage.sh <stage> compile <grader-id>
```

Scores are comparable only within the same `score_set_id`, rubric version,
grader prompt version, task, and frozen base. Separate candidate execution cost
from grading-model cost.

Unseal only after scores are locked:

```bash
make -C scripts/benchmark unseal TASK=<task-id>
```

## Publish Results

1. Update the appropriate file under `docs/benchmarks/` on a normal feature
   branch from current `main`.
2. Record task, base SHA, apparatus commit, artifact tag, candidate alias,
   requested and observed model, score set, rubric, grader, cost source, wall
   time, and caveats.
3. Cite immutable commits, tags, Actions runs, issues, and PRs. Do not cite the
   mutable `benchmark/roi` head as evidence.
4. Amend ADR-031 only when the new evidence changes repository policy.
5. Run the normal repository verification and sandbox user-outcome process for
   the publication PR.

Raw run directories, worktrees, response bundles, manifests that reveal model
identity, and local logs remain off `main`. Preserve evidence needed to reproduce
published conclusions in an immutable tag.

## Known Boundaries

- Class A/B evidence does not establish universal model quality.
- Class C greenfield comparison remains incomplete until a planned campaign runs.
- Pricing, model aliases, and routed backends change; refresh rate cards and
  record observed models for every campaign.
- Context-pack conclusions must be revalidated after material `AGENTS.md` or
  repository-process changes.
- Production code and tests promoted from benchmark findings stay on `main`; do
  not move them back into the evaluation lab.
