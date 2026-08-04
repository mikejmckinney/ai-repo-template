# Makefile — front-end for the model-ROI benchmark runner.
#
# Typical flow:
#   make base TASK=opfit-281-class-a              # freeze a base branch, prints BASE_SHA
#   make doctor STAGE=1 BASE=<sha>                 # readiness gate before any spend
#   make worktrees TASK=opfit-281-class-a BASE=<sha> STAGE=1  # (optional) pre-make all Stage-1 worktrees
#   make suite TASK=opfit-281-class-a BASE=<sha> STAGE=1   # run all Stage-1 automated candidates
#   make suite TASK=opfit-281-class-a BASE=<sha> STAGE=1 CONTEXT_VARIANT=full-rules-injected
#   make suite TASK=opfit-281-class-a-premerge-pipeline BASE=<sha> STAGE=1 PROMPT_FILE=../../.github/prompts/model-roi-orchestration-pipeline-candidate.md MANIFEST=orchestration-candidates.tsv BENCHMARK_SUBISSUE=#376 ORCHESTRATION_VARIANT=pipeline-same-model
#   make duo-suite TASK=opfit-281-class-a-premerge BASE=<sha> STAGE=1d # run Stage-1D planner/implementer candidates
#   make suite-resume TASK=opfit-281-class-a BASE=<sha> STAGE=1 RUN_INDEX=2 # resume missing candidates
#   make run TASK=opfit-281-class-a BASE=<sha> ALIAS=cand-01   # one candidate
#   make duo-run TASK=opfit-281-class-a-premerge BASE=<sha> ALIAS=cand-12-duo # one duo candidate
#   make worktree TASK=opfit-281-class-a BASE=<sha> ALIAS=cand-06   # isolate for a MANUAL candidate
#   make record TASK=opfit-281-class-a BASE=<sha> ALIAS=cand-06 RC=0 TOKENS_IN=... TOKENS_OUT=...
#   make collect TASK=opfit-281-class-a           # blind grading sheet
#   RUN_GROUP=ctx-a-core-min make collect TASK=opfit-281-class-a-premerge STAGE=1
#   make push TASK=opfit-281-class-a ALIAS=cand-01 # runner-owned push (optional)
#   make unseal TASK=opfit-281-class-a            # AFTER grading: reveal alias->model
#   RUN_GROUP=ctx-a-core-min MANIFEST=.../stage-1e-pack-screen-candidates.tsv.example \
#     make suite TASK=opfit-281-class-a-premerge BASE=<sha> STAGE=1 CONTEXT_VARIANT=pack:core-min
#
# REPO_DIR defaults to the repo root inferred by lib.sh; override on the CLI if needed.
# TASK must match .context/benchmarks/model-roi/tasks/<TASK>.md.

SHELL := /usr/bin/env bash
HERE  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TASK ?=
BASE ?=
ALIAS ?=
STAGE ?=
RUN_INDEX ?= 1
RUN_GROUP ?=
CONTEXT_VARIANT ?= baseline
ORCHESTRATION_VARIANT ?= none
MANIFEST ?=

SCORE_SET ?=
EVAL_ID ?=
GRADER_ID ?=
RESPONSE ?=
RUBRIC ?=

.PHONY: help base doctor worktrees worktree run suite suite-resume duo-run duo-suite duo-suite-resume record collect push unseal clean-worktrees grade-bundles grade-objective grade-subjective-prompts grade-subjective-record grade-compile grade-compare grade-adjudicate regrade-stage-1e

help:
	@sed -n '1,32p' "$(HERE)Makefile"

# Freeze a base branch from origin/main without changing the operator's working branch.
base:
	@test -n "$(TASK)" || { echo "set TASK=<id>"; exit 2; }
	@cd "$$(bash -c 'source "$(HERE)lib.sh"; echo $$REPO_DIR')" && \
	  git fetch origin main && \
	  BASE_SHA="$$(git rev-parse origin/main)" && \
	  BR="benchmark/model-roi/base-$(TASK)-$$(date -u +%Y%m%d)" && \
	  git branch -f "$$BR" "$$BASE_SHA" && \
	  git push -u origin "$$BR" && \
	  echo "" && echo "FROZEN BASE for $(TASK):" && \
	  echo "  branch : $$BR" && \
	  echo "  BASE   : $$BASE_SHA" && \
	  echo "Record BASE in the sub-issue, then: make suite TASK=$(TASK) BASE=$$BASE_SHA STAGE=1"

doctor:
	@test -n "$(STAGE)" && test "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@"$(HERE)doctor.sh" --stage "$(STAGE)" $(if $(BASE),--base "$(BASE)",)

