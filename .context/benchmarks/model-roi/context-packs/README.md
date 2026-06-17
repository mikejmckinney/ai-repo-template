# Targeted context packs (Stage 1E)

Named, small context bundles for the model-ROI benchmark. Each pack is a TSV manifest
listing repo-relative paths to inject into the candidate worktree's `AGENTS.md` for the
duration of a run only (skip-worktree + restore before diff capture).

## Manifest format

```tsv
# path<TAB>reason
.context/00_INDEX.md	Map of available context surfaces and lazy-load expectations.
```

- Blank lines and `#` comments are ignored.
- The first tab-separated field is the repo-relative path; the reason column is documentation only.

## Packs

| Pack ID | Intended use |
|---|---|
| `core-min` | Smallest lazy-load floor: index, ownership map, latest session lessons |
| `class-a-process` | Class A operational-fit: core-min + process/doc/PR completion rules |
| `class-b-implementation` | Class B reasoning/code: core-min + code quality and doc-sync rules |
| `workflow-risk` | High verification-risk workflow changes: core-min + ADR-016 + sandbox guide |
| `adr-docs` | ADR/docs work: core-min + ADR index/template + model tier + orchestration patterns |
| `pr-review-automation` | Automated pr-review / bot-feedback consolidation surfaces |
| `implementation` | Fix-job libs and ADR-029 §1.1 ordering/failure-semantics invariants |

## Harness usage

```bash
CONTEXT_VARIANT=pack:core-min \
RUN_GROUP=ctx-a-core-min \
make -C scripts/benchmark suite TASK=opfit-281-class-a-premerge BASE=<sha> STAGE=1
```

Unknown pack IDs and unsafe manifest paths fail before any paid agent run.

## Sweet-spot decision rule

```text
sweet_spot_pack =
  highest marginal ROI pack
  with score >= best_score_for_task_class - 2
  and no model-specific degradation > 3 points
  and lower injected bytes/tokens than full-rules injection
```

This is benchmark evidence only — not a production routing change.
