SHELL := /usr/bin/env bash
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help assets assets-check preflight phase-0b-validate phase-0b-plan phase-0b-execution-validate phase-0b-summary

help:
	@printf '%s\n' 'assets       regenerate tracked Phase 0A placeholder assets' \
	  'assets-check verify placeholder assets reproduce byte-for-byte' \
	  'preflight    validate tracked Phase 0A state without external operations' \
	  'phase-0b-validate validate the blocked Phase 0B preparation contract' \
	  'phase-0b-plan render the blocked ten-run plan without executing candidates' \
	  'phase-0b-execution-validate validate approval, base, and progress state' \
	  'phase-0b-summary derive Gate 0 inputs from tracked terminal results'

assets:
	@python3 "$(HERE)generate-placeholder-assets.py"

assets-check:
	@python3 "$(HERE)generate-placeholder-assets.py" --check

preflight:
	@"$(HERE)run-preflight.sh"

phase-0b-validate:
	@python3 "$(HERE)prepare-phase-0b.py" --validate

phase-0b-plan:
	@python3 "$(HERE)prepare-phase-0b.py" --plan \
	  "$(HERE)../../../.artifacts/task-parallelism/phase-0b-run-plan.json"

phase-0b-execution-validate:
	@python3 "$(HERE)run-phase-0b.py" --validate-state

phase-0b-summary:
	@python3 "$(HERE)run-phase-0b.py" \
	  --summarize "$(HERE)../../../.context/benchmarks/model-roi/task-parallelism/results/phase-0b" \
	  --output "$(HERE)../../../.context/benchmarks/model-roi/task-parallelism/results/phase-0b-summary.json"