worktrees:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(STAGE)" || { echo "set TASK BASE STAGE=1"; exit 2; }
	@test "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@bash -c 'source "$(HERE)lib.sh"; for a in $$(manifest_aliases "$(STAGE)"); do \
	   make_worktree "$(TASK)" "$$a" "$(RUN_INDEX)" "$(BASE)" >/dev/null && echo "worktree: $$a"; done'

worktree:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(ALIAS)" || { echo "set TASK BASE ALIAS"; exit 2; }
	@bash -c 'source "$(HERE)lib.sh"; row=$$(manifest_lookup "$(ALIAS)") || exit $$?; \
	  require_alias_stage_one "$(ALIAS)" "$$row" || exit $$?; \
	  make_worktree "$(TASK)" "$(ALIAS)" "$(RUN_INDEX)" "$(BASE)"'

run:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(ALIAS)" || { echo "set TASK BASE ALIAS"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-candidate.sh" --task "$(TASK)" --base "$(BASE)" --alias "$(ALIAS)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)" \
	  --orchestration-variant "$(ORCHESTRATION_VARIANT)"

suite:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(STAGE)" || { echo "set TASK BASE STAGE=1"; exit 2; }
	@test "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-suite.sh" --task "$(TASK)" --base "$(BASE)" --stage "$(STAGE)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)" --continue-on-error \
	  --orchestration-variant "$(ORCHESTRATION_VARIANT)"

suite-resume:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(STAGE)" || { echo "set TASK BASE STAGE=1"; exit 2; }
	@test "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-suite.sh" --task "$(TASK)" --base "$(BASE)" --stage "$(STAGE)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)" --continue-on-error --resume \
	  --orchestration-variant "$(ORCHESTRATION_VARIANT)"

duo-run:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(ALIAS)" || { echo "set TASK BASE ALIAS"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-duo-candidate.sh" --task "$(TASK)" --base "$(BASE)" --alias "$(ALIAS)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)"

duo-suite:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(STAGE)" || { echo "set TASK BASE STAGE=1d"; exit 2; }
	@test "$(STAGE)" = "1d" || { echo "Stage 1D duo benchmark requires STAGE=1d"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-duo-suite.sh" --task "$(TASK)" --base "$(BASE)" --stage "$(STAGE)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)" --continue-on-error

