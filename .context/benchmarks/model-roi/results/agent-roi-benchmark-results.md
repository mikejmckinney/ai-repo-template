# Agent ROI Benchmark Results

Issues: #374, #376

Status: blind scores locked for the completed benchmark sessions; sealed alias
mapping and cost addenda appended. This record covers monolithic Stage 1,
extended Stage 1, Stage 1C context injection, Stage 1D duo planner/implementer,
issue #376 orchestration pipeline runs, and Stage 1E targeted context-pack screen
(issue #378). Canonical `cursor-llm-blind-v1` regrades are complete for all of
those stages. Published **Canonical | Objective | Subjective** columns in this file
are the operator source of truth on `main`. Subjective JSON fixtures used to
compile those columns are preserved on git tag `benchmark/phase-a-artifacts-20260608`
(not merged to `main`; see runbook § "Branch and fixture retention").

This file supersedes the earlier local `grading-scores-blind.tsv` `score_10` shorthand files. Those
10-point scores were evaluator notes from blind diff review, not the official #374 weighted scoring
record. The tables below re-score the same blind evidence against the issue-defined categories:
Correctness 30, Code/doc quality 25, Repo-process adherence 20, Tool reliability 15, and Latency 10.

## Score-set comparability

Rows in this file predate the standardized grading pipeline
(`.context/benchmarks/model-roi/grading/`). Treat them as **legacy score cohorts**
unless a row explicitly cites a `score_set_id`.

- Future canonical conclusions must cite `score_set_id`, rubric version (`rubric.v1`),
  and subjective grader prompt version (`model-roi-grader-v1`).
- Stage 1 monolithic, Stage 1C, Stage 1D, pipeline (#376), and Stage 1E CP-1 rows
  include canonical `score_set_id`, objective, and subjective columns alongside legacy
  category scores (regraded via `regrade-stage.sh` / `regrade-stage-1e.sh`).
- Stage 1 monolithic, Stage 1C, Stage 1D, pipeline (#376), and Stage 1E CP-1 rows
  support canonical `score_set_id`, objective, and subjective columns alongside legacy
  category scores once regraded via the `regrade-stage-*.sh` scripts.
- Exploratory Cursor/Codex regrades are separate cohorts for inter-rater analysis;
  do not average them into canonical truth.
- Separate benchmark **execution cost** from **grading LLM cost** in ROI tables when
  subjective graders use paid models.

## Cost Normalization Status

The issue's cost formula is the canonical cost view:

```text
marginal_cost_usd = (input_tok*in_rate + output_tok*out_rate + cached_tok*cached_rate) / 1e6
cost_to_mergeable = marginal_cost_usd + sum(review_loop_costs) + human_rescue_cost
marginal_roi      = weighted_score / cost_to_mergeable

amortized_cost_per_task = monthly_plan_cost_usd / V
amortized_roi           = weighted_score / amortized_cost_per_task
```

Stage 1 has no measured review-loop costs yet, so `sum(review_loop_costs)` is `0` for this stage unless
manual rescue is explicitly recorded. Numeric marginal costs are computed only where the run captured
token telemetry and a current public rate card has enough fields to apply the formula. Copilot costs use
the recovered local `session.shutdown.totalNanoAiu` ledger from `events.jsonl`; captured
`premiumRequests` values are retained only as legacy/diagnostic metadata.

Telemetry normalization used here:

- `input_tok`: fresh/non-cached input tokens. When a runtime reports total input and cached input separately, use `fresh_input = input_tokens - cached_input_tokens` to avoid double-counting cached input.
- `output_tok`: output tokens, including reasoning output when the runtime reports it inside output totals.
- `cached_tok`: cached/cache-read input tokens.
- `token telemetry present`: enough raw token fields exist to compute `marginal_cost_usd` after unseal + rate lookup.
- `token telemetry absent`: runtime did not expose token counts; marginal ROI is `N/A` unless vendor billing exports are supplied.
- `cursor composer 2.5`: Cursor reports input, output, and cache-read tokens; Composer 2.5 Standard pricing is applied as input `$0.50`, cache read `$0.20`, and output `$2.50` per 1M tokens.

Numeric marginal ROI uses **canonical /100** numerators when `final-grades.json` exists for the alias (`stage-1-canonical-v1`, `stage-1c-canonical-v1`, `stage-1d-canonical-v1`, `stage-1-pipeline-canonical-v1`). Extended-stage aliases (`-pipe`, `-injected`, `-duo`) resolve within the matching task class so Class A and Class B rows do not collide on run index. Legacy holistic scores remain in the Legacy /100 column; Objective and Subjective are from the same compiled canonical score set.

## Class A: `opfit-281-class-a-premerge`

Canonical columns: `score_set_id=stage-1-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).
Legacy /100 columns retain the original holistic blind grades for comparison.
Task class: deterministic small/medium repo-process implementation.

Base SHA: `6946d04b3fd17014e32d9da5ea947acf6df14360`

Reference merge SHA: `e8f5f96c44568a32e40ce1995b9ffb80c0009d28`

*Table sort: Sorted by **Canonical /100** (desc).*

| Alias | Run | Gates | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Wall s | Cost status | Summary |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|
| `cand-08` | 1 | pass | 29 | 22 | 19 | 15 | 9 | 94 | 68 | 40 | 28 | `stage-1-canonical-v1` | 118 | token telemetry present | Strong, fast nullglob implementation with recovered Copilot nano-AIU cost. |
| `cand-06` | 1 | pass | 28 | 20 | 17 | 15 | 10 | 90 | 66 | 40 | 26 | `stage-1-canonical-v1` | 138 | token telemetry present | Fastest usable result; quality/process detail trailed the top group. |
| `cand-11` | 2 | pass | 29 | 24 | 18 | 15 | 8 | 94 | 66 | 38 | 28 | `stage-1-canonical-v1` | 269 | token telemetry present | Best extended code quality with duplicate-safe glob handling; small process caveat from superseded invalid-picker run. |
| `cand-12` | 1 | pass | 29 | 24 | 18 | 15 | 5 | 91 | 66 | 36 | 30 | `stage-1-canonical-v1` | 461 | token telemetry present | Strong commented implementation; slower than the top Class A cluster. |
| `cand-05` | 1 | pass | 29 | 24 | 18 | 15 | 4 | 90 | 65 | 34 | 31 | `stage-1-canonical-v1` | 612 | token telemetry present | High-quality diff, but materially slower than the rest of the class. |
| `cand-20` | 2 | pass | 29 | 21 | 19 | 15 | 10 | 94 | 65 | 40 | 25 | `stage-1-canonical-v1` | 96 | token telemetry present; Auto ROI computed | Fastest clean extended result; minimal but correct implementation using explicit Cursor Auto. |
| `cand-01` | 1 | pass | 29 | 22 | 18 | 15 | 9 | 93 | 64 | 38 | 26 | `stage-1-canonical-v1` | 214 | token telemetry present | Strong, concise result; slightly less polished than the top alias but faster. |
| `cand-02` | 1 | pass | 27 | 18 | 16 | 15 | 5 | 81 | 64 | 36 | 28 | `stage-1-canonical-v1` | 509 | token telemetry present | Usable but weaker quality/process fit and slower than most peers. |
| `cand-04` | 1 | pass | 29 | 22 | 18 | 15 | 8 | 92 | 64 | 38 | 26 | `stage-1-canonical-v1` | 338 | token telemetry present | Strong result with direct task coverage and usable telemetry. |
| `cand-18` | 1 | pass | 29 | 23 | 19 | 15 | 8 | 94 | 64 | 38 | 26 | `stage-1-canonical-v1` | 327 | token telemetry present | Strong implementation with good fit to the reference behavior and low process risk. |
| `cand-21` | 5 | pass | 29 | 21 | 17 | 14 | 8 | 89 | 64 | 38 | 26 | `stage-1-canonical-v1` | 274 | token telemetry present; Gemini Auto JSON rerun | Correct direct Gemini JSON auto rerun; routed through Flash Lite utility plus Flash backend, with process/reliability penalties for no candidate commit and one API retry. |
| `cand-07` | 1 | pass | 28 | 20 | 18 | 15 | 8 | 89 | 63 | 38 | 25 | `stage-1-canonical-v1` | 333 | token telemetry present | Correct minimal Copilot implementation; less polished than nullglob/dedupe variants. |
| `cand-10` | 1 | pass | 29 | 22 | 18 | 15 | 7 | 91 | 63 | 36 | 27 | `stage-1-canonical-v1` | 362 | token telemetry present | Correct explicit-glob implementation with medium thinking requested through Cursor prompt directive. |
| `cand-15` | 4 | pass | 29 | 22 | 18 | 15 | 8 | 92 | 63 | 38 | 25 | `stage-1-canonical-v1` | 194 | token telemetry present | Clean Gemini run after earlier harness artifacts; concise correct implementation. |
| `cand-17` | 1 | pass | 28 | 21 | 18 | 15 | 8 | 90 | 63 | 38 | 25 | `stage-1-canonical-v1` | 312 | token telemetry present | Solid implementation with small correctness/quality caveats. |
| `cand-23` | 1 | pass | 29 | 22 | 16 | 12 | 6 | 85 | 63 | 36 | 27 | `stage-1-canonical-v1` | 392 | token telemetry present; default model/rate unknown | Correct Codex default result, penalized for partial/read-only-gitdir run caveat. |
| `cand-03` | 1 | pass | 28 | 20 | 17 | 15 | 7 | 87 | 61 | 36 | 25 | `stage-1-canonical-v1` | 368 | token telemetry present | Good implementation, with more caveats than the top cluster. |
| `cand-14` | 1 | pass | 29 | 21 | 18 | 15 | 6 | 89 | 61 | 36 | 25 | `stage-1-canonical-v1` | 410 | token telemetry present | Clean Codex fixed-model result with correct behavior and minor quality caveats. |
| `cand-19` | 1 | pass | 29 | 22 | 18 | 15 | 6 | 90 | 61 | 36 | 25 | `stage-1-canonical-v1` | 427 | token telemetry present | Correct Copilot Auto result; routed model observed and nano-AIU telemetry recovered. |
| `cand-16` | 4 | pass | 29 | 21 | 18 | 14 | 4 | 86 | 59 | 34 | 25 | `stage-1-canonical-v1` | 653 | token telemetry present | Correct clean Gemini run, but slowest valid Class A extended result and stderr included capacity retry warnings. |
| `cand-24` | 2 | pass | 28 | 20 | 15 | 14 | 9 | 86 | 58 | 33 | 25 | `stage-1-canonical-v1` | 195 | token telemetry present; `gemini-3.5-flash` mapped to backend | Useful fixed Flash run with captured JSON stats; penalized for adding `PLAN.md` to the candidate diff and for the model-picker/backend alias caveat. |
| `cand-09` | 1 | pass | 28 | 18 | 14 | 15 | 8 | 83 | 57 | 32 | 25 | `stage-1-canonical-v1` | 296 | token telemetry present | Correct core fix, but extra `.context`/guide scope noise reduced quality and process scores. |
| `cand-13` | 1 | pass | 28 | 18 | 12 | 12 | 7 | 77 | 55 | 28 | 27 | `stage-1-canonical-v1` | 500 | token telemetry present | Correct core behavior, but state/session artifact noise and partial-run head SHA caveat materially reduced score. |

### Class A Raw Telemetry

*Table sort: Sorted by **Alias** (asc).*

| Alias | Input tok | Output tok | Cached tok | Cache-write tok | Legacy premiumRequests | Session ms | Formula status |
|---|---:|---:|---:|---:|---:|---:|---|
| `cand-01` | 70928 | 15849 | 1300992 |  | 0.33 | 211266 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-02` | 70912 | 13948 | 1828224 |  | 1 | 505866 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-03` | 411 | 11548 | 1799130 | 75388 | 15 | 365411 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-04` | 293 | 9285 | 959877 | 54661 |  |  | computed in sealed marginal table |
| `cand-05` | 338 | 15830 | 3049908 | 89354 |  |  | computed in sealed marginal table |
| `cand-06` | 39342 | 6048 | 574784 | 0 |  |  | Cursor marginal range computed in sealed marginal table |
| `cand-07` | 292064 | 6402 | 2027126 | 0 | 1 | 333000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-08` | 184185 | 2484 | 249106 | 0 | 1 | 118000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-15` | 152772 | 4964 | 445333 |  |  | 49405 API latency | Gemini JSON stats; computed in sealed marginal table |
| `cand-16` | 371059 Pro + 10213 Flash | 11078 Pro + 470 Flash | 952042 Pro + 0 Flash |  |  | 338843 API latency | Gemini JSON stats; output includes candidates + thoughts; computed in sealed marginal table |
| `cand-17` | 94722 fresh / 853506 total | 7055 | 758784 |  |  |  | computed in sealed marginal table |
| `cand-18` | 61526 | 9694 | 1074688 |  | 7.5 | 323865 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-19` | 51224 | 10967 | 1163904 |  | 1 | 427000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-21` | 6273 Flash Lite + 139219 Flash | 760 Flash Lite + 4951 Flash | 0 Flash Lite + 463211 Flash |  |  | 124910 API latency | Gemini JSON stats rerun; output includes candidates + thoughts; computed in sealed marginal table |
| `cand-24` | 119713 | 3935 | 322110 |  |  | 39006 API latency | Gemini JSON stats; requested `gemini-3.5-flash` mapped to observed `gemini-3-flash-preview` backend; computed in sealed marginal table |

### Class A Extended Run Notes

Extended candidates are scored in the main Class A table above. These notes preserve run-selection
caveats that affected the weighted Process/Reliability categories.

*Table sort: Sorted by **Alias** (asc).*

| Alias | Run used | Platform/model mode | Headless outcome | Diff | Notes |
|---|---:|---|---|---|---|
| `cand-07` | 1 | copilot / gemini-3.5-flash | success | 1 file, 9 insertions, 11 deletions | Medium effort requested with Copilot `--effort=medium`. |
| `cand-08` | 1 | copilot / gemini-3.1-pro-preview | success | 1 file, 17 insertions, 10 deletions | Medium effort requested with Copilot `--effort=medium`. |
| `cand-09` | 1 | cursor / gpt-5.4-mini | success | 5 files, 99 insertions, 11 deletions | Medium thinking requested through Cursor inline prompt directive; extra `.context`/guide edits were treated as scope noise. |
| `cand-10` | 1 | cursor / gpt-5.4 | success | 1 file, 19 insertions, 10 deletions | Medium thinking requested through Cursor inline prompt directive; unverifiable by telemetry. |
| `cand-11` | 2 | cursor / claude-opus-4-8-medium | success | 1 file, 26 insertions, 10 deletions | `r1` used invalid picker `claude-opus-4.8`; `r2` used the available Cursor medium picker. |
| `cand-12` | 1 | claude-code / opus | success | 1 file, 30 insertions, 10 deletions | Medium effort approximated through `think-hard(medium)` prompt mechanism. |
| `cand-13` | 1 | codex / gpt-5.4-mini | partial | 6 files, 137 insertions, 34 deletions | Codex medium effort flag applied, but recorded `head_sha` stayed at base despite produced diff/work. |
| `cand-14` | 1 | codex / gpt-5.4 | partial | 1 file, 16 insertions, 10 deletions | Codex medium effort flag applied, but recorded `head_sha` stayed at base despite produced diff/work. |
| `cand-15` | 4 | gemini-cli / gemini-3-flash-preview | success | 1 file, 16 insertions, 10 deletions | `r1`/`r2` failed before valid execution; `r3` included runner-created `.gemini` artifacts; `r4` is the clean run. |
| `cand-16` | 4 | gemini-cli / gemini-3.1-pro-preview | success | 1 file, 28 insertions, 10 deletions | `r1`/`r2` failed before valid execution; `r3` included runner-created `.gemini` artifacts; `r4` is the clean run. Gemini capacity retry warnings appeared in stderr. |
| `cand-19` | 1 | copilot / auto | success | 1 file, 24 insertions, 10 deletions | Invocation used Copilot `--model auto`; Copilot routed the session to `gpt-5.3-codex` in `agent-output.jsonl`. |
| `cand-20` | 2 | cursor / auto | success | 1 file, 10 insertions, 10 deletions | `r1` omitted `--model` and is superseded. `r2` used explicit `--model auto` and records `model:auto(applied)`. |
| `cand-21` | 5 | gemini/agy / auto | success | 1 file, 21 insertions, 10 deletions | `r5` supersedes the earlier clean agy run because the patched adapter used direct `gemini --output-format json` and captured routed-model token stats. |
| `cand-22` | N/A | claude-code / auto | not applicable | N/A | Claude Code does not expose a distinct auto setting. Earlier auto-attempt artifacts failed during prompt parsing and are not valid benchmark runs. |
| `cand-23` | 1 | codex / recommended default | partial | 1 file, 25 insertions, 10 deletions | Codex omits `--model` to use the recommended default. The worktree recorded no commit ahead of base because the candidate reported a read-only gitdir and created an equivalent verifier commit under `/tmp`. |
| `cand-24` | 2 | gemini-cli / gemini-3.5-flash requested | success | 2 files, 74 insertions, 10 deletions | `r1` failed with `ModelNotFoundError` for raw `gemini-3.5-flash`; `r2` maps to the observed `gemini-3-flash-preview` backend while preserving the requested alias in metadata. |

Extended artifact pointers:

- `cand-07/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-07/r1/`
- `cand-08/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-08/r1/`
- `cand-09/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-09/r1/`
- `cand-10/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-10/r1/`
- `cand-11/r2`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-11/r2/`
- `cand-12/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-12/r1/`
- `cand-13/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-13/r1/`
- `cand-14/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-14/r1/`
- `cand-15/r4`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-15/r4/`
- `cand-16/r4`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-16/r4/`
- `cand-19/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-19/r1/`
- `cand-20/r2`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-20/r2/`
- `cand-21/r5`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-21/r5/`
- `cand-22/r1` and `cand-22/r2`: failed prompt-parsing attempts; excluded.
- `cand-23/r1`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-23/r1/`
- `cand-24/r2`: `scripts/benchmark/runs/opfit-281-class-a-premerge/cand-24/r2/`

## Class B: `opfit-326-class-b-premerge`

Canonical columns: `score_set_id=stage-1-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).
Legacy /100 columns retain the original holistic blind grades for comparison.
Task class: harder implementation/reasoning task.

Base SHA: `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6`

Reference merge SHA: `f3145229b2ad8044519ed1c1f88b5f4612d90718`

Canonical columns: `score_set_id=stage-1-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).

*Table sort: Sorted by **Canonical /100** (desc).*

| Alias | Run | Gates | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Wall s | Cost status | Summary |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|
| `cand-20` | 1 | pass | 28 | 22 | 18 | 15 | 10 | 93 | 90 | 58 | 32 | `stage-1-canonical-v1` | 233 | token telemetry present; Auto ROI computed | Strong Cursor Auto result with focused tests, broad helper coverage, and excellent latency. |
| `cand-06` | 1 | pass | 30 | 23 | 19 | 15 | 10 | 97 | 89 | 56 | 33 | `stage-1-canonical-v1` | 303 | token telemetry present | Clear class winner: comprehensive, tested, and fastest, with only size/complexity caution. |
| `cand-11` | 1 | pass | 28 | 22 | 18 | 15 | 8 | 91 | 84 | 54 | 30 | `stage-1-canonical-v1` | 563 | token telemetry present | Strong fixed-model Cursor result with the broadest focused-test coverage among extended candidates. |
| `cand-12` | 2 | pass | 27 | 22 | 18 | 14 | 8 | 89 | 84 | 52 | 32 | `stage-1-canonical-v1` | 750 | token telemetry present | Good Claude Code implementation and tests; reliability score reflects adapter failure in superseded `r1`. |
| `cand-14` | 1 | pass | 26 | 20 | 17 | 14 | 7 | 84 | 84 | 52 | 32 | `stage-1-canonical-v1` | 764 | token telemetry present | Solid Codex fixed-model result with focused tests and helper coverage, though less complete than the top cluster. |
| `cand-23` | 1 | pass | 26 | 20 | 16 | 12 | 8 | 82 | 84 | 52 | 32 | `stage-1-canonical-v1` | 739 | token telemetry present; default model/rate unknown | Useful Codex default result with focused checks, penalized for partial status and read-only-gitdir commit workaround. |
| `cand-09` | 1 | pass | 27 | 20 | 17 | 13 | 7 | 84 | 83 | 52 | 31 | `stage-1-canonical-v1` | 774 | token telemetry present | Substantive solution with several focused tests; self-reported partial status and baseline test failure reduced reliability. |
| `cand-02` | 1 | pass | 28 | 22 | 18 | 15 | 5 | 88 | 82 | 50 | 32 | `stage-1-canonical-v1` | 1154 | token telemetry present | Strong implementation and coverage, but much slower than the top result. |
| `cand-03` | 1 | pass | 22 | 18 | 15 | 13 | 7 | 75 | 82 | 52 | 30 | `stage-1-canonical-v1` | 794 | token telemetry present | Usable partial implementation, with notable coverage and integration gaps. |
| `cand-10` | 1 | pass | 25 | 18 | 17 | 14 | 6 | 80 | 82 | 50 | 32 | `stage-1-canonical-v1` | 912 | token telemetry present | Broad helper implementation but heavier/less focused than stronger peers and only minimal focused-test coverage. |
| `cand-18` | 2 | pass | 23 | 19 | 16 | 13 | 8 | 79 | 82 | 52 | 30 | `stage-1-canonical-v1` | 624 | token telemetry present | Good helper and docs, but narrower API/error-state coverage than stronger candidates. |
| `cand-17` | 2 | pass | 25 | 20 | 16 | 13 | 8 | 82 | 79 | 49 | 30 | `stage-1-canonical-v1` | 662 | token telemetry present | Good substantive implementation; penalized for resumed run and partial behavioral coverage. |
| `cand-04` | 1 | pass | 20 | 16 | 14 | 13 | 3 | 66 | 78 | 48 | 30 | `stage-1-canonical-v1` | 1422 | token telemetry present | Substantive shell helper, but capped/no pagination and weaker API-error handling. |
| `cand-19` | 1 | pass | 26 | 20 | 16 | 14 | 8 | 84 | 78 | 52 | 26 | `stage-1-canonical-v1` | 717 | token telemetry present | Good Copilot Auto implementation and docs; recovered nano-AIU cost enables ROI. |
| `cand-01` | 1 | pass | 17 | 17 | 15 | 13 | 1 | 63 | 76 | 45 | 31 | `stage-1-canonical-v1` | 1788 | token telemetry present | Produced work, but too broad/slow with weaker fit to the reference behavior. |
| `cand-24` | 1 | pass | 25 | 20 | 15 | 14 | 10 | 84 | 76 | 55 | 21 | `stage-1-canonical-v1` | 281 | token telemetry present; `gemini-3.5-flash` mapped to backend | Useful fixed Flash backend run with helper/tests and strong cost telemetry; penalized for `PLAN.md`, broader scope, and a reported full-suite failure tied to existing version drift. |
| `cand-13` | 1 | pass | 24 | 19 | 16 | 14 | 3 | 76 | 74 | 48 | 26 | `stage-1-canonical-v1` | 1413 | token telemetry present | Produced meaningful Codex work, but slowest extended run and weaker head-SHA/error-state evidence. |
| `cand-07` | 1 | pass | 25 | 19 | 17 | 14 | 6 | 81 | 72 | 47 | 25 | `stage-1-canonical-v1` | 1025 | token telemetry present | Substantive Copilot result, but slower and thinner focused-test coverage than stronger extended candidates. |
| `cand-15` | 1 | pass | 26 | 20 | 16 | 15 | 10 | 87 | 68 | 50 | 18 | `stage-1-canonical-v1` | 336 | token telemetry present | Fast Gemini result with useful helper/tests, penalized for broader-than-needed compliance-plan/schema edits. |
| `cand-16` | 1 | pass | 22 | 17 | 14 | 10 | 7 | 70 | 67 | 46 | 21 | `stage-1-canonical-v1` | 628 | token telemetry present | Implemented core helper pieces but lacked focused Bats coverage, reducing process and reliability confidence. |
| `cand-21` | 2 | pass | 27 | 21 | 16 | 14 | 10 | 88 | 63 | 43 | 20 | `stage-1-canonical-v1` | 334 | token telemetry present; Gemini Auto JSON rerun | Good direct Gemini JSON auto rerun with useful helper/docs/tests and captured stats; process score reflects broader prompt/AGENTS fixture edits. |
| `cand-08` | 1 | pass | 23 | 17 | 16 | 14 | 6 | 76 | 59 | 43 | 16 | `stage-1-canonical-v1` | 986 | token telemetry present | Compact Copilot result with basic coverage; less complete than peer extended implementations. |
| `cand-05` | 1 | fail: acceptance | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `stage-1-canonical-v1` | 646 | token telemetry present | Disqualified from ROI ranking because the run produced no diff/work. Runtime remains useful as a cost/reliability signal. |

### Class B Extended Run Notes

Extended candidates are scored in the main Class B table above. These notes preserve run-selection
caveats that affected the weighted Process/Reliability categories.

*Table sort: Sorted by **Alias** (asc).*

| Alias | Run used | Platform/model mode | Headless outcome | Wall s | Diff | Notes |
|---|---:|---|---|---:|---|---|
| `cand-07` | 1 | copilot / gemini-3.5-flash | success | 1025 | 11 files, 693 insertions, 5 deletions | Produced substantive helper/docs/tests, but focused coverage was thin relative to stronger extended candidates. |
| `cand-08` | 1 | copilot / gemini-3.1-pro-preview | success | 986 | 10 files, 193 insertions, 6 deletions | Compact result with basic polling coverage; less complete than peer extended runs. |
| `cand-09` | 1 | cursor / gpt-5.4-mini | success | 774 | 8 files, 745 insertions, 9 deletions | Focused checks passed, but candidate self-reported partial status due baseline `./test.sh` failures. |
| `cand-10` | 1 | cursor / gpt-5.4 | success | 912 | 9 files, 940 insertions, 13 deletions | Broad helper implementation with limited focused-test count and heavier-than-reference diff. |
| `cand-11` | 1 | cursor / claude-opus-4-8-medium | success | 563 | 11 files, 671 insertions, 1 deletion | Strongest extended fixed-model coverage signal; 11 focused polling tests. |
| `cand-12` | 2 | claude-code / opus | success | 750 | 7 files, 457 insertions | `r1` failed from Claude adapter prompt parsing; `r2` is the valid run after adapter fix. |
| `cand-13` | 1 | codex / gpt-5.4-mini | success | 1413 | 10 files, 545 insertions, 2 deletions | Produced meaningful work but was slowest and showed weaker head-SHA/error-state evidence in the scanned helper signals. |
| `cand-14` | 1 | codex / gpt-5.4 | success | 764 | 11 files, 569 insertions, 2 deletions | Solid helper/docs/tests with broad polling coverage. |
| `cand-15` | 1 | gemini-cli / gemini-3-flash-preview | success | 336 | 11 files, 484 insertions, 7 deletions | Fast and useful, but included broader compliance-plan/schema edits outside the narrow reference shape. |
| `cand-16` | 1 | gemini-cli / gemini-3.1-pro-preview | success | 628 | 5 files, 198 insertions, 2 deletions | No focused Bats coverage was produced, limiting confidence despite core helper changes. |
| `cand-19` | 1 | copilot / auto | success | 717 | 12 files, 644 insertions, 8 deletions | Copilot Auto run produced useful helper/docs/tests; nano-AIU telemetry recovered for ROI. |
| `cand-20` | 1 | cursor / auto | success | 233 | 8 files, 598 insertions, 7 deletions | Explicit Cursor Auto run with strong helper/test signal and excellent latency. |
| `cand-21` | 2 | gemini/agy / auto | success | 334 | 8 files, 247 insertions, 15 deletions | Direct Gemini JSON auto rerun captured token/model stats; useful helper/docs/tests, but broader prompt/AGENTS fixture edits counted as process caveats. |
| `cand-23` | 1 | codex / recommended default | success | 739 | 10 files, 517 insertions, 3 deletions | Focused checks passed, but candidate self-reported partial status and used a read-only-gitdir workaround. |
| `cand-24` | 1 | gemini-cli / gemini-3.5-flash requested | success | 281 | 7 files, 468 insertions | Direct Gemini JSON run mapped the requested alias to the observed `gemini-3-flash-preview` backend; useful but included `PLAN.md` and broader prompt/docs edits. |

### Class B Raw Telemetry

*Table sort: Sorted by **Alias** (asc).*

| Alias | Input tok | Output tok | Cached tok | Cache-write tok | Legacy premiumRequests | Session ms | Formula status |
|---|---:|---:|---:|---:|---:|---:|---|
| `cand-01` | 763386 | 120456 | 11746816 |  | 0.33 | 1784328 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-02` | 156202 | 57952 | 6142336 |  | 1 | 1151809 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-03` | 11055 | 44687 | 4443872 | 146102 | 15 | 791342 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-04` | 55 | 65214 | 6341578 | 156510 |  |  | computed in sealed marginal table |
| `cand-05` | 1894 | 13169 | 3711549 | 101420 |  |  | computed in sealed marginal table; score is disqualified |
| `cand-06` | 75963 | 12236 | 1701886 | 0 |  |  | Cursor marginal range computed in sealed marginal table |
| `cand-07` | 1482786 | 43391 | 9062726 | 0 | 1 | 1025000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-08` | 802376 | 9106 | 5400511 | 0 | 1 | 986000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-15` | 492031 | 13017 | 1080733 |  |  | 130052 API latency | Gemini JSON stats; computed in sealed marginal table |
| `cand-16` | 819270 Pro + 19264 Flash | 29593 Pro + 1136 Flash | 3220506 Pro + 0 Flash |  |  | 486120 API latency | Gemini JSON stats; output includes candidates + thoughts; computed in sealed marginal table |
| `cand-17` | 151150 fresh / 3065070 total | 23746 | 2913920 |  |  |  | computed in sealed marginal table |
| `cand-18` | 137289 | 23921 | 2461696 |  | 7.5 | 614522 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-19` | 280702 | 81147 | 8178176 |  | 0.33 | 717000 | Copilot `session.shutdown` nano AIU; computed in sealed marginal table |
| `cand-21` | 6909 Flash Lite + 440999 Flash | 1521 Flash Lite + 23867 Flash | 0 Flash Lite + 2575963 Flash |  |  | 200355 API latency | Gemini JSON stats rerun; output includes candidates + thoughts; computed in sealed marginal table |
| `cand-24` | 249305 | 22881 | 1876668 |  |  | 188400 API latency | Gemini JSON stats; requested `gemini-3.5-flash` mapped to observed `gemini-3-flash-preview` backend; computed in sealed marginal table |

## Per-Candidate Record Shape

Each row above maps to the issue result-record requirements:

- Run metadata: alias, task id/class, run index, base SHA, head SHA in `result.json`, and local-only artifact paths under `scripts/benchmark/runs/<task>/<alias>/r<run>/`.
- Hard gates: summarized in `Gates`; `cand-05` Class B fails acceptance due no produced work.
- Weighted score: represented by the five category columns plus `Total /100`.
- Cost: raw telemetry recorded above; numeric marginal ROI is computed below where telemetry and rates are sufficient. Amortized ROI is pending a chosen monthly plan cost and task volume `V`.
- Summary judgment: captured in the `Summary` column.

## Sealed Alias Mapping

Scores above were locked before this mapping was added.

*Table sort: Sorted by **Alias** (asc).*

| Alias | Platform | Model | Agent/runtime | Effort requested | Effort status | Effort applied |
|---|---|---|---|---|---|---|
| `cand-01` | copilot | gpt-5.4-mini | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-02` | copilot | gpt-5.4 | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-03` | copilot | claude-opus-4.8 | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-04` | claude-code | sonnet | claude-code-cli | medium | approximated | prompt:`think-hard(medium)` |
| `cand-05` | claude-code | haiku | claude-code-cli | medium | approximated | prompt:`think-hard(medium)` |
| `cand-06` | cursor | composer-2.5 | cursor-cli | medium | requested | prompt:inline directive, unverified |
| `cand-07` | copilot | gemini-3.5-flash | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-08` | copilot | gemini-3.1-pro-preview | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-09` | cursor | gpt-5.4-mini | cursor-cli | medium | requested | prompt:inline-directive(gpt-5.4-mini+medium-thinking;unverified) |
| `cand-10` | cursor | gpt-5.4 | cursor-cli | medium | requested | prompt:inline-directive(gpt-5.4+medium-thinking;unverified) |
| `cand-11` | cursor | claude-opus-4-8-medium | cursor-cli | medium | requested | prompt:inline-directive(claude-opus-4-8-medium+medium-thinking;unverified) |
| `cand-12` | claude-code | opus | claude-code-cli | medium | approximated | prompt:`think-hard(medium)` |
| `cand-13` | codex | gpt-5.4-mini | codex-cli | medium | applied | flag:`model_reasoning_effort=medium` |
| `cand-14` | codex | gpt-5.4 | codex-cli | medium | applied | flag:`model_reasoning_effort=medium` |
| `cand-15` | gemini-cli | gemini-3-flash-preview | gemini-cli | medium | applied | config:`thinkingLevel=medium` |
| `cand-16` | gemini-cli | gemini-3.1-pro-preview | gemini-cli | medium | applied | config:`thinkingLevel=medium` |
| `cand-17` | codex | gpt-5.5 | codex-cli | medium | applied | flag:`model_reasoning_effort=medium` |
| `cand-18` | copilot | gpt-5.5 | copilot-cli | medium | applied | flag:`--effort=medium` |
| `cand-19` | copilot | auto, routed to `gpt-5.3-codex` | copilot-cli | default | applied for model selection | flag:`--model auto`; no explicit effort flag |
| `cand-20` | cursor | auto | cursor-cli | default | applied for model selection | flag:`--model auto`; no explicit effort directive |
| `cand-21` | gemini/agy | auto, routed to Flash Lite utility + Flash backend in JSON rerun | gemini primary, agy fallback | default | applied for model selection | direct `gemini --output-format json` with model omitted; no exposed thinking control |
| `cand-22` | claude-code | N/A | claude-code-cli | N/A | not applicable | Claude Code has no distinct auto setting; failed prompt-parsing attempts excluded |
| `cand-23` | codex | recommended default, model omitted | codex-cli | default | default model selection | omitted `--model`; Codex selected its recommended default |
| `cand-24` | gemini/agy | gemini-3.5-flash requested; observed `gemini-3-flash-preview` backend | gemini-cli | medium | mapped/applied | adapter maps unavailable picker alias to JSON-observed backend; config:`thinkingLevel=medium` |

## Sealed Marginal Cost And ROI

Rate sources checked on 2026-06-04:

Cost source register:

*Table sort: Sorted by **Platform / rows** (asc).*

| Platform / rows | Source URL(s) | Rates applied | Audit caveat |
|---|---|---|---|
| Anthropic / Claude Code rows | [Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing) | Opus 4.8: `$5` input, `$10` 1h cache write, `$0.50` cache read, `$25` output. Sonnet 4.x: `$3` input, `$6` 1h cache write, `$0.30` cache read, `$15` output. Haiku 4.5: `$1` input, `$2` 1h cache write, `$0.10` cache read, `$5` output. All per 1M tokens. Claude Code runtime adds `$0.08/hour`, prorated by wall time. | Uses Claude Code reported token-cost telemetry where available, plus runtime. Family-level labels (`sonnet`, `haiku`, `opus`) are mapped to the observed or current family rate; reconcile with Claude Code export if exact snapshot billing differs. |
| Cursor Composer / Auto rows | [Cursor Models & Pricing](https://cursor.com/docs/models-and-pricing), [Cursor pricing policy](https://cursor.com/terms/pricing/), [Composer 2.5 changelog](https://cursor.com/changelog/composer-2-5) | Composer 2.5 Standard: `$0.50` input, `$0.20` cache read, `$2.50` output per 1M tokens. Cursor Auto: `$1.25` input/cache-write, `$0.25` cache-read, `$6.00` output per 1M tokens. | Cursor fixed-model rows are API-rate estimates from captured Cursor token telemetry and should be reconciled against the Cursor dashboard. Composer 2.5 Fast is not applied unless run metadata explicitly proves Fast-mode selection. |
| Cursor named provider rows | [Cursor Models & Pricing](https://cursor.com/docs/models-and-pricing), plus the underlying provider rate card above | Captured Cursor token telemetry multiplied by the named model's public provider/API rates. | These are estimates because Cursor account billing can differ from raw provider API billing depending on pool, mode, and account terms. Dashboard export is the final bill-of-record. |
| Gemini CLI fixed-model rows | [Gemini Developer API pricing](https://ai.google.dev/gemini-api/docs/pricing), [Vertex AI Gemini pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) | Gemini 3 Flash Preview: `$0.50` input, `$0.05` cached, `$3.00` output. Gemini 3.1 Flash Lite: `$0.25` input, `$0.025` cached, `$1.50` output. Gemini 3.1 Pro Preview: `$2.00` input, `$0.20` cached, `$12.00` output. All per 1M tokens. | Uses captured JSON `.stats.models[*].tokens`; output cost uses `.tokens.candidates + .tokens.thoughts` because Google prices output including thinking tokens. Gemini 3.1 Pro uses the `<=200k` prompt tier as an aggregate estimate because saved stats do not expose per-request prompt length. `cand-24` requested the `gemini-3.5-flash` picker alias, but direct JSON telemetry reported `gemini-3-flash-preview`; ROI is computed from the observed backend. |
| Gemini/agy auto rows | [Gemini Developer API pricing](https://ai.google.dev/gemini-api/docs/pricing), [Vertex AI Gemini pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) | Uses the routed model rates from captured JSON stats when present: Flash Lite utility-router tokens plus Flash Preview main-loop tokens in the rerun rows. | Legacy agy-only runs did not expose token stats, but the patched adapter now tries direct `gemini --output-format json` first so future auto rows can capture `response` and `stats`. |
| GitHub Copilot rows | [Copilot billing](https://docs.github.com/en/billing/concepts/product-billing/github-copilot-billing), [Copilot models and pricing](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) | GitHub AI Credits: `1 credit = $0.01`; Copilot `session.shutdown.totalNanoAiu` is converted with `cost_usd = totalNanoAiu / 1e11`. | Uses local `/home/codespace/.copilot/session-state/<session-id>/events.jsonl` `session.shutdown` telemetry. `totalPremiumRequests` is retained as legacy/diagnostic metadata, but ROI cost uses `totalNanoAiu` because Copilot now bills with AI credits. |
| OpenAI / Codex rows | [GPT-5.4 mini](https://developers.openai.com/api/docs/models/gpt-5.4-mini), [GPT-5.4](https://developers.openai.com/api/docs/models/gpt-5.4), [GPT-5.5](https://developers.openai.com/api/docs/models/gpt-5.5/) | GPT-5.4 mini: `$0.75` input, `$0.075` cached, `$4.50` output. GPT-5.4: `$2.50` input, `$0.25` cached, `$15.00` output. GPT-5.5: `$5.00` input, `$0.50` cached, `$30.00` output. All per 1M tokens. | Uses fresh input = total input minus cached input. GPT-5.4/GPT-5.5 long-context surcharges are not applied unless per-run telemetry proves the prompt threshold was crossed. Codex recommended-default rows remain `N/A` until the selected model/rate is sealed. |

Refresh this register before publishing final benchmark conclusions, before starting a new benchmark stage,
or whenever a vendor pricing page changes. If billing exports disagree with this source register, preserve
the source-register estimate and add a billing-export reconciliation note rather than overwriting the
historical calculation silently.

### Class A Marginal ROI

*Table sort: Sorted by **Marginal ROI** (desc); non-numeric ROI last.*

| Alias | Platform/model | Legacy /100 | Canonical /100 | Objective | Subjective | Marginal cost USD | Marginal ROI | Cost caveat |
|---|---|---:|---:|---:|---:|---:|---:|---|
| `cand-24` | gemini-cli / gemini-3.5-flash requested (`gemini-3-flash-preview` observed) | 86 | 58 | 33 | 25 | `$0.087767` | `660.84` | Uses Gemini JSON stats; requested picker alias was unavailable directly, so adapter mapped to observed `gemini-3-flash-preview` backend. |
| `cand-21` | gemini/agy / auto, routed through Flash Lite + Flash backend | 89 | 64 | 38 | 26 | `$0.110331` | `580.07` | Uses rerun Gemini JSON stats with per-model rates: Flash Lite utility-router tokens plus Flash Preview main-loop tokens. |
| `cand-15` | gemini-cli / gemini-3-flash-preview | 92 | 63 | 38 | 25 | `$0.113545` | `554.85` | Uses Gemini JSON stats: input `$0.50`, cache read `$0.05`, output/thinking `$3.00` per 1M. |
| `cand-06` | cursor / composer-2.5 | 90 | 66 | 40 | 26 | `$0.149748` | `440.74` | Uses Cursor Composer 2.5 Standard pricing: input `$0.50`, cache read `$0.20`, output `$2.50` per 1M. |
| `cand-06-injected` | cursor / composer-2.5 context-injected | 92 | 68 | 38 | 30 | `$0.169864` | `400.32` | Stage 1C full-rules injection; uses Cursor Composer 2.5 Standard pricing. |
| `cand-05-injected` | claude-code / haiku context-injected | 93 | 66 | 38 | 28 | `$0.207365` | `318.28` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-01` | copilot / gpt-5.4-mini | 93 | 64 | 38 | 26 | `$0.222091` | `288.17` | Uses Copilot `session.shutdown.totalNanoAiu` from session `f939e562-4f1d-4870-8e8c-d72b6230aaa2`. |
| `cand-20` | cursor / auto | 94 | 65 | 40 | 25 | `$0.320794` | `202.62` | Uses Cursor Auto pricing from captured tokens: input/cache-write `$1.25`, cache-read `$0.25`, output `$6.00` per 1M. |
| `cand-20-pipe` | cursor / auto pipeline | 87 | 62 | 33 | 29 | `$0.312429` | `198.45` | Issue #376 pipeline run; uses Cursor Auto pricing from captured tokens. |
| `cand-21-duo` | gemini/agy / auto duo planner+implementer | 82 | 65 | 38 | 27 | `$0.342674` | `189.68` | Stage 1D duo run; uses Gemini JSON stats with Flash Lite router tokens plus Flash Preview main-loop tokens. |
| `cand-20-duo` | cursor / auto duo planner+implementer | 84 | 66 | 36 | 30 | `$0.361981` | `182.33` | Stage 1D duo run; sums Cursor Auto planner and implementer token telemetry. |
| `cand-19-injected` | copilot / auto context-injected | 91 | 64 | 38 | 26 | `$0.373056` | `171.56` | Stage 1C full-rules injection; uses Copilot `session.shutdown.totalNanoAiu`. |
| `cand-20-injected` | cursor / auto context-injected | 92 | 68 | 38 | 30 | `$0.426560` | `159.41` | Stage 1C full-rules injection; uses Cursor Auto pricing from captured tokens. |
| `cand-09` | cursor / gpt-5.4-mini | 83 | 57 | 32 | 25 | `$0.368390` | `154.73` | API-rate estimate from captured Cursor tokens; reconcile with Cursor dashboard. |
| `cand-08` | copilot / gemini-3.1-pro-preview | 94 | 68 | 40 | 28 | `$0.447999` | `151.79` | Uses Copilot `session.shutdown.totalNanoAiu` from session `ebee2880-9033-4d6d-a728-50ee8fd896dc`. |
| `cand-19` | copilot / auto, routed to gpt-5.3-codex | 90 | 61 | 36 | 25 | `$0.402177` | `151.67` | Uses Copilot `session.shutdown.totalNanoAiu`; routed model observed in session output. |
| `cand-05-pipe` | claude-code / haiku pipeline | 77 | 55 | 27 | 28 | `$0.366020` | `150.27` | Issue #376 pipeline run; uses Claude Code reported token cost. |
| `cand-13` | codex / gpt-5.4-mini | 77 | 55 | 28 | 27 | `$0.370886` | `148.29` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-13-injected` | codex / gpt-5.4-mini context-injected | 78 | 58 | 30 | 28 | `$0.391716` | `148.07` | Stage 1C full-rules injection; uses fresh input = total input minus cached input. |
| `cand-12-duo` | claude-code / opus planner + haiku implementer | 91 | 64 | 38 | 26 | `$0.464986` | `137.64` | Stage 1D duo run; sums Claude Code reported token cost plus prorated runtime. |
| `cand-19-duo` | copilot / auto duo planner+implementer | 88 | 64 | 38 | 26 | `$0.475459` | `134.61` | Stage 1D duo run; uses retained Copilot planner+implementer `session.shutdown.totalNanoAiu`. |
| `cand-14-duo` | codex / GPT-5.4 planner + GPT-5.4 mini implementer | 78 | 53 | 30 | 23 | `$0.441885` | `119.94` | Stage 1D duo run; uses GPT-5.4 planner rates plus GPT-5.4 mini implementer rates. |
| `cand-05` | claude-code / haiku | 90 | 65 | 34 | 31 | `$0.576787` | `112.69` | Includes `$0.563187` token cost + `$0.013600` runtime; model label is family-level. |
| `cand-04` | claude-code / sonnet | 92 | 64 | 38 | 26 | `$0.763594` | `83.81` | Includes `$0.756083` token cost + `$0.007511` runtime; model label is family-level. |
| `cand-10` | cursor / gpt-5.4 | 91 | 63 | 36 | 27 | `$0.771208` | `81.69` | API-rate estimate from captured Cursor tokens; reconcile with Cursor dashboard. |
| `cand-14` | codex / gpt-5.4 | 89 | 61 | 36 | 25 | `$0.760133` | `80.25` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-07` | copilot / gemini-3.5-flash | 89 | 63 | 38 | 25 | `$0.799783` | `78.77` | Uses Copilot `session.shutdown.totalNanoAiu` from session `f0a35e5b-db47-4b7d-9ab3-e8d30f4fb8b9`. |
| `cand-02` | copilot / gpt-5.4 | 81 | 64 | 36 | 28 | `$0.843556` | `75.87` | Uses Copilot `session.shutdown.totalNanoAiu` from session `163c982d-0c47-43c7-93fb-532dcd829c08`. |
| `cand-17` | codex / gpt-5.5 | 90 | 63 | 38 | 25 | `$1.064652` | `59.17` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-12-injected` | claude-code / opus context-injected | 93 | 68 | 38 | 30 | `$1.150626` | `59.10` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-18` | copilot / gpt-5.5 | 94 | 64 | 38 | 26 | `$1.135794` | `56.35` | Uses Copilot `session.shutdown.totalNanoAiu` from session `8575a0eb-8454-4a4e-998b-5408dddd68ff`. |
| `cand-16` | gemini-cli / gemini-3.1-pro-preview | 86 | 59 | 34 | 25 | `$1.071979` | `55.04` | Uses Gemini JSON stats; Pro cost estimated at `<=200k` prompt tier plus observed Flash helper usage. |
| `cand-04-injected` | claude-code / sonnet context-injected | 91 | 66 | 36 | 30 | `$1.230982` | `53.62` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-12` | claude-code / opus | 91 | 66 | 36 | 30 | `$1.302635` | `50.67` | Includes `$1.292391` reported token cost + `$0.010244` runtime; model label is family-level. |
| `cand-11` | cursor / claude-opus-4.8 | 94 | 66 | 38 | 28 | `$1.406774` | `46.92` | API-rate estimate from captured Cursor tokens, including cache-write tokens; reconcile with Cursor dashboard. |
| `cand-03-pipe` | copilot / claude-opus-4.8 pipeline | 94 | 61 | 31 | 30 | `$1.558170` | `39.15` | Issue #376 pipeline run; uses Copilot `session.shutdown.totalNanoAiu`. |
| `cand-03` | copilot / claude-opus-4.8 | 87 | 61 | 36 | 25 | `$1.661495` | `36.71` | Uses Copilot `session.shutdown.totalNanoAiu` from session `3264166e-5a28-4f24-a7b0-b228b4b77260`. |
| `cand-12-pipe` | claude-code / opus pipeline | 86 | 59 | 29 | 30 | `$1.761853` | `33.49` | Issue #376 pipeline run; uses Claude Code reported token cost. |
| `cand-21-injected` | gemini/agy / auto context-injected | 84 | 56 | 32 | 24 | `N/A` | N/A | Stage 1C full-rules injection; Gemini token telemetry absent. |
| `cand-21-pipe` | gemini/agy / auto pipeline | 73 | 48 | 23 | 25 | `N/A` | N/A | Issue #376 pipeline run; Gemini routed-model/token stats need session recovery. |
| `cand-23` | codex / recommended default | 85 | 63 | 36 | 27 | `N/A` | N/A | Codex token telemetry present, but selected default model/rate is not sealed. |

### Class B Marginal ROI

*Table sort: Sorted by **Marginal ROI** (desc); non-numeric ROI last.*

| Alias | Platform/model | Legacy /100 | Canonical /100 | Objective | Subjective | Marginal cost USD | Marginal ROI | Cost caveat |
|---|---|---:|---:|---:|---:|---:|---:|---|
| `cand-24` | gemini-cli / gemini-3.5-flash requested (`gemini-3-flash-preview` observed) | 84 | 76 | 55 | 21 | `$0.287129` | `264.69` | Uses Gemini JSON stats; requested picker alias was unavailable directly, so adapter mapped to observed `gemini-3-flash-preview` backend. |
| `cand-06` | cursor / composer-2.5 | 97 | 89 | 56 | 33 | `$0.408949` | `217.63` | Uses Cursor Composer 2.5 Standard pricing: input `$0.50`, cache read `$0.20`, output `$2.50` per 1M. |
| `cand-15` | gemini-cli / gemini-3-flash-preview | 87 | 68 | 50 | 18 | `$0.339103` | `200.53` | Uses Gemini JSON stats: input `$0.50`, cache read `$0.05`, output/thinking `$3.00` per 1M. |
| `cand-05-agents` | claude-code / haiku AGENTS-import-only | 64 | 67 | 52 | 15 | `$0.336678` | `199.00` | Stage 1C isolation run; default `AGENTS.md` plus `@AGENTS.md` in `CLAUDE.md`. |
| `cand-21` | gemini/agy / auto, routed through Flash Lite + Flash backend | 88 | 63 | 43 | 20 | `$0.424907` | `148.27` | Uses rerun Gemini JSON stats with per-model rates: Flash Lite utility-router tokens plus Flash Preview main-loop tokens. |
| `cand-20` | cursor / auto | 93 | 90 | 58 | 32 | `$0.616344` | `146.02` | Uses Cursor Auto pricing from captured tokens: input/cache-write `$1.25`, cache-read `$0.25`, output `$6.00` per 1M. |
| `cand-21-duo` | gemini/agy / auto duo planner+implementer | 75 | 72 | 50 | 22 | `$0.517891` | `139.03` | Stage 1D duo run; uses Gemini JSON stats with Flash Lite router tokens plus Flash Preview main-loop tokens. |
| `cand-19-injected` | copilot / auto context-injected | 76 | 67 | 52 | 15 | `$0.503979` | `132.94` | Stage 1C full-rules injection; uses Copilot `session.shutdown.totalNanoAiu`. |
| `cand-05-injected` | claude-code / haiku context-injected | 72 | 66 | 50 | 16 | `$0.508275` | `129.85` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-20-pipe` | cursor / auto pipeline | 90 | 82 | 50 | 32 | `$0.632973` | `129.55` | Issue #376 pipeline run; uses Cursor Auto pricing from captured tokens. |
| `cand-06-injected` | cursor / composer-2.5 context-injected | 96 | 92 | 58 | 34 | `$0.743520` | `123.74` | Stage 1C full-rules injection; uses Cursor Composer 2.5 Standard pricing. |
| `cand-20-duo` | cursor / auto duo planner+implementer | 88 | 87 | 58 | 29 | `$0.714514` | `121.76` | Stage 1D duo run; sums Cursor Auto planner and implementer token telemetry. |
| `cand-19-duo` | copilot / auto duo planner+implementer | 84 | 71 | 51 | 20 | `$0.689384` | `102.99` | Stage 1D duo run; uses retained Copilot planner+implementer `session.shutdown.totalNanoAiu`. |
| `cand-20-injected` | cursor / auto context-injected | 95 | 90 | 58 | 32 | `$0.950754` | `94.66` | Stage 1C full-rules injection; uses Cursor Auto pricing from captured tokens. |
| `cand-19` | copilot / auto | 84 | 78 | 52 | 26 | `$1.070146` | `72.89` | Uses Copilot `session.shutdown.totalNanoAiu` from session `3350f201-0c31-4648-ba3b-1355f257d26f`. |
| `cand-13-injected` | codex / gpt-5.4-mini context-injected | 78 | 77 | 48 | 29 | `$1.128873` | `68.21` | Stage 1C full-rules injection; uses fresh input = total input minus cached input. |
| `cand-09` | cursor / gpt-5.4-mini | 84 | 83 | 52 | 31 | `$1.251805` | `66.30` | API-rate estimate from captured Cursor tokens; reconcile with Cursor dashboard. |
| `cand-14` | codex / gpt-5.4 | 84 | 84 | 52 | 32 | `$1.637274` | `51.30` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-13` | codex / gpt-5.4-mini | 76 | 74 | 48 | 26 | `$1.755668` | `42.15` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-01` | copilot / gpt-5.4-mini | 63 | 76 | 45 | 31 | `$1.995603` | `38.08` | Uses Copilot `session.shutdown.totalNanoAiu` from session `6987e6c5-3f0d-4ac8-97f1-e4036e8021f4`. |
| `cand-14-duo` | codex / GPT-5.4 planner + GPT-5.4 mini implementer | 83 | 80 | 48 | 32 | `$2.227744` | `35.91` | Stage 1D duo run; uses GPT-5.4 planner rates plus GPT-5.4 mini implementer rates. |
| `cand-18` | copilot / gpt-5.5 | 79 | 82 | 52 | 30 | `$2.634923` | `31.12` | Uses Copilot `session.shutdown.totalNanoAiu` from session `2f791671-2884-4bde-a5c1-579ce7a7ff85`. |
| `cand-02` | copilot / gpt-5.4 | 88 | 82 | 50 | 32 | `$2.795369` | `29.33` | Uses Copilot `session.shutdown.totalNanoAiu` from session `6fd2f33c-a1a6-43c2-b87a-54837f199489`. |
| `cand-17` | codex / gpt-5.5 | 82 | 79 | 49 | 30 | `$2.925090` | `27.01` | Uses fresh input = total input minus cached input to avoid double-counting cache hits. |
| `cand-12-duo` | claude-code / opus planner + haiku implementer | 72 | 52 | 40 | 12 | `$2.008018` | `25.90` | Stage 1D duo run; sums Claude Code reported token cost plus prorated runtime. |
| `cand-16` | gemini-cli / gemini-3.1-pro-preview | 70 | 67 | 46 | 21 | `$2.650797` | `25.28` | Uses Gemini JSON stats; Pro cost estimated at `<=200k` prompt tier plus observed Flash helper usage. |
| `cand-04-injected` | claude-code / sonnet context-injected | 82 | 78 | 48 | 30 | `$3.312117` | `23.55` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-10` | cursor / gpt-5.4 | 80 | 82 | 50 | 32 | `$3.752994` | `21.85` | API-rate estimate from captured Cursor tokens; reconcile with Cursor dashboard. |
| `cand-11` | cursor / claude-opus-4.8 | 91 | 84 | 54 | 30 | `$3.944440` | `21.30` | API-rate estimate from captured Cursor tokens, including cache-write tokens; reconcile with Cursor dashboard. |
| `cand-08` | copilot / gemini-3.1-pro-preview | 76 | 59 | 43 | 16 | `$2.794126` | `21.12` | Uses Copilot `session.shutdown.totalNanoAiu` from session `c733aa3e-9231-4c40-8014-7d1e5d28f356`. |
| `cand-04` | claude-code / sonnet | 66 | 78 | 48 | 30 | `$3.851508` | `20.25` | Includes `$3.819908` token cost + `$0.031600` runtime; model label is family-level. |
| `cand-12` | claude-code / opus | 89 | 84 | 52 | 32 | `$4.147855` | `20.25` | Includes `$4.131188` reported token cost + `$0.016667` runtime; model label is family-level. |
| `cand-12-injected` | claude-code / opus context-injected | 89 | 84 | 52 | 32 | `$4.242677` | `19.80` | Stage 1C full-rules injection; uses Claude Code reported token cost. |
| `cand-03` | copilot / claude-opus-4.8 | 75 | 82 | 52 | 30 | `$4.307524` | `19.04` | Uses Copilot `session.shutdown.totalNanoAiu` from session `cde4bd73-b2e9-403b-8831-42c3afc5e48d`. |
| `cand-07` | copilot / gemini-3.5-flash | 81 | 72 | 47 | 25 | `$3.974107` | `18.12` | Uses Copilot `session.shutdown.totalNanoAiu` from session `eae16ea7-0c95-4e77-b833-06f7bb680199`. |
| `cand-12-pipe` | claude-code / opus pipeline | 81 | 76 | 44 | 32 | `$8.202184` | `9.27` | Issue #376 pipeline run; uses Claude Code reported token cost. |
| `cand-03-pipe` | copilot / claude-opus-4.8 pipeline | 84 | 73 | 42 | 31 | `$8.172126` | `8.93` | Issue #376 pipeline run; uses Copilot `session.shutdown.totalNanoAiu`. |
| `cand-05-pipe` | claude-code / haiku pipeline | 0 | 0 | 0 | 0 | `$0.470430` | `0.00` | Issue #376 pipeline run; no candidate work produced. |
| `cand-05` | claude-code / haiku | 0 | 0 | 0 | 0 | `$0.656090` | `0.00` | Includes `$0.641734` token cost + `$0.014356` runtime; disqualified for no produced work. |
| `cand-21-injected` | gemini/agy / auto context-injected | 84 | N/A | N/A | N/A | `N/A` | N/A | Stage 1C full-rules injection; Gemini token telemetry absent. |
| `cand-21-pipe` | gemini/agy / auto pipeline | 58 | 61 | 37 | 24 | `N/A` | N/A | Issue #376 pipeline run; Gemini routed-model/token stats need session recovery. |
| `cand-23` | codex / recommended default | 82 | 84 | 52 | 32 | `N/A` | N/A | Codex token telemetry present, but selected default model/rate is not sealed. |

## Stage 1C Context Injection Results

Stage 1C reuses the completed Stage 1 Class A/Class B results as the baseline and runs only the
`full-rules-injected` condition. The harness appended the full contents of `.context/rules/*.md` to
worktree `AGENTS.md`, added `@AGENTS.md` to `CLAUDE.md` for Claude Code runs, marked injected
instruction files `skip-worktree`, and restored the instruction files before diff capture.

Injected-context metadata was captured in each run's `context-injection.json`. Because Class A and
Class B use different frozen base SHAs, the injected payload differs by task base:

| Task | Rule files | Injected `AGENTS.md` bytes | Injected `AGENTS.md` SHA-256 |
|---|---:|---:|---|
| Class A injected | 14 | 102,729 | `102a9cc59862e2aa889e620e15f28e6c74745a2bc0f4ba152b4c7791e02aa255` |
| Class B injected | 16 | 143,054 | `c1a5a6c88c820d7944411359cec279c22179c060a7e5fb25cb94854acf442142` |

### Stage 1C Class A: `opfit-281-class-a-premerge-context-injected`

Canonical columns: `score_set_id=stage-1c-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).

*Table sort: Sorted by **Marginal ROI** (desc).*

| Injected alias | Baseline alias | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Score delta | Wall s | Wall delta | Marginal cost USD | Marginal ROI | ROI delta | Summary |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| `cand-06-injected` | `cand-06` | 29 | 22 | 18 | 15 | 8 | 92 | 68 | 38 | 30 | `stage-1c-canonical-v1` | +2.00 | +2 | 213 | `$0.169864` | `400.32` | -40.42 | Composer stayed strong, but injected context increased cache/cost enough to reduce ROI despite a small score gain. |
| `cand-05-injected` | `cand-05` | 29 | 22 | 19 | 15 | 9 | 93 | 66 | 38 | 28 | `stage-1c-canonical-v1` | +1.00 | +3 | 188 | `$0.207365` | `318.28` | +205.59 | Haiku improved sharply: clean focused diff, faster runtime, lower reported Claude cost, and successful negative smoke. |
| `cand-19-injected` | `cand-19` | 29 | 20 | 18 | 15 | 9 | 91 | 64 | 38 | 26 | `stage-1c-canonical-v1` | +3.00 | +1 | 262 | `$0.373056` | `171.56` | +19.88 | Copilot Auto was faster and correct; recovered nano-AIU telemetry shows ROI improved despite only a small score gain. |
| `cand-20-injected` | `cand-20` | 29 | 22 | 18 | 15 | 8 | 92 | 68 | 38 | 30 | `stage-1c-canonical-v1` | +1.00 | -2 | 209 | `$0.426560` | `159.41` | -66.45 | Cursor Auto remained good, but the injected payload erased much of the baseline Auto ROI advantage. |
| `cand-13-injected` | `cand-13` | 28 | 18 | 13 | 12 | 7 | 78 | 58 | 30 | 28 | `stage-1c-canonical-v1` | +3.00 | +1 | 447 | `$0.391716` | `148.07` | -0.23 | Codex mini solved the core task but still carried state-artifact/head-SHA caveats, so cost increased more than score. |
| `cand-12-injected` | `cand-12` | 29 | 23 | 19 | 15 | 7 | 93 | 68 | 38 | 30 | `stage-1c-canonical-v1` | +2.00 | +2 | 322 | `$1.150626` | `59.10` | +8.43 | Opus improved score and ROI slightly, with clean scoped implementation and strong verification. |
| `cand-04-injected` | `cand-04` | 29 | 23 | 19 | 15 | 5 | 91 | 66 | 36 | 30 | `stage-1c-canonical-v1` | +2.00 | -1 | 453 | `$1.230982` | `53.62` | -30.20 | Sonnet produced a clean verified fix, but full-rule injection raised runtime/cost enough to hurt ROI. |
| `cand-21-injected` | `cand-21` | 29 | 20 | 14 | 13 | 8 | 84 | 56 | 32 | 24 | `stage-1c-canonical-v1` | -5 | -5 | 269 | `N/A` | N/A | N/A | Gemini/agy solved the task but added `.context/state` artifacts, making process adherence materially worse than the JSON-stats baseline rerun. |

### Stage 1C Class B: `opfit-326-class-b-premerge-context-injected`

*Table sort: Sorted by **Marginal ROI** (desc).*

| Injected alias | Baseline alias | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Score delta | Wall s | Wall delta | Marginal cost USD | Marginal ROI | ROI delta | Summary |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| `cand-05-agents` | `cand-05` | 20 | 15 | 14 | 5 | 10 | 64 | 67 | 52 | 15 | `stage-1c-canonical-v1` | +67.00 | +64 | 263 | `$0.336678` | `199.00` | +199.00 | Default `AGENTS.md` plus `@AGENTS.md` in `CLAUDE.md` recovered usable Haiku work at lower cost, but missing tests/check wiring and polling-correctness gaps kept quality below the full-rules injected run. |
| `cand-19-injected` | `cand-19` | 23 | 18 | 16 | 9 | 10 | 76 | 67 | 52 | 15 | `stage-1c-canonical-v1` | -11.00 | -8 | 295 | `$0.503979` | `132.94` | +60.05 | Copilot Auto was much faster and cheaper, improving ROI despite a thinner implementation with little/no test wiring compared with baseline. |
| `cand-05-injected` | `cand-05` | 22 | 18 | 15 | 7 | 10 | 72 | 66 | 50 | 16 | `stage-1c-canonical-v1` | +66.00 | +72 | 326 | `$0.508275` | `129.85` | +129.85 | Haiku moved from disqualified/no-work baseline to usable work, but missing focused test/check wiring capped reliability. |
| `cand-06-injected` | `cand-06` | 30 | 23 | 18 | 15 | 10 | 96 | 92 | 58 | 34 | `stage-1c-canonical-v1` | +3.00 | -1 | 296 | `$0.743520` | `123.74` | -93.90 | Composer remained the strongest implementation, but injected context raised cache cost and lowered ROI versus baseline. |
| `cand-20-injected` | `cand-20` | 30 | 22 | 18 | 15 | 10 | 95 | 90 | 58 | 32 | `stage-1c-canonical-v1` | 0 | +2 | 293 | `$0.950754` | `94.66` | -51.36 | Cursor Auto improved score but paid a higher Auto-token cost, reducing ROI despite excellent latency. |
| `cand-13-injected` | `cand-13` | 27 | 20 | 15 | 13 | 3 | 78 | 77 | 48 | 29 | `stage-1c-canonical-v1` | +3.00 | +2 | 1461 | `$1.128873` | `68.21` | +26.06 | Codex mini improved score and cost efficiency versus baseline despite a very long run and some process noise. |
| `cand-04-injected` | `cand-04` | 26 | 21 | 17 | 14 | 4 | 82 | 78 | 48 | 30 | `stage-1c-canonical-v1` | 0 | +16 | 1245 | `$3.312117` | `23.55` | +3.30 | Sonnet benefited substantially from injected context on correctness/process, though runtime remained high. |
| `cand-12-injected` | `cand-12` | 27 | 22 | 18 | 14 | 8 | 89 | 84 | 52 | 32 | `stage-1c-canonical-v1` | +15.00 | 0 | 830 | `$4.242677` | `19.80` | +3.16 | Opus was stable and well-tested, but the injected context did not improve score and slightly reduced ROI. |
| `cand-21-injected` | `cand-21` | 26 | 20 | 16 | 14 | 8 | 84 | N/A | N/A | N/A | N/A | -4 | -4 | 431 | `N/A` | N/A | N/A | Gemini/agy produced useful helper/tests, but score fell from the JSON-stats baseline rerun and telemetry remains unavailable for the injected run. |

Stage 1C notes:

- Full-rule injection appears most helpful for weaker Claude rows: Haiku Class A and Class B improved materially, and Sonnet Class B improved from 66 to 82.
- The `cand-05-agents` isolation run suggests the Claude `@AGENTS.md` import accounts for much of Haiku's Class B rescue versus the no-work baseline, while full-rule injection added some quality/reliability on top.
- Full-rule injection did not improve the already-strong ROI leaders enough to justify its token cost: Composer 2.5 and Cursor Auto remained strong but lost ROI versus baseline.
- Gemini/agy Auto did not benefit in this run; both classes lost score due process/scope issues, and token telemetry remains unavailable.
- The Class B `cand-21-injected/r1` Gemini run was interrupted before terminal capture when the terminal session dropped. It was preserved as partial evidence, and `cand-21-injected/r2` is the scored terminal run.
- These results support using targeted context packs for issue #376 rather than globally injecting every rule into every agent by default.

## Stage 1D Duo Workflow Results

Stage 1D tests a two-phase workflow where a stronger or auto-routed planner produces a sealed plan and a
cheaper or auto-routed implementer executes from the same frozen base. Costs below sum planner plus
implementer telemetry. The scoring rubric remains the Stage 1 100-point rubric:
Correctness/acceptance 30, code and doc quality 25, repo-process adherence 20,
reliability/verification 15, and latency 10.

| Task | Base branch | Base SHA |
|---|---|---|
| Class A duo | `benchmark/model-roi/base-opfit-281-class-a-premerge-YYYYMMDD` | `6946d04b3fd17014e32d9da5ea947acf6df14360` |
| Class B duo | `benchmark/model-roi/base-opfit-326-class-b-premerge-YYYYMMDD` | `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6` |

### Stage 1D Class A: `opfit-281-class-a-premerge`

Canonical columns: `score_set_id=stage-1d-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).

*Table sort: Sorted by **Marginal ROI** (desc).*

| Alias | Platform / planner -> implementer | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Wall s | Marginal cost USD | Marginal ROI | Summary |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| `cand-21-duo` | gemini/agy auto -> gemini/agy auto | 28 | 18 | 14 | 14 | 8 | 82 | 65 | 38 | 27 | `stage-1d-canonical-v1` | 346 | `$0.342674` | `189.68` | Compact working change, but touched `AI_REPO_GUIDE.md` and had planner-marker compliance caveats; cost uses nested Gemini JSON stats. |
| `cand-20-duo` | cursor auto -> cursor auto | 28 | 19 | 15 | 14 | 8 | 84 | 66 | 36 | 30 | `stage-1d-canonical-v1` | 373 | `$0.361981` | `182.33` | Correct implementation with narrow verification, but an extra `scripts/checks/README.md` edit and no local commit capped process score. |
| `cand-12-duo` | claude-code opus -> haiku | 29 | 22 | 18 | 15 | 7 | 91 | 64 | 38 | 26 | `stage-1d-canonical-v1` | 307 | `$0.464986` | `137.64` | Clean one-file fix, successful negative smoke evidence, and local commit; slower/costlier than the best monolithic ROI leaders. |
| `cand-19-duo` | copilot auto -> copilot auto | 28 | 20 | 17 | 15 | 8 | 88 | 64 | 38 | 26 | `stage-1d-canonical-v1` | 359 | `$0.475459` | `134.61` | Correct one-file solution with verification, but the implementation was broader than necessary for the tiny Class A task. |
| `cand-14-duo` | codex GPT-5.4 -> GPT-5.4 mini | 28 | 18 | 12 | 13 | 7 | 78 | 53 | 30 | 23 | `stage-1d-canonical-v1` | 422 | `$0.441885` | `119.94` | Solved the syntax-check task but included `.context/state` process noise and did not produce a local commit. |

### Stage 1D Class B: `opfit-326-class-b-premerge`

Canonical columns: `score_set_id=stage-1d-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).

*Table sort: Sorted by **Marginal ROI** (desc).*

| Alias | Platform / planner -> implementer | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Wall s | Marginal cost USD | Marginal ROI | Summary |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| `cand-21-duo` | gemini/agy auto -> gemini/agy auto | 24 | 18 | 15 | 12 | 6 | 75 | 72 | 50 | 22 | `stage-1d-canonical-v1` | 385 | `$0.517891` | `139.03` | Compact helper/docs/check work, but missing focused tests and planner-marker compliance caveats capped the score; cost uses nested Gemini JSON stats. |
| `cand-20-duo` | cursor auto -> cursor auto | 28 | 22 | 17 | 14 | 7 | 88 | 87 | 58 | 29 | `stage-1d-canonical-v1` | 249 | `$0.714514` | `121.76` | Best duo Class B ROI: fast, broad helper/docs/tests/check coverage, but a large diff and smoke-test-heavy wiring kept it below the strongest monolithic Composer run. |
| `cand-19-duo` | copilot auto -> copilot auto | 26 | 20 | 16 | 14 | 8 | 84 | 71 | 51 | 20 | `stage-1d-canonical-v1` | 536 | `$0.689384` | `102.99` | Good helper/tests/docs surface and strong Copilot credit efficiency; broad prompt/doc edits and adapter rerun caveat limit confidence slightly. |
| `cand-14-duo` | codex GPT-5.4 -> GPT-5.4 mini | 27 | 21 | 16 | 13 | 6 | 83 | 80 | 48 | 32 | `stage-1d-canonical-v1` | 1561 | `$2.227744` | `35.91` | Strong Bats coverage and helper implementation, but extremely slow and had read-only gitdir/no-commit process caveats. |
| `cand-12-duo` | claude-code opus -> haiku | 23 | 19 | 15 | 10 | 5 | 72 | 52 | 40 | 12 | `stage-1d-canonical-v1` | 894 | `$2.008018` | `25.90` | Substantive helper and allow-list work, but no focused tests and limited check/doc wiring reduced reliability. |

Stage 1D notes:

- Duo planning did not beat the best monolithic ROI leaders on either class. Cursor Auto duo was competitive on Class B, but monolithic Composer 2.5 and Gemini Flash still dominated ROI where telemetry was available.
- The duo shape appears most useful when the planner can prevent weak implementers from stalling, but the extra planning turn adds cost/latency that is hard to recover on small tasks.
- Copilot Class B cost excludes the discarded failed pre-patch prompt-delivery attempt and uses only the retained successful planner and implementer sessions: `61c69de9-9249-42da-965e-86b6695749ed` and `9351dd65-b397-47d3-9542-503056d0afe6`.
- Gemini/agy duo rows used the direct `gemini --output-format json` path, not the `agy` fallback. Cost uses nested `stats.models` telemetry from the saved planner and implementer `agent-output.jsonl` files.

## Issue #376 Orchestrated Pipeline Results

Issue #376 tests whether a multi-role orchestration pipeline improves quality or ROI compared with
the monolithic Stage 1 and Stage 1C runs. The valid scored runs below use the historical premerge base
branches created for the same Class A/Class B tasks:

| Task | Base branch | Base SHA |
|---|---|---|
| Class A pipeline | `benchmark/model-roi/base-opfit-281-class-a-premerge-pipeline-ref-20260604` | `6946d04b3fd17014e32d9da5ea947acf6df14360` |
| Class B pipeline | `benchmark/model-roi/base-opfit-326-class-b-premerge-pipeline-ref-20260604` | `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6` |

Issue #376 uses a pipeline-specific 100-point rubric:
Correctness/acceptance 30, code and doc quality 20, repo-process adherence 15,
end-to-end reliability 15, coordination efficiency 10, and latency 10.

Cost/ROI is computed where the scored pipeline run captured usable telemetry. Copilot pipeline rows use
recovered local `session.shutdown.totalNanoAiu` from `events.jsonl`; Gemini/agy rows still need a session
`/stats model` recovery because the agy output did not emit token/model usage into `agent-output.jsonl`.

### Issue #376 Class A: `opfit-281-class-a-premerge-pipeline`

Canonical columns: `score_set_id=stage-1-pipeline-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review; pipeline bundles use `rubric.pipeline.v1` including coordination).
Rows with numeric cost are sorted by marginal ROI; rows requiring external telemetry are left as `N/A`.

*Table sort: Sorted by **ROI** (desc); `N/A` cost rows last.*

| Alias | Platform / model | Run | Gates | Correctness /30 | Quality /20 | Process /15 | Reliability /15 | Coordination /10 | Latency /10 | Legacy /100 | Canonical /100 | Objective /58 | Subjective /42 | score_set_id | Wall s | Diff | Cost USD | ROI | Summary |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---|
| `cand-20-pipe` | cursor / auto | `r3` | pass | 29 | 16 | 12 | 15 | 5 | 10 | 87 | 62 | 33 | 29 | `stage-1-pipeline-canonical-v1` | 279 | `2 files changed, 35 insertions(+), 9 deletions(-)` | `$0.312429` | `198.45` | Fastest useful Class A pipeline; correct fix, but added a small extra README and leaked shell-option state instead of restoring prior `nullglob`. |
| `cand-05-pipe` | claude-code / haiku | `r2` | pass | 28 | 16 | 12 | 14 | 4 | 3 | 77 | 55 | 27 | 28 | `stage-1-pipeline-canonical-v1` | 1128 | `1 file changed, 44 insertions(+), 12 deletions(-)` | `$0.366020` | `150.27` | Solved the task, but the helper is more brittle around shell-option restoration and word splitting, with limited orchestration evidence and high latency. |
| `cand-03-pipe` | copilot / claude-opus-4.8 | `r2` | pass | 30 | 19 | 14 | 15 | 9 | 7 | 94 | 61 | 31 | 30 | `stage-1-pipeline-canonical-v1` | 518 | `1 file changed, 37 insertions(+), 9 deletions(-)` | `$1.558170` | `39.15` | Strongest Class A pipeline by quality and coordination; recovered Copilot nano-AIU cost shows ROI trails cheaper monolithic/Composer/Auto rows. |
| `cand-12-pipe` | claude-code / opus | `r2` | pass | 30 | 19 | 13 | 15 | 4 | 5 | 86 | 59 | 29 | 30 | `stage-1-pipeline-canonical-v1` | 765 | `1 file changed, 14 insertions(+), 11 deletions(-)` | `$1.761853` | `33.49` | Excellent compact implementation with minimal diff; lower pipeline score is mostly from weak observable orchestration evidence and slower runtime. |
| `cand-21-pipe` | gemini/agy / auto | `r3` | pass with process caveats | 27 | 13 | 7 | 13 | 6 | 7 | 73 | 48 | 23 | 25 | `stage-1-pipeline-canonical-v1` | 544 | `4 files changed, 79 insertions(+), 34 deletions(-)` | N/A | N/A | Core fix is usable, but scope drift into `.context/sessions` and `.context/state` materially hurts process adherence; Gemini routed-model/token stats need session recovery. |

### Issue #376 Class B: `opfit-326-class-b-premerge-pipeline`

Canonical columns: `score_set_id=stage-1-pipeline-canonical-v1`, grader `cursor-llm-blind-v1`
(true LLM blind review; pipeline bundles use `rubric.pipeline.v1` including coordination).
Rows with numeric cost are sorted by marginal ROI; rows requiring external telemetry are left as `N/A`.

*Table sort: Sorted by **ROI** (desc); `N/A` cost rows last.*

| Alias | Platform / model | Run | Gates | Correctness /30 | Quality /20 | Process /15 | Reliability /15 | Coordination /10 | Latency /10 | Legacy /100 | Canonical /100 | Objective /58 | Subjective /42 | score_set_id | Wall s | Diff | Cost USD | ROI | Summary |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---|
| `cand-20-pipe` | cursor / auto | `r2` | pass | 29 | 18 | 13 | 15 | 5 | 10 | 90 | 82 | 50 | 32 | `stage-1-pipeline-canonical-v1` | 376 | `13 files changed, 1565 insertions(+), 18 deletions(-)` | `$0.632973` | `129.55` | Best practical Class B pipeline: broad helper/test coverage, very fast runtime, and strong acceptance fit; minor process/quality dings for oversized scope and trailing whitespace. |
| `cand-12-pipe` | claude-code / opus | `r2` | pass | 27 | 17 | 13 | 14 | 4 | 6 | 81 | 76 | 44 | 32 | `stage-1-pipeline-canonical-v1` | 1179 | `7 files changed, 851 insertions(+), 1 deletion(-)` | `$8.202184` | `9.27` | Focused and well-tested helper, but less orchestration evidence and some robustness caveats around pagination/env handling cap the score. |
| `cand-03-pipe` | copilot / claude-opus-4.8 | `r2` | pass | 28 | 17 | 14 | 15 | 9 | 1 | 84 | 73 | 42 | 31 | `stage-1-pipeline-canonical-v1` | 2227 | `8 files changed, 1033 insertions(+)` | `$8.172126` | `8.93` | Strongest observable orchestration, but recovered Copilot nano-AIU cost plus very long wall time sharply reduce the pipeline ROI case. |
| `cand-05-pipe` | claude-code / haiku | `r2` | fail: no work | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `stage-1-pipeline-canonical-v1` | 478 | no diff | `$0.470430` | `0.00` | No candidate work was produced, so the run is disqualified for the scored Class B comparison. |
| `cand-21-pipe` | gemini/agy / auto | `r2` | partial pass | 17 | 11 | 6 | 12 | 5 | 7 | 58 | 61 | 37 | 24 | `stage-1-pipeline-canonical-v1` | 970 | `11 files changed, 710 insertions(+), 7 deletions(-)` | N/A | N/A | Produced substantial work, but a vacuous-convergence behavior, missing pagination depth, and out-of-scope edits to `AGENTS.md`/fixtures are major correctness and process issues; Gemini routed-model/token stats need session recovery. |

Issue #376 run notes:

- Invalid or setup-failed pipeline attempts are excluded from the scored tables. The valid corrected runs are Class A `r2` for `cand-03-pipe`, `cand-12-pipe`, `cand-05-pipe`; Class A `r3` for `cand-20-pipe`, `cand-21-pipe`; and Class B `r2` for all five aliases.
- Earlier Class A `r1` attempts used the wrong current-main base SHA and are retained only as invalid setup evidence, not benchmark evidence.
- `cand-20-pipe` and `cand-21-pipe` required overlay seeding for historical bases that did not yet contain `.cursor/agents` or `.agents`.
- H1, tiered orchestration quality: not proven. `cand-03-pipe` had strong coordination evidence, but latency was too high to clearly beat the best monolithic ROI rows.
- H2, orchestration overhead on simple work: supported. Class A pipeline runs were generally slower and did not materially improve quality over the strongest monolithic baselines.
- H3, cheap same-model orchestration: not supported for hard work. Haiku solved Class A slowly but produced no Class B work.
- H4, crossover point: no favorable crossover was observed in these two tasks. Cursor Auto pipeline is the strongest practical pipeline result, but monolithic Cursor/Auto/Composer-style baselines remain the better ROI direction unless coordination quality is explicitly required.

Pipeline session recovery notes:

| Alias/task | Session artifact | How to recover usage |
|---:|---:|---:|
| `cand-03-pipe` Class A | `/home/codespace/.copilot/session-state/8ec09f7c-6d38-4f81-8743-f19c45469a14/events.jsonl` | Recovered `session.shutdown.totalNanoAiu=155816975000`; cost `$1.558170`, ROI `60.33`. |
| `cand-03-pipe` Class B | `/home/codespace/.copilot/session-state/1666dadf-fc10-4e8c-84e3-155c63eb709e/events.jsonl` | Recovered `session.shutdown.totalNanoAiu=817212650000`; cost `$8.172126`, ROI `10.28`. |
| `cand-21-pipe` Class A | `/home/codespace/.gemini/antigravity-cli/brain/37d3147f-39e1-45ce-ab27-78a9f4ee3b50/` and `/home/codespace/.gemini/antigravity-cli/conversations/37d3147f-39e1-45ce-ab27-78a9f4ee3b50.db` | Scored agy run `r3`; reopen/search this Antigravity conversation and run `/stats model` if the CLI supports resuming that brain. |
| `cand-21-pipe` Class B | `/home/codespace/.gemini/antigravity-cli/brain/4f9c02d9-26da-4e0c-8b58-daf9b06f5907/` and `/home/codespace/.gemini/antigravity-cli/conversations/4f9c02d9-26da-4e0c-8b58-daf9b06f5907.db` | Scored agy run `r2`; reopen/search this Antigravity conversation and run `/stats model` if the CLI supports resuming that brain. |

## Stage 1E Targeted Context-Pack Results

Canonical columns: `score_set_id=stage-1e-canonical-v1-*`, grader `cursor-llm-blind-v1`
(true LLM blind review of each CP-1 bundle's `subjective-prompt.md` via `model-roi-grader-v1`).
Stage 1E tests targeted context packs as a middle path between lazy loading and
full `.context/rules/*.md` injection. It reuses the historical Class A and Class B
frozen bases from issues #374/#376 and measures whether smaller named context
bundles improve quality enough to offset added token/cache cost.

Tracking issue: #378. CP-1 screen manifest:
`.context/benchmarks/model-roi/stage-1e-pack-screen-candidates.tsv.example`
(`ctx-cur` = cursor / composer-2.5; `ctx-gem` = gemini-cli / gemini-3.5-flash
requested). Scores locked 2026-06-06 from diff-only grading before unseal;
locked rows in `scripts/benchmark/runs/stage-1e-blind-scores-locked.tsv`.
Marginal cost/ROI from per-run `agent-output.jsonl` (JSON stats for Gemini; top-level `.usage` for Cursor) using Stage 1 rate cards. **ROI numerators use canonical /100 scores** (`cursor-llm-blind-v1`).
(JSON stats for Gemini; top-level `.usage` for Cursor) using the same Stage 1
rate cards below.

**Base context note:** candidates ran against frozen-base `AGENTS.md`, not the
current workspace copy. Class A base `6946d04…` carried **AGENTS.md v14**; Class B
base `cff89bf…` carried **AGENTS.md v20**. Pack manifests were resolved from the
harness at run time (issue #378 implementation tree).

### Context variants and packs (CP-1 matrix)

Stage 1E compares five **context conditions** per task class. Each row in the
tables below sets `CONTEXT_VARIANT` on the harness; pack rows inject the listed
files into the worktree's `AGENTS.md` for the run only (skip-worktree restore
before diff capture). Manifests live under
[`.context/benchmarks/model-roi/context-packs/`](../context-packs/).

| Context variant | CP-1 Class A | CP-1 Class B | Pack files | Pack bytes (typ.) | What it adds |
|---|---|---|---|---:|---|
| `baseline` | yes | yes | 0 | 0 | **No injection.** Frozen-base `AGENTS.md` only — lazy-load / pointer-table discipline with no extra pack append. Control arm for token cost and scope. |
| `pack:core-min` | yes | yes | 3 | ~28k | **Smallest targeted floor:** [`.context/00_INDEX.md`](../../../00_INDEX.md) (context map), [`.context/rules/agent_ownership.md`](../../../rules/agent_ownership.md) (path ownership), [`.context/sessions/latest_summary.md`](../../../sessions/latest_summary.md) (recent session lessons). Manifest: [`context-packs/core-min.tsv`](../context-packs/core-min.tsv). |
| `pack:class-a-process` | yes | no | 6 | ~46k | **Class A process/doc arm:** `core-min` plus PR completion, doc-sync triggers, work-style/testing expectations, and opportunity-feedback channel — [process_pr_completion.md](../../../rules/process_pr_completion.md), [process_doc_maintenance.md](../../../rules/process_doc_maintenance.md), [process_work_style.md](../../../rules/process_work_style.md), [process_opportunity_feedback.md](../../../rules/process_opportunity_feedback.md). Manifest: [`context-packs/class-a-process.tsv`](../context-packs/class-a-process.tsv). |
| `pack:class-b-implementation` | no | yes | 6 | ~50k | **Class B code/reasoning arm:** `core-min` plus code-quality floor (SOLID/TDD), work-style/testing, and doc-sync triggers — [domain_code_quality.md](../../../rules/domain_code_quality.md), [process_work_style.md](../../../rules/process_work_style.md), [process_doc_maintenance.md](../../../rules/process_doc_maintenance.md). Manifest: [`context-packs/class-b-implementation.tsv`](../context-packs/class-b-implementation.tsv). |
| `full-rules-injected` | yes | yes | 14 / 16 | ~103k / ~143k | **Stage 1C-style full rule dump:** all `.context/rules/*.md` appended to `AGENTS.md` (14 rule files on Class A base, 16 on Class B base because the frozen bases differ). Upper-bound cost/quality comparison vs targeted packs — not a production default. |

CP-1 did **not** screen `workflow-risk` or `adr-docs` packs (defined in
[`context-packs/README.md`](../context-packs/README.md) for future stages).

Per-row **Pack files** / **Pack bytes** in the score tables are measured at run
time from the resolved manifest + injection metadata, not from this summary.

### Stage 1E Class A: targeted context packs

Task: `opfit-281-class-a-premerge`. Base SHA: `6946d04b3fd17014e32d9da5ea947acf6df14360`.

*Table sort: Sorted by **ROI** (desc).*

| Alias | Platform/model | Observed model | Context variant | Pack files | Pack bytes | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Score delta | Wall s | Cost USD | ROI | ROI delta | Summary |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `full-rules-injected` | 14 | 102729 | 29 | 24 | 17 | 14 | 8 | 92 | 65 | 38 | 27 | `stage-1e-canonical-v1-ctx-a-full-rules` | +1.00 | 220 | `$0.103696` | `626.83` | +47.26 | Best Class A raw score; clean 055 expansion |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `baseline` | 0 | 0 | 29 | 24 | 17 | 14 | 7 | 91 | 64 | 38 | 26 | `stage-1e-canonical-v1-ctx-a-baseline` | 0 | 281 | `$0.110427` | `579.57` | 0 | Near-best without injection; nullglob reference-quality |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `pack:class-a-process` | 6 | 45673 | 28 | 23 | 17 | 14 | 8 | 90 | 63 | 38 | 25 | `stage-1e-canonical-v1-ctx-a-class-a-process` | +1.00 | 200 | `$0.119763` | `526.04` | +197.19 | Only pack within -2 of best for this alias; fast single-file fix; **ROI winner for `ctx-cur`** |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `pack:core-min` | 3 | 27587 | 26 | 20 | 14 | 13 | 7 | 80 | 66 | 38 | 28 | `stage-1e-canonical-v1-ctx-a-core-min` | +4.00 | 271 | `$0.127994` | `515.65` | +186.80 | Extra `AI_REPO_GUIDE` scope noise |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `pack:core-min` | 3 | 27587 | 26 | 19 | 13 | 13 | 8 | 79 | 64 | 38 | 26 | `stage-1e-canonical-v1-ctx-a-core-min` | 0 | 239 | `$0.126870` | `504.45` | -75.12 | `IMPLEMENTATION_PLAN.md` junk in diff |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `baseline` | 0 | 0 | 27 | 22 | 16 | 14 | 5 | 84 | 62 | 38 | 24 | `stage-1e-canonical-v1-ctx-a-baseline` | 0 | 335 | `$0.188539` | `328.84` | 0 | Unquoted glob loop; correct but weaker than reference |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `pack:class-a-process` | 6 | 45673 | 25 | 21 | 14 | 13 | 6 | 79 | 62 | 38 | 24 | `stage-1e-canonical-v1-ctx-a-class-a-process` | -2.00 | 303 | `$0.238923` | `259.50` | -320.07 | Extra `assertions.sh` tweak; >3pt degradation vs baseline |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `full-rules-injected` | 14 | 102729 | 27 | 22 | 16 | 14 | 4 | 83 | 62 | 36 | 26 | `stage-1e-canonical-v1-ctx-a-full-rules` | 0 | 382 | `$0.294135` | `210.79` | -118.06 | Full injection did not help cursor; slowest Class A cursor run |

Score delta is vs the same alias's `baseline` **canonical** score for this task class
(e.g. `ctx-cur` pack rows compare to `ctx-cur` + `baseline`, not to `ctx-gem`).
ROI = `canonical / cost_usd`; ROI delta is vs the same alias's `baseline` marginal ROI.
Baseline rows always show `0` for both deltas. Recompute after canonical regrades:
`python3 scripts/benchmark/update-stage-1e-roi.py`.
Gemini costs use JSON `.stats.models[*].tokens` and Gemini 3 Flash Preview rates; Cursor
costs use top-level `.usage` and Composer 2.5 Standard rates (see Stage 1 rate card).

### Stage 1E Class B: targeted context packs

Task: `opfit-326-class-b-premerge`. Base SHA: `cff89bffe7e15e155bd740b6c7a0f158a6f2bad6`.

*Table sort: Sorted by **ROI** (desc).*

| Alias | Platform/model | Observed model | Context variant | Pack files | Pack bytes | Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id | Score delta | Wall s | Cost USD | ROI | ROI delta | Summary |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `pack:core-min` | 3 | 28105 | 27 | 23 | 17 | 13 | 6 | 86 | 73 | 55 | 18 | `stage-1e-canonical-v1-ctx-b-core-min` | +13.00 | 248 | `$0.182007` | `401.08` | +243.57 | Sweet-spot pack: within -2 of best raw score; **ROI winner for `ctx-gem`** |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `pack:core-min` | 3 | 28105 | 26 | 22 | 16 | 13 | 7 | 84 | 90 | 58 | 32 | `stage-1e-canonical-v1-ctx-b-core-min` | +5.00 | 281 | `$0.384231` | `234.23` | +24.72 | Focused helper; large gain vs weak baseline |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `baseline` | 0 | 0 | 22 | 18 | 10 | 12 | 6 | 68 | 85 | 53 | 32 | `stage-1e-canonical-v1-ctx-b-baseline` | 0 | 320 | `$0.405702` | `209.51` | 0 | 17-file blast radius |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `full-rules-injected` | 14 | 143054 | 27 | 23 | 16 | 14 | 8 | 88 | 80 | 58 | 22 | `stage-1e-canonical-v1-ctx-b-full-rules` | +20.00 | 268 | `$0.411508` | `194.41` | +36.89 | Best Class B raw score; focused 6-file helper delivery |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `pack:class-b-implementation` | 6 | 50230 | 23 | 19 | 11 | 12 | 5 | 70 | 84 | 53 | 31 | `stage-1e-canonical-v1-ctx-b-class-b-implementation` | -1.00 | 371 | `$0.456512` | `184.00` | -25.51 | 15-file blast radius |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `pack:class-b-implementation` | 6 | 50230 | 24 | 20 | 15 | 12 | 7 | 78 | 68 | 55 | 13 | `stage-1e-canonical-v1-ctx-b-class-b-implementation` | +8.00 | 280 | `$0.417283` | `162.96` | +5.45 | Root junk files (`called_once`, `counter`) |
| `ctx-gem` | gemini-cli / gemini-3.5-flash requested | `gemini-3-flash-preview` (JSON `.stats.models`) | `baseline` | 0 | 0 | 24 | 20 | 12 | 13 | 5 | 74 | 60 | 40 | 20 | `stage-1e-canonical-v1-ctx-b-baseline` | 0 | 373 | `$0.380922` | `157.51` | 0 | Under-delivered; AGENTS/compliance fixture churn |
| `ctx-cur` | cursor / composer-2.5 | `composer-2.5` (manifest-pinned; agent self-report) | `full-rules-injected` | 14 | 143054 | 25 | 21 | 13 | 13 | 2 | 74 | 84 | 52 | 32 | `stage-1e-canonical-v1-ctx-b-full-rules` | -1.00 | 719 | `$0.687274` | `122.22` | -87.29 | Broad but very slow |

Category scores in the legacy columns are from blind diff grading
(`scripts/benchmark/runs/stage-1e-blind-scores-locked.tsv` for the exploratory
pass). Canonical columns use `stage-1e-canonical-v1-*` score sets compiled from
`scripts/benchmark/grade-bundles/` (grader `cursor-llm-blind-v1`, blind review of each bundle's `subjective-prompt.md` + diff). Legacy and canonical
totals differ because `rubric.v1` splits objective automation from subjective
review.

### Context-pack comparison

*Table sort: Sorted by **mean ROI** (desc).*

| Task class | Pack / variant | Mean canonical /100 | Mean cost | Mean ROI | Scope-noise count | Process-miss count | Recommendation |
|---|---|---:|---:|---:|---:|---:|---|
| A | `pack:core-min` | 65.0 | `$0.127432` | `510.05` | 2 | 2 | Not recommended — weaker mean canonical score on both aliases |
| A | `baseline` | 63.0 | `$0.149483` | `454.21` | 0 | 1 | **Default for Class A** — best mean ROI; `ctx-gem` canonical leader |
| A | `full-rules-injected` | 63.5 | `$0.198915` | `418.81` | 0 | 1 | High `ctx-gem` ROI but tied mean score; avoid default injection |
| A | `pack:class-a-process` | 62.5 | `$0.179343` | `392.77` | 1 | 1 | Optional **cursor-only** pack — strong cursor ROI vs baseline |
| B | `pack:core-min` | 81.5 | `$0.283119` | `317.66` | 1 | 0 | **Default targeted pack for Class B** — best mean ROI; near top canonical scores |
| B | `baseline` | 72.5 | `$0.393312` | `183.51` | 5 | 4 | Under-delivered on this task without targeted context |
| B | `pack:class-b-implementation` | 76.0 | `$0.436897` | `173.48` | 4 | 3 | Not recommended |
| B | `full-rules-injected` | 82.0 | `$0.549391` | `158.31` | 2 | 1 | Highest `ctx-gem` canonical score but ~2× mean cost vs `core-min` |

Mean score, mean cost, and mean ROI average the two CP-1 aliases (`ctx-cur`, `ctx-gem`) per pack/variant.

### Stage 1E model verification

| Alias | Requested | Observed (all 8 runs) | Verification source | agy fallback |
|---|---|---|---|---|
| `ctx-cur` | `composer-2.5` | `composer-2.5` (unverified by JSON) | `--model` pin + agent self-report in `result` text; JSON has `.usage` only | n/a |
| `ctx-gem` | `gemini-3.5-flash` | `gemini-3-flash-preview` | `agent-output.jsonl` → `.stats.models` keys; adapter remap in `effort-applied.txt` | none |

Gemini did **not** run a literal `gemini-3.5-flash` API model — same adapter behavior as Stage 1 `cand-24`
(`gemini-3.5-flash` picker alias → `gemini-3-flash-preview` backend). No `agy` fallback occurred.

**Why Cursor “model” was not in the first CP-1 results pass:** Stage 1 never recorded Cursor's
chosen model from JSON either — `cursor-agent --output-format json` returns token usage but
**no model field** (verified on Stage 1 `cand-06` and Stage 1E `ctx-cur` artifacts). Stage 1
listed `cursor / composer-2.5` from the sealed manifest and `effort-applied.txt`, not from
runtime telemetry. The benchmark prompt also injects `candidate_model:` into the rendered prompt,
and agents echo it in the final text summary (`Alias / Platform / Model` block) — that
self-report was present in Stage 1E `agent-output.jsonl` `result` text but was not extracted into
the first results tables. Copilot **auto** rows are different: those can show a routed model from
session shutdown events (`cand-19`), which is why the original suite may feel more explicit for
some platforms than for pinned Cursor runs.

### Stage 1E notes

- **Canonical-score leader (Class A):** `full-rules-injected` / `ctx-gem` (65); legacy holistic was 92.
- **Canonical-score leader (Class B):** `full-rules-injected` / `ctx-gem` (80); legacy holistic was 88.
- **ROI winner (Class A):** `baseline` on mean ROI (`454.21`); per-alias peaks: `pack:class-a-process` / `ctx-cur` (`526.04`, +197.19 vs baseline) and `full-rules-injected` / `ctx-gem` (`626.83`, +47.26 vs baseline).
- **ROI winner (Class B):** `pack:core-min` / `ctx-gem` (`401.08`, +243.57 vs baseline) — `full-rules` still leads canonical score on `ctx-gem` but trails on ROI at higher cost.
- **Canonical vs ROI winner differ:** yes for Class B (`full-rules` canonical leader on `ctx-gem`, `core-min` ROI leader).
- **>3pt canonical degradation under a pack:** Class A `pack:core-min` and `pack:class-a-process` on `ctx-gem` (-10 and -7 vs baseline canonical 72); Class B packs improved `ctx-gem` vs baseline canonical 59.
- **Full-rule injection dominated?** Class A: yes for cursor (worse canonical, more bytes, lower ROI). Class B: full-rules leads canonical on `ctx-gem` but `core-min` wins ROI at ~48% lower mean cost.
- **Baseline lazy best?** Class A: competitive mean ROI (`501.04`) with lowest mean cost; Class B no — baseline under-delivered; `pack:core-min` helps both aliases.
- **Telemetry:** token counts captured in `agent-output.jsonl` for all 16 runs (`--output-format json`); `session-summary` sidecar not available in this `gemini` CLI build and was not required for cost. CP-2 robustness not yet run.

### Proposed follow-up: context loading policy

- **Default:** baseline lazy loading.
- **Class A:** no automatic injection by default; optional `pack:class-a-process` when cursor/composer runs need stronger process/doc-sync reminders (accept ~1–2pt tradeoffs on some models).
- **Class B:** `pack:core-min` when code/test reasoning risk is high and baseline lazy under-delivers.
- **Avoid:** `full-rules-injected` by default — use only for measured rescue cases or explicit human opt-in.
- **Exception:** re-benchmark on current `AGENTS.md` (v22 decomposition) before changing production routing; CP-1 bases used v14/v20.

These results support `pack:core-min` as the default targeted pack for Class B benchmark-like work and **baseline lazy loading** (not automatic pack injection) for Class A, subject to future reruns when model pricing, `AGENTS.md` version, or context-loading behavior changes.

## Amortized / Subscription ROI

Not used as the primary Stage 1 ranking view.

For this benchmark, the primary ROI question is model/agent performance per credit/token cost. Every
candidate platform requires some subscription or account access, so choosing an arbitrary monthly task
volume `V` before seeing benchmark results would make the subscription allocation dominate the ranking
and could obscure the actual model/runtime cost-performance signal.

Use amortized/subscription math only as a secondary adoption or break-even view:

```text
amortized_cost_per_task = monthly_plan_cost_usd / V
amortized_roi           = weighted_score / amortized_cost_per_task
```

For Copilot, the known access cost is `$39/month`, but `V` should be derived from the eventual routing
decision or measured real usage, not guessed up front. In other words, after the benchmark identifies
which candidates are worth using, compute how many qualifying tasks per month are needed for the fixed
subscription to make sense.

Do not double-count hybrid plans: for Copilot, use token/credit marginal cost for the primary ROI view,
and use the `$39/month` subscription only in a separate break-even/adoption view.

## Session Handshake Capture

The current harness asked candidates to emit the AGENTS.md handshake and final compliance summary. Raw
`agent-output.jsonl` logs can be scanned for this evidence, but the signal is not normalized into
`result.json` yet.

| Task | Alias/run | Handshake evidence found in `agent-output.jsonl` |
|---|---|---|
| Class A core | all 8 locked-score runs | yes |
| Class A extended | `cand-07/r1` through `cand-10/r1`, `cand-11/r2`, `cand-12/r1`, `cand-13/r1`, `cand-14/r1`, `cand-15/r4`, `cand-16/r4` | yes |
| Class A extended | `cand-19/r1`, `cand-20/r2`, `cand-21/r5`, `cand-23/r1`, `cand-24/r2` | yes |
| Class A extended | `cand-22/r1`, `cand-22/r2` | not applicable; prompt parsing failed before a valid run |
| Class B | all completed scored runs except `cand-04/r1` | yes; includes telemetry reruns `cand-21/r2` and `cand-24/r1` |
| Class B | `cand-04/r1` | not found by simple handshake-string scan |

Recommended next benchmark revision: add `handshake_emitted`, `session_context_receipt_emitted`, and
`reported_read_profile` fields to `result.json` so compliance scoring does not depend on brittle raw-log
searches.
