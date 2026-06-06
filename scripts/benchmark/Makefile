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

.PHONY: help base doctor worktrees worktree run suite suite-resume duo-run duo-suite duo-suite-resume record collect push unseal clean-worktrees

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
