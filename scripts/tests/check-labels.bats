#!/usr/bin/env bats
# check-labels.bats — verify that all expected pipeline labels are declared
# in scripts/setup/40-ensure-labels.sh.
#
# Tests are static (parse the LABEL_SPECS heredoc) so they pass in CI without
# a live GitHub token.  The seed script must be re-run with a PAT to create
# the labels in the repo itself.

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-30}"

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export REPO_ROOT
  LABEL_SCRIPT="$REPO_ROOT/scripts/setup/40-ensure-labels.sh"
  export LABEL_SCRIPT
}

# Helper: assert that a label name appears in the LABEL_SPECS block.
_label_declared() {
  local name="$1"
  grep -qE "^${name}\\|" "$LABEL_SCRIPT"
}

@test "agent-suggested label is declared in 40-ensure-labels.sh" {
  _label_declared "agent-suggested"
}

@test "agent-suggested label has correct color BFD4F2" {
  grep -qE "^agent-suggested\\|BFD4F2\\|" "$LABEL_SCRIPT"
}

@test "agent-suggested label description references process_opportunity_feedback" {
  grep -qE "^agent-suggested\\|.*process_opportunity_feedback" "$LABEL_SCRIPT"
}

@test "core pipeline labels are still declared" {
  for label in auto-merge claude-fix copilot-relay agent:claimed agent:blocked agent:awaiting-review cap-override; do
    _label_declared "$label" || { echo "missing label: $label"; return 1; }
  done
}
