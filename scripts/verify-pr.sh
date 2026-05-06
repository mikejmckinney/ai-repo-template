#!/usr/bin/env bash
# scripts/verify-pr.sh — classify a PR's changed paths and compare against
# the declared `Change class` from the issue Implementation Plan comment.
#
# Why this exists (issue #227): workflows triggered by `pull_request_review`,
# `issue_comment`, `push`, `schedule`, and `workflow_run` always run from
# the **default branch**, never the PR branch. PR #225 paid 11 rounds of
# bot review for one such change because the bug class is structurally
# unverifiable on the PR branch. This script is the surgical Plan-template
# guard: if you declare `code-or-docs` but you actually touched a
# default-branch-only workflow, you must either (a) reclassify and run
# the sandbox playbook (`docs/guides/sandbox-verification.md`), or
# (b) explain why the trigger event genuinely runs from the PR branch.
#
# Usage:
#   scripts/verify-pr.sh [--base <ref>] [--declared <class>] [--paths-from <file>]
#
# Resolution order for the changed-path list (first hit wins):
#   1. --paths-from FILE  (one path per line; `-` for stdin)
#   2. PR_FILES env var   (newline-separated; set by CI from the PR API)
#   3. git diff --name-only <base>...HEAD  (base default: origin/main)
#
# Resolution order for the declared class (first hit wins):
#   1. --declared <class>
#   2. PR_DECLARED_CLASS env var
#   3. (none) — script reports the *detected* class only and exits 0;
#      this lets developers run it locally for an at-a-glance check.
#
# Exit codes:
#   0  — no declaration provided, OR declaration matches detection.
#   1  — declaration mismatch (detected class is more restrictive than
#        declared, or pure type mismatch).
#   2  — usage / argument error.
#
# The matrix lives in docs/guides/agent-pipeline.md § "Workflow
# verifiability matrix". Detection rules below mirror that doc — keep
# them in lockstep.

set -euo pipefail

usage() {
  cat <<'USAGE'
verify-pr.sh — Plan-template Change-class classifier (issue #227)

Usage:
  scripts/verify-pr.sh [options]

Options:
  --base <ref>          Base ref for `git diff` (default: origin/main).
  --declared <class>    Declared Change class. One of:
                          code-or-docs
                          pull_request-triggered workflow
                          default-branch-only workflow
                          mixed
  --paths-from <file>   Read changed paths from FILE (one per line).
                        Use `-` for stdin.
  --quiet               Suppress the per-path detection trace.
  -h, --help            Show this help.

Exit codes:
  0  match (or no --declared given)
  1  mismatch
  2  usage error
USAGE
}

base="origin/main"
declared="${PR_DECLARED_CLASS:-}"
paths_from=""
quiet=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base="$2"
      shift 2
      ;;
    --declared)
      declared="$2"
      shift 2
      ;;
    --paths-from)
      paths_from="$2"
      shift 2
      ;;
    --quiet)
      quiet=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'verify-pr.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ── Gather changed paths ────────────────────────────────────────────────────

paths=""
if [[ -n "$paths_from" ]]; then
  if [[ "$paths_from" == "-" ]]; then
    paths=$(cat)
  else
    paths=$(cat "$paths_from")
  fi
elif [[ -n "${PR_FILES:-}" ]]; then
  paths="$PR_FILES"
else
  paths=$(git diff --name-only "$base"...HEAD 2>/dev/null || true)
  if [[ -z "$paths" ]]; then
    # Fallback: working-tree diff, useful when running locally pre-push.
    paths=$(git diff --name-only "$base" 2>/dev/null || true)
  fi
fi

if [[ -z "$paths" ]]; then
  printf 'verify-pr.sh: no changed paths found (base=%s).\n' "$base" >&2
  printf '  Pass --paths-from FILE or set PR_FILES if running outside a git checkout.\n' >&2
  exit 2
fi

# ── Classify each path ──────────────────────────────────────────────────────
#
# Detection rules (mirror docs/guides/agent-pipeline.md § "Workflow
# verifiability matrix"):
#
# default-branch-only workflow
#   Any `.github/workflows/<name>.yml` whose triggers include any of:
#   pull_request_review, pull_request_review_comment, issue_comment,
#   push, schedule, workflow_run. These always execute from the
#   default branch, so a PR-branch change to such a file cannot be
#   exercised pre-merge.
#
# pull_request-triggered workflow
#   Any `.github/workflows/<name>.yml` whose triggers are limited to
#   pull_request / pull_request_target / workflow_dispatch. These run
#   the workflow file from the PR branch, so PR-branch testing works.
#
# code-or-docs
#   Anything else: source, docs, scripts, config, ADRs, role files, etc.
#
# A diff that contains paths from more than one bucket above classifies
# as `mixed`; the most-restrictive bucket present sets the verification
# floor (default-branch-only > pull_request-triggered > code-or-docs).

