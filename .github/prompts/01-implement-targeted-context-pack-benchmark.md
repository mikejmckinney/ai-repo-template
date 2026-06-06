# Implement targeted context-pack benchmark support

## Role and objective

You are implementing the targeted context-pack benchmark for `ai-repo-template`.

The goal is to add a benchmark variant that tests **small, named context bundles** against the existing model ROI benchmark tasks, instead of injecting all of `.context/rules/*.md`.

This work extends the benchmark harness and docs only. Do not change production agent routing, default model pins, PR review timing workflows, or the AGENTS.md decomposition in this PR.

## Required startup

1. Read `AGENTS.md`.
2. If `.context/rules/process_session_start.md` exists, read it and follow it. Otherwise follow the current startup contract in `AGENTS.md`.
3. Read `.context/00_INDEX.md`.
4. Read:
   - `.context/benchmarks/model-roi/README.md`
   - `.context/benchmarks/model-roi/benchmark-runbook.md`
   - `.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md`
   - `scripts/benchmark/lib.sh`
   - `scripts/benchmark/Makefile`
   - `scripts/benchmark/run-candidate.sh`
   - `scripts/benchmark/run-suite.sh`
   - `scripts/benchmark/collect.sh`
   - `scripts/checks/055-script-syntax.sh`
5. Before editing, create or update the implementation plan comment according to repo convention.

## Context and evidence to preserve

Issue #374/#376 results showed that full-rule injection can improve some weaker runs but generally hurts ROI for the best candidates. The new benchmark must measure the "sweet spot" between lazy loading and full-rule injection.

The benchmark should test:

```text
baseline lazy loading
targeted small packs
class-specific packs
full-rule injection as the ceiling/negative-control
```

## Scope

Implement first-class support for:

```text
CONTEXT_VARIANT=pack:<pack-id>
```

Example:

```bash
RUN_GROUP=ctx-a-core-min \
MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE=<class-a-base-sha> \
  STAGE=1 \
  CONTEXT_VARIANT=pack:core-min
```

The implementation must remain backward compatible with existing values:

```text
baseline
agents-import-only
full-rules-injected
```

## Deliverables

### 1. Context-pack manifests

Add:

```text
.context/benchmarks/model-roi/context-packs/
  README.md
  core-min.tsv
  class-a-process.tsv
  class-b-implementation.tsv
  workflow-risk.tsv
  adr-docs.tsv
```

Manifest format:

```tsv
# path<TAB>reason
.context/00_INDEX.md	Map of available context surfaces and lazy-load expectations.
.context/rules/agent_ownership.md	Required before touching files.
```

Rules:

- Ignore blank lines and lines beginning with `#`.
- Parse the first tab-separated field as the repo-relative path.
- Reject absolute paths.
- Reject paths containing `..`.
- Reject missing files.
- Reject `AGENTS.md` and `CLAUDE.md` as pack entries to avoid self-injection / facade duplication.
- Preserve the reason column for documentation, but do not require the harness to use it during injection.

Suggested pack contents:

```text
core-min.tsv
  .context/00_INDEX.md
  .context/rules/agent_ownership.md
  .context/sessions/latest_summary.md

class-a-process.tsv
  all core-min files
  .context/rules/process_work_style.md
  .context/rules/process_doc_maintenance.md
  .context/rules/process_pr_completion.md
  .context/rules/process_opportunity_feedback.md

class-b-implementation.tsv
  all core-min files
  .context/rules/domain_code_quality.md
  .context/rules/process_work_style.md
  .context/rules/process_doc_maintenance.md

workflow-risk.tsv
  all core-min files
  .context/rules/process_work_style.md
  .context/rules/process_doc_maintenance.md
  docs/decisions/adr-016-pre-merge-verification-gate.md
  docs/guides/sandbox-verification.md

adr-docs.tsv
  all core-min files
  docs/decisions/README.md
  docs/decisions/adr-template.md
  .context/rules/process_model_tier.md
  .context/rules/repo_orchestration_patterns.md
```

If one of the suggested files does not exist under its exact name, search for the nearest current canonical file and either use that path or leave the row out with a note in `context-packs/README.md`. Do not invent empty placeholder rule files.

### 2. Harness support for `CONTEXT_VARIANT=pack:<pack-id>`

Modify `scripts/benchmark/lib.sh`.

Add or update functions so:

- `context_variant_slug` accepts:
  - `baseline`
  - `agents-import-only`
  - `full-rules-injected`
  - `pack:<pack-id>`