duo-suite-resume:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(STAGE)" || { echo "set TASK BASE STAGE=1d"; exit 2; }
	@test "$(STAGE)" = "1d" || { echo "Stage 1D duo benchmark requires STAGE=1d"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" CONTEXT_VARIANT="$(CONTEXT_VARIANT)" \
	  $(if $(MANIFEST),MANIFEST="$(MANIFEST)",) \
	  "$(HERE)run-duo-suite.sh" --task "$(TASK)" --base "$(BASE)" --stage "$(STAGE)" --run-index "$(RUN_INDEX)" --context-variant "$(CONTEXT_VARIANT)" --continue-on-error --resume

# Manual-candidate capture. Pass timing/telemetry you read off the platform dashboard.
record:
	@test -n "$(TASK)" -a -n "$(BASE)" -a -n "$(ALIAS)" || { echo "set TASK BASE ALIAS"; exit 2; }
	@"$(HERE)record-manual.sh" --task "$(TASK)" --base "$(BASE)" --alias "$(ALIAS)" --run-index "$(RUN_INDEX)" \
	  $(if $(RC),--rc $(RC),) $(if $(START),--start $(START),) $(if $(END),--end $(END),) \
	  $(if $(TOKENS_IN),--tokens-in $(TOKENS_IN),) $(if $(TOKENS_OUT),--tokens-out $(TOKENS_OUT),) \
	  $(if $(COST_SRC),--cost-src "$(COST_SRC)",)

collect:
	@test -n "$(TASK)" || { echo "set TASK"; exit 2; }
	@test -z "$(STAGE)" -o "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" "$(HERE)collect.sh" --task "$(TASK)" $(if $(STAGE),--stage "$(STAGE)",)

# Runner-owned push of an aliased candidate branch (keeps push out of the agent's hands).
push:
	@test -n "$(TASK)" -a -n "$(ALIAS)" || { echo "set TASK ALIAS"; exit 2; }
	@bash -c 'source "$(HERE)lib.sh"; \
	  br="$$(branch_name "$(TASK)" "$(ALIAS)")-r$(RUN_INDEX)"; \
	  git -C "$$REPO_DIR" push -u origin "$$br" && echo "pushed $$br"'

unseal:
	@test -n "$(TASK)" || { echo "set TASK"; exit 2; }
	@test -z "$(STAGE)" -o "$(STAGE)" = "1" || { echo "Phase A requires STAGE=1"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" "$(HERE)collect.sh" --task "$(TASK)" $(if $(STAGE),--stage "$(STAGE)",) --unseal

clean-worktrees:
	@bash -c 'source "$(HERE)lib.sh"; git -C "$$REPO_DIR" worktree prune; \
	  rm -rf "$$WORKTREES_DIR"/*; echo "pruned worktrees"'

grade-bundles:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" || { echo "set TASK SCORE_SET"; exit 2; }
	@RUN_GROUP="$(RUN_GROUP)" "$(HERE)prepare-grade-bundle.sh" \
	  --task "$(TASK)" --stage "$(if $(STAGE),$(STAGE),1)" --score-set "$(SCORE_SET)" \
	  $(if $(filter command line,$(origin RUN_INDEX)),--run-index "$(RUN_INDEX)",) \
	  $(if $(MANIFEST),--manifest "$(MANIFEST)",)

grade-objective:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" || { echo "set TASK SCORE_SET"; exit 2; }
	@python3 "$(HERE)grade-objective.py" \
	  --bundle-root "$(HERE)grade-bundles/$(TASK)/$(SCORE_SET)" \
	  --rubric "$(if $(RUBRIC),$(RUBRIC),$(if $(filter %-pipeline,$(TASK)),$(HERE)../../.context/benchmarks/model-roi/grading/rubric.pipeline.v1.json,$(HERE)../../.context/benchmarks/model-roi/grading/rubric.v1.json))" \
	  --task-spec "$(HERE)../../.context/benchmarks/model-roi/grading/tasks/$(TASK).json"

grade-subjective-prompts:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" || { echo "set TASK SCORE_SET"; exit 2; }
	@for d in "$(HERE)grade-bundles/$(TASK)/$(SCORE_SET)"/eval-*; do \
	  [ -d "$$d" ] || continue; \
	  python3 "$(HERE)render-subjective-grade-prompt.py" \
	    --bundle "$$d" \
	    --out "$$d/subjective-prompt.md"; \
	done

grade-subjective-record:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" -a -n "$(EVAL_ID)" -a -n "$(GRADER_ID)" -a -n "$(RESPONSE)" \
	  || { echo "set TASK SCORE_SET EVAL_ID GRADER_ID RESPONSE"; exit 2; }
	@python3 "$(HERE)record-subjective-grade.py" \
	  --bundle "$(HERE)grade-bundles/$(TASK)/$(SCORE_SET)/$(EVAL_ID)" \
	  --response "$(RESPONSE)" \
	  --grader-id "$(GRADER_ID)"

grade-compile:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" || { echo "set TASK SCORE_SET"; exit 2; }
	@python3 "$(HERE)compile-final-grades.py" \
	  --bundle-root "$(HERE)grade-bundles/$(TASK)/$(SCORE_SET)" \
	  $(if $(GRADER_ID),--grader-id "$(GRADER_ID)",) \
	  $(if $(MEDIAN_SUBJECTIVE),--median-subjective,)

grade-compare:
	@test -n "$(LEFT)" -a -n "$(RIGHT)" -a -n "$(OUT)" || { echo "set LEFT RIGHT OUT"; exit 2; }
	@python3 "$(HERE)compare-grade-sets.py" --left "$(LEFT)" --right "$(RIGHT)" --out "$(OUT)"

grade-adjudicate:
	@test -n "$(TASK)" -a -n "$(SCORE_SET)" || { echo "set TASK SCORE_SET"; exit 2; }
	@python3 "$(HERE)adjudicate-grades.py" \
	  --bundle-root "$(HERE)grade-bundles/$(TASK)/$(SCORE_SET)" \
	  $(if $(COMPARE_REPORT),--compare-report "$(COMPARE_REPORT)",)

# Stage 1E CP-1 canonical regrade (see regrade-stage-1e.sh and docs/guides/model-roi-benchmark-runbook.md)
# Examples:
#   make -C scripts/benchmark regrade-stage-1e ARGS="prepare"
#   make -C scripts/benchmark regrade-stage-1e ARGS="status"
#   make -C scripts/benchmark regrade-stage-1e ARGS="record codex-fixed ./stage-1e-responses"
#   make -C scripts/benchmark regrade-stage-1e ARGS="compile codex-fixed"
regrade-stage-1e:
	@"$(HERE)regrade-stage-1e.sh" $(ARGS)