has_default_only=0
has_pr_triggered=0
has_other=0

# Surface-only triggers that pin a workflow to default-branch execution.
# Keep this list in lockstep with docs/guides/agent-pipeline.md.
#
# Note on `pull_request_target`: per GitHub docs, this trigger runs in
# the context of the PR's *base* branch (the target / default branch),
# not the PR head. The workflow file is therefore loaded from the
# default branch ref, exactly like push / schedule / workflow_run.
# Treating it as PR-branch verifiable would be wrong, and it's also
# the trigger most often abused for write-permission escalation, so
# being conservative here is the right default.
DEFAULT_ONLY_TRIGGERS=(
  pull_request_review
  pull_request_review_comment
  pull_request_target
  issue_comment
  push
  schedule
  workflow_run
  repository_dispatch
)

# Build alternation for grep -E, e.g. "(push|schedule|...)".
DEFAULT_ONLY_ALT=$(
  IFS='|'
  printf '(%s)' "${DEFAULT_ONLY_TRIGGERS[*]}"
)

# Detect whether a workflow file's `on:` block carries any default-only
# trigger. Handles four common YAML shapes (and excludes comments and
# jobs/steps):
#
#   1. Block-form key:        `  push:` or `  push:\n    branches: [main]`
#   2. Block-form list item:  `  - push` or `  - push:`
#   3. Inline scalar:         `on: push`
#   4. Inline flow sequence:  `on: [push, schedule]`
#
# Pre-step: strip `#` comments (anywhere on a line) so a commented-out
# `# on: push` cannot trigger a false positive. Multi-line YAML comments
# don't exist, so a one-pass strip is sufficient.
#
# This is regex-based rather than YAML-parsed because the script is
# pure bash with no python/yq dependency. Edge cases (a job literally
# named `push:`, an env var `PUSH:`) are bounded by anchoring patterns
# 1 and 2 to leading whitespace + a real top-level key shape, plus
# pattern 3/4 anchoring to `on:` at the start of a line. Adding more
# shapes is the documented extension point — see
# scripts/test-verify-pr.sh fixtures.
detect_default_only() {
  local file="$1"
  local cleaned
  # Strip line comments. `\b#` would be wrong because YAML allows `#`
  # only as start-of-line or preceded by whitespace; sed handles both.
  cleaned=$(sed -E 's/[[:space:]]+#.*$//; s/^#.*$//' "$file")
  # Pattern 1 (block-form key) AND pattern 2 (block-form list item).
  if printf '%s\n' "$cleaned" \
    | grep -qE "^[[:space:]]*(-[[:space:]]+)?${DEFAULT_ONLY_ALT}([[:space:]]*:|[[:space:]]*$)"; then
    return 0
  fi
  # Pattern 3 (inline scalar): `on: push` on a single line.
  if printf '%s\n' "$cleaned" \
    | grep -qE "^on:[[:space:]]+${DEFAULT_ONLY_ALT}[[:space:]]*$"; then
    return 0
  fi
  # Pattern 4 (inline flow sequence): `on: [push, schedule, ...]`.
  # Match the `[...]` block on the `on:` line. Closing `]` cannot be
  # placed inside a bracket expression in ERE (it would terminate it),
  # so the trailing delimiter is expressed as an alternation
  # `(,|[[:space:]]*])` instead. Token must be preceded by `[`,
  # whitespace, or `,`.
  if printf '%s\n' "$cleaned" \
    | grep -qE "^on:[[:space:]]*\[[^]]*[[:space:],[]${DEFAULT_ONLY_ALT}([[:space:]]*,|[[:space:]]*\])"; then
    return 0
  fi
  # Edge case: leading flow-sequence token `on: [push,` or `on: [push]`.
  if printf '%s\n' "$cleaned" \
    | grep -qE "^on:[[:space:]]*\[${DEFAULT_ONLY_ALT}([[:space:]]*,|[[:space:]]*\])"; then
    return 0
  fi
  return 1
}

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  detected="code-or-docs"
  if [[ "$path" == .github/workflows/*.yml || "$path" == .github/workflows/*.yaml ]]; then
    if [[ -f "$path" ]]; then
      # Look at the `on:` block. We only care about top-level trigger
      # *keys*; values like `branches: [main]` are intentionally not
      # treated as triggers. detect_default_only handles block-form,
      # list-bullet, inline-scalar, and bracket-list YAML shapes.
      if detect_default_only "$path"; then
        detected="default-branch-only workflow"
        has_default_only=1
      else
        detected="pull_request-triggered workflow"
        has_pr_triggered=1
      fi
    else
      # File deleted in this diff — we can't read it. Be conservative:
      # treat as default-branch-only so reviewers catch a removal of a
      # workflow that was previously default-branch-pinned.
      detected="default-branch-only workflow (file removed; conservative)"
      has_default_only=1
    fi
  else
    has_other=1
  fi

  if [[ "$quiet" -eq 0 ]]; then
    printf '  %-46s  %s\n' "$detected" "$path"
  fi
done <<<"$paths"

# Determine the overall (most-restrictive) detected class.
buckets_set=0
[[ "$has_default_only" -eq 1 ]] && buckets_set=$((buckets_set + 1))
[[ "$has_pr_triggered" -eq 1 ]] && buckets_set=$((buckets_set + 1))
[[ "$has_other" -eq 1 ]] && buckets_set=$((buckets_set + 1))

if [[ "$buckets_set" -ge 2 ]]; then
  detected_overall="mixed"
elif [[ "$has_default_only" -eq 1 ]]; then
  detected_overall="default-branch-only workflow"
elif [[ "$has_pr_triggered" -eq 1 ]]; then
  detected_overall="pull_request-triggered workflow"
else
  detected_overall="code-or-docs"
fi

# ── Report / compare ────────────────────────────────────────────────────────

if [[ "$quiet" -eq 0 ]]; then
  printf '\nDetected change class: %s\n' "$detected_overall"
fi

if [[ -z "$declared" ]]; then
  # Detection-only mode (no declaration to compare).
  exit 0
fi

if [[ "$declared" == "$detected_overall" ]]; then
  printf '✓ declared class (%s) matches detection.\n' "$declared"
  exit 0
fi

# Note: we deliberately do NOT short-circuit on `declared == "mixed"`
# alone. detected_overall is "mixed" iff buckets_set >= 2, so the
# equality check above already covers every legitimate multi-bucket
# diff. A `declared mixed` against a single-bucket diff is a real
# mismatch (over-declaration hides which bucket actually applies),
# and falls through to the mismatch branch below.

# Mismatch. Tell the author what to do next.
printf '✗ Change class mismatch.\n' >&2
printf '    declared:  %s\n' "$declared" >&2
printf '    detected:  %s\n' "$detected_overall" >&2
printf '\nNext steps:\n' >&2
case "$detected_overall" in
  "default-branch-only workflow")
    printf '  - Update the issue Plan comment Verification section:\n' >&2
    printf '      Change class: %s\n' "$detected_overall" >&2
    printf '      Verification target: sandbox repo (or both)\n' >&2
    printf '  - Run the sandbox playbook before merging:\n' >&2
    printf '      docs/guides/sandbox-verification.md\n' >&2
    ;;
  "mixed")
    # In a mixed diff the verification floor is set by the
    # most-restrictive bucket present, NOT by the literal label
    # "mixed". If any default-branch-only path is in the diff, the
    # sandbox playbook applies; otherwise the floor is PR-branch
    # verifiable. Mirrors the matrix in
    # docs/guides/agent-pipeline.md § "Workflow verifiability matrix".
    printf '  - Update the issue Plan comment Verification section:\n' >&2
    printf '      Change class: mixed\n' >&2
    if [[ "$has_default_only" -eq 1 ]]; then
      printf '      Verification target: sandbox repo (or both)\n' >&2
      printf '  - Run the sandbox playbook before merging:\n' >&2
      printf '      docs/guides/sandbox-verification.md\n' >&2
    else
      printf '      Verification target: PR branch\n' >&2
    fi
    ;;
  "pull_request-triggered workflow")
    printf '  - Update the issue Plan comment Verification section:\n' >&2
    printf '      Change class: pull_request-triggered workflow\n' >&2
    printf '      Verification target: PR branch\n' >&2
    ;;
  *)
    printf '  - Update the issue Plan comment Verification section to declare:\n' >&2
    printf '      Change class: %s\n' "$detected_overall" >&2
    ;;
esac
exit 1