- `<pack-id>` must match a conservative pattern such as:
  - `^[A-Za-z0-9._-]+$`
- The pack manifest resolves to:
  - `.context/benchmarks/model-roi/context-packs/<pack-id>.tsv`
- The harness appends only the manifest-listed files to the candidate worktree's `AGENTS.md`, under a benchmark marker.
- For Claude Code compatibility, if `CLAUDE.md` exists and does not already contain `@AGENTS.md`, append the same benchmark import section used by full-rule injection.
- The harness must mark modified instruction files `skip-worktree` during the candidate run and restore them before diff capture, just like existing context injection.
- The injected files must not appear in the candidate diff.

Use a clear injected section like:

```markdown
<!-- BENCHMARK_CONTEXT_PACK_START: <pack-id> -->

## Benchmark Context Pack: `<pack-id>`

This section is injected by the model-ROI benchmark harness for a targeted context-pack variant. Treat these files as task-relevant project instructions for this run.

### Begin `<path>`

<file contents>

### End `<path>`

<!-- BENCHMARK_CONTEXT_PACK_END: <pack-id> -->
```

### 3. Metadata

The run artifact directory must include valid JSON metadata for pack runs.

You may reuse `context-injection.json`, but it must contain pack-specific fields:

```json
{
  "context_variant": "pack:class-b-implementation",
  "context_pack_id": "class-b-implementation",
  "injected": true,
  "source_manifest": ".context/benchmarks/model-roi/context-packs/class-b-implementation.tsv",
  "file_count": 6,
  "injected_agents_bytes": 24891,
  "injected_agents_sha256": "...",
  "files": [
    {
      "path": ".context/00_INDEX.md",
      "bytes": 1234,
      "sha256": "..."
    }
  ],
  "artifacts": {
    "agents_before": "AGENTS.md.before-context-injection",
    "agents_injected": "AGENTS.md.pack-class-b-implementation-injected",
    "claude_before": "CLAUDE.md.before-context-injection"
  }
}
```

Requirements:

- JSON must pass `jq -e .`.
- Include byte counts and SHA-256 hashes.
- Include each injected file path.
- Do not expose sealed model identity in this file.

Also check existing JSON generation paths in `lib.sh` and `run-duo-candidate.sh` while you are in this area. If any missing commas or invalid JSON are present, fix them in this PR because they directly affect benchmark artifact validity.

### 4. Artifact grouping to avoid collisions

Add optional run grouping so repeated context-variant suites can run against the same task/alias without overwriting each other.

Support:

```text
RUN_GROUP=<group-id>
```

Behavior:

- If `RUN_GROUP` is unset, keep current artifact paths unchanged.
- If `RUN_GROUP` is set, write artifacts under a grouped task directory.
- Use a conservative id pattern such as `^[A-Za-z0-9._-]+$`.
- The group must affect:
  - `run_outdir`
  - `result_file_path`
  - `suite_alias_set_path`
  - `suite_manifest_snapshot_path`
  - `collect`
  - `unseal`
- Existing historical artifacts and commands must remain compatible.

Recommended path shape:

```text
scripts/benchmark/runs/<task-id>/groups/<run-group>/<alias>/r<run-index>/
scripts/benchmark/runs/<task-id>/groups/<run-group>/stage-1-aliases.txt
scripts/benchmark/runs/<task-id>/groups/<run-group>/stage-1-manifest.tsv
scripts/benchmark/runs/<task-id>/groups/<run-group>/grading-sheet-blind.tsv
scripts/benchmark/runs/<task-id>/groups/<run-group>/unsealed-map.tsv
```

Document that `RUN_GROUP` is required for pack-matrix runs unless each alias is globally unique.

### 5. Candidate manifests

Add example manifests:

```text
.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example
.context/benchmarks/model-roi/stage-1e-pack-robustness-candidates.tsv.example
```

Pack screen manifest:

```tsv
# alias	platform	model	agent	stage	effort	effort_mechanism
ctx-cur	cursor	composer-2.5	cursor-cli	1	medium	prompt
ctx-gem	gemini-cli	gemini-3.5-flash	gemini-cli	1	medium	config
```

Robustness manifest:

```tsv
# alias	platform	model	agent	stage	effort	effort_mechanism
ctx-cursor-auto	cursor	auto	cursor-cli	1	default	none
ctx-gemini-auto	gemini-cli	auto	gemini-cli	1	default	none
ctx-claude-haiku	claude-code	haiku	claude-code-cli	1	medium	prompt
ctx-copilot-auto	copilot	auto	copilot-cli	1	default	none
```

