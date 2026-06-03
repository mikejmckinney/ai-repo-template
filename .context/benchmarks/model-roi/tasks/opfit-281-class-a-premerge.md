---
task_id: opfit-281-class-a-premerge
task_class: A-operational
base_branch: benchmark/model-roi/base-opfit-281-class-a-premerge-YYYYMMDD
reference_issue: 281
reference_pr: 288
reference_merge_sha: e8f5f96c44568a32e40ce1995b9ffb80c0009d28
reference_base_sha: 6946d04b3fd17014e32d9da5ea947acf6df14360
reference_title: Expand 055-script-syntax.sh bash -n coverage to scripts/, scripts/checks/, scripts/setup/, scripts/lib/
---

# Class A Benchmark Task: Expand Shell Syntax Coverage

## Candidate task

Implement the operational-fit task from closed issue #281.

### Problem

`scripts/checks/055-script-syntax.sh` only checks a small subset of shell scripts with `bash -n`. A syntax error in helper scripts under `scripts/`, `scripts/checks/`, `scripts/setup/`, or `scripts/lib/` can slip past the local `bash test.sh` verification flow until a later runtime path happens to source that file.

### Requested change

Update `scripts/checks/055-script-syntax.sh` so the repo-local verification suite runs `bash -n` against every authored shell script in these locations:

- `*.sh`
- `scripts/*.sh`
- `scripts/checks/*.sh`
- `scripts/setup/*.sh`
- `scripts/lib/*.sh`

Each checked file should produce its own `pass` or `fail` line through the existing test helper functions.

### Constraints

- Keep this as a parser-only `bash -n` check. Do not replace it with `shellcheck`.
- Do not add heavyweight dependencies.
- Keep the glob set explicit; do not accidentally include vendored/generated trees or Bats files.
- Handle empty globs safely.
- If the expanded check reveals a latent shell syntax error, fix it in the same diff.
- Update docs only where repo doc-sync rules require it; record any no-change decision in the plan/PR artifact.

### Verification expectations

Run:

```bash
bash test.sh
```

Also run any narrow syntax/lint command you use to verify the changed script, and report the real output.

### Acceptance criteria

- `scripts/checks/055-script-syntax.sh` checks the requested shell-script locations.
- Each file reports independently through the existing `pass`/`fail` helpers.
- `bash test.sh` catches a deliberate syntax error in one covered file and passes again after restoration, or the candidate clearly explains why that negative smoke could not be performed.
- The PR/diff remains scoped to the check and any required doc-sync.

## Reference solution (sealed; do not inject into candidate prompt)

- Issue: #281
- Reference PR: #288
- Reference merge SHA: `e8f5f96c44568a32e40ce1995b9ffb80c0009d28`
- Reference base SHA: `6946d04b3fd17014e32d9da5ea947acf6df14360`
- Reference changed files:
  - `scripts/checks/055-script-syntax.sh`
  - `.context/state/_active.md` (legacy state artifact; exclude from grading expectations)
