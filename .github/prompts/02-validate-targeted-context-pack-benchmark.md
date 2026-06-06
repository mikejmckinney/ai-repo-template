# Validate targeted context-pack benchmark implementation

## Role and objective

You are an independent QA/reviewer agent. Review the PR that implements targeted context-pack benchmark support.

Your job is to verify that the implementation is correct, safe, backwards-compatible, and cheap to run. Do not widen scope into production routing, AGENTS.md decomposition, or PR-review workflow redesign.

## Required startup

1. Read `AGENTS.md`.
2. If `.context/rules/process_session_start.md` exists, read it and follow it.
3. Read `.context/00_INDEX.md`.
4. Read:
   - `.context/benchmarks/model-roi/README.md`
   - `.context/benchmarks/model-roi/benchmark-runbook.md`
   - `scripts/benchmark/lib.sh`
   - `scripts/benchmark/run-candidate.sh`
   - `scripts/benchmark/run-suite.sh`
   - `scripts/benchmark/collect.sh`
   - `scripts/checks/167-context-pack-manifests.sh`, if present
   - `scripts/checks/055-script-syntax.sh`

## Review focus

Check these areas in order.

### 1. Backward compatibility

Confirm existing variants still work conceptually:

```text
baseline
agents-import-only
full-rules-injected
```

Confirm existing artifact paths are unchanged when `RUN_GROUP` is unset.

Confirm existing manifest format still works.

### 2. Context-pack safety

Inspect context-pack parsing.

It must reject:

- absolute paths
- `..`
- missing files
- `AGENTS.md`
- `CLAUDE.md`
- `.git`
- run/worktree artifact paths
- empty or invalid pack ids

It must not require the reason column to exist, but should tolerate it.

### 3. Metadata correctness

Inspect generated JSON code.

All generated JSON must be syntactically valid. Pay special attention to comma placement around:

```text
context-injection.json
context-pack metadata
meta-blind.json
meta-sealed.json
orchestration-overlay.json
duo metadata, if touched
```

Run:

```bash
jq -e . <each generated fixture or smoke-test JSON>
```

If the PR does not add a non-metered smoke fixture, note that as a high-impact follow-up.

### 4. Restoration and diff containment

Confirm pack injection:

- copies `AGENTS.md` before modifying it,
- copies `CLAUDE.md` before modifying it when present,
- marks modified instruction files skip-worktree during the run,
- restores both files before diff capture,
- prevents injected context from appearing in candidate diffs.

This is critical: context-pack benchmark artifacts must not contaminate the candidate diff.

### 5. RUN_GROUP collision prevention

Confirm grouped runs write to:

```text
scripts/benchmark/runs/<task>/groups/<run-group>/...
```

Confirm ungrouped runs still write to:

```text
scripts/benchmark/runs/<task>/...
```

Confirm `collect` and `unseal` read from the same grouped path when `RUN_GROUP` is set.

### 6. Docs and operator usability

Docs must include:

- pack list,
- pack purpose,
- exact commands,
- collect/unseal commands,
- sweet-spot decision rule,
- warning not to unseal before blind scores lock,
- warning that implementation support alone does not change model-routing policy.

### 7. Checks

Run:

```bash
bash -n scripts/benchmark/*.sh scripts/benchmark/adapters/*.sh scripts/checks/*.sh
./test.sh
```

If local environment lacks paid CLIs, do not run benchmark candidates. The validation should not spend model/API credits.

## Non-metered smoke test recommendation

If the implementation exposes functions cleanly, run a smoke like this, adapted to the actual implementation:

```bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export REPO_DIR="$PWD"
export RUNS_DIR="$tmpdir/runs"
export WORKTREES_DIR="$tmpdir/worktrees"
export MANIFEST="$PWD/.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example"

source scripts/benchmark/lib.sh

base_sha="$(git rev-parse HEAD)"
task="opfit-281-class-a-premerge"
alias="ctx-smoke"
run_index="1"
outdir="$RUNS_DIR/$task/$alias/r$run_index"
mkdir -p "$outdir"

wt="$(make_worktree "$task" "$alias" "$run_index" "$base_sha")"
apply_context_variant "$wt" "$outdir" "pack:core-min"

jq -e . "$outdir/context-injection.json"

grep -q "BENCHMARK_CONTEXT_PACK_START" "$wt/AGENTS.md"

restore_context_variant "$wt" "$outdir" "pack:core-min"

if grep -q "BENCHMARK_CONTEXT_PACK_START" "$wt/AGENTS.md"; then
  echo "AGENTS.md still contains injected context after restore" >&2
  exit 1
fi
```

Do not copy this blindly if function signatures changed; adapt it.

## Review output format

Post a review with this structure:

```markdown
## Overall assessment

APPROVE / REQUEST_CHANGES / BLOCK

## Findings

| Severity | Area | Finding | Evidence | Required fix |
|---|---|---|---|---|

## Verification performed

- [ ] bash syntax
- [ ] test.sh
- [ ] jq metadata validation
- [ ] non-metered context-pack smoke
- [ ] docs inspected

## Out-of-scope observations

List only high-impact observations. Do not ask for production routing or PR-review timing changes in this PR.
```