If the current harness cannot support a listed cell without additional auth or model-picker work, document the caveat instead of silently changing the candidate.

### 6. Checks

Add a cheap validation check:

```text
scripts/checks/167-context-pack-manifests.sh
```

It should verify:

- `context-packs/README.md` exists.
- Required manifest files exist.
- Each manifest row path is safe and repo-relative.
- Each referenced file exists.
- No manifest references `AGENTS.md`, `CLAUDE.md`, `.git`, `scripts/benchmark/runs/`, or `scripts/benchmark/worktrees/`.
- Pack ids are valid.
- Example candidate manifests are not accidentally ignored unless that is explicitly intended.

Update `scripts/checks/055-script-syntax.sh` so it also checks:

```text
scripts/benchmark/*.sh
scripts/benchmark/adapters/*.sh
```

### 7. Documentation

Update:

```text
.context/benchmarks/model-roi/README.md
.context/benchmarks/model-roi/benchmark-runbook.md
AI_REPO_GUIDE.md
```

Add a section titled something close to:

```text
Targeted Context-Pack Stage
```

Include:

- Why this exists.
- Pack list and intended use.
- Commands to run pack screen.
- Commands to collect and unseal.
- Decision rule for the sweet spot.
- Caveat that this is not a production routing change.

Include this decision rule:

```text
sweet_spot_pack =
  highest marginal ROI pack
  with score >= best_score_for_task_class - 2
  and no model-specific degradation > 3 points
  and lower injected bytes/tokens than full-rules injection
```

Add example commands:

```bash
CLASS_A_BASE=6946d04b3fd17014e32d9da5ea947acf6df14360
CLASS_B_BASE=cff89bffe7e15e155bd740b6c7a0f158a6f2bad6

RUN_GROUP=ctx-a-core-min \
MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example" \
make -C scripts/benchmark suite \
  TASK=opfit-281-class-a-premerge \
  BASE="$CLASS_A_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:core-min

RUN_GROUP=ctx-b-class-b-implementation \
MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example" \
make -C scripts/benchmark suite \
  TASK=opfit-326-class-b-premerge \
  BASE="$CLASS_B_BASE" \
  STAGE=1 \
  CONTEXT_VARIANT=pack:class-b-implementation

RUN_GROUP=ctx-b-class-b-implementation \
make -C scripts/benchmark collect \
  TASK=opfit-326-class-b-premerge \
  STAGE=1
```

Also include the pack matrix:

```text
Class A:
  baseline
  pack:core-min
  pack:class-a-process
  full-rules-injected

Class B:
  baseline
  pack:core-min
  pack:class-b-implementation
  full-rules-injected

Workflow-risk task, if selected:
  baseline
  pack:core-min
  pack:workflow-risk
  full-rules-injected

ADR/docs task, if selected:
  baseline
  pack:core-min
  pack:adr-docs
  full-rules-injected
```

## Acceptance criteria

The PR is complete only when all of these are true:

- `CONTEXT_VARIANT=pack:core-min` is accepted by the harness.
- Unknown pack ids fail before spending on an agent run.
- Unsafe manifest paths fail before spending.
- Pack injection writes valid JSON metadata.
- Pack injection restores `AGENTS.md` and `CLAUDE.md` before diff capture.
- Pack-injected files do not appear in candidate diffs.
- `RUN_GROUP` keeps repeated variant runs from overwriting each other.
- Existing baseline and full-rules commands still work.
- `scripts/checks/167-context-pack-manifests.sh` passes.
- `scripts/checks/055-script-syntax.sh` covers new benchmark scripts.
- `./test.sh` passes, or any existing unrelated failure is documented with evidence.

## Verification commands

Run at minimum:

```bash
bash -n scripts/benchmark/*.sh scripts/benchmark/adapters/*.sh scripts/checks/*.sh
./test.sh
```

Add a non-metered smoke test if possible by sourcing `scripts/benchmark/lib.sh` and applying/restoring `CONTEXT_VARIANT=pack:core-min` to a temporary worktree without invoking any paid agent CLI.

## Out of scope

Do not do these in this PR:

- Do not change production model routing.
- Do not change `.github/agents`, `.claude/agents`, `.cursor/agents`, or `.codex/agents` model pins.
- Do not implement the AGENTS.md decomposition.
- Do not change PR review timing workflows.
- Do not run paid benchmark candidates unless explicitly asked.
- Do not update ADR-019 routing recommendations from this implementation alone.
