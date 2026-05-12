# Makefile — opt-in workflow targets.
#
# This Makefile intentionally exposes only workflow targets that benefit
# from deterministic enforcement. Build/test/lint commands continue to
# live in `test.sh` and the per-script entry points under `scripts/`.

.PHONY: closeout

# closeout — legacy fallback for old repo-local state close-out artifacts.
# Implements issue #262 (the cadence-trigger discipline enforcement).
# See `scripts/closeout.sh` for the six checks performed.
closeout:
	@./scripts/closeout.sh
