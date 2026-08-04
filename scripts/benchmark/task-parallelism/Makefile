SHELL := /usr/bin/env bash
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help assets assets-check preflight phase-0b-validate phase-0b-plan

help:
	@printf '%s\n' 'assets       regenerate tracked Phase 0A placeholder assets' \
	  'assets-check verify placeholder assets reproduce byte-for-byte' \
	  'preflight    validate tracked Phase 0A state without external operations' \
	  'phase-0b-validate validate the blocked Phase 0B preparation contract' \
	  'phase-0b-plan render the blocked ten-run plan without executing candidates'

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
