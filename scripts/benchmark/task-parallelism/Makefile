SHELL := /usr/bin/env bash
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help assets assets-check preflight

help:
	@printf '%s\n' 'assets       regenerate tracked Phase 0A placeholder assets' \
	  'assets-check verify placeholder assets reproduce byte-for-byte' \
	  'preflight    validate tracked Phase 0A state without external operations'

assets:
	@python3 "$(HERE)generate-placeholder-assets.py"

assets-check:
	@python3 "$(HERE)generate-placeholder-assets.py" --check

preflight:
	@"$(HERE)run-preflight.sh"
