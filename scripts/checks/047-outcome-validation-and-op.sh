#!/usr/bin/env bash
# scripts/checks/047-outcome-validation-and-op.sh — static checks that the
# outcome-first validation and Parent Orchestrator (OP) guardrails added by
# issue #311 cannot be silently removed.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Outcome-first validation and Parent Orchestrator (OP) guardrails ---
echo "Checking outcome-first validation and OP guardrails (issue #311)..."

# 1. process_work_style.md must carry "Primary validation" and "User outcome"
#    so user-outcome validation is the primary completion gate, not just CI.
if grep -q "Primary validation" .context/rules/process_work_style.md; then
  pass ".context/rules/process_work_style.md contains 'Primary validation' (issue #311)"
else
  fail ".context/rules/process_work_style.md missing 'Primary validation' (issue #311)"
fi

if grep -q "User outcome" .context/rules/process_work_style.md; then
  pass ".context/rules/process_work_style.md contains 'User outcome' (issue #311)"
else
  fail ".context/rules/process_work_style.md missing 'User outcome' (issue #311)"
fi

# 2. process_pr_completion.md must contain "User outcome validation" so the
#    PR gate explicitly requires outcome validation, not just generic checks.
if grep -q "User outcome validation" .context/rules/process_pr_completion.md; then
  pass ".context/rules/process_pr_completion.md contains 'User outcome validation' (issue #311)"
else
  fail ".context/rules/process_pr_completion.md missing 'User outcome validation' (issue #311)"
fi

# 3. PLAN_TEMPLATE.md must carry the outcome validation section heading.
#    The em-dash (U+2014 — ) is part of the required literal.
if grep -qF "User outcome validation plan — PRIMARY" .github/PLAN_TEMPLATE.md; then
  pass ".github/PLAN_TEMPLATE.md contains 'User outcome validation plan — PRIMARY' (issue #311)"
else
  fail ".github/PLAN_TEMPLATE.md missing 'User outcome validation plan — PRIMARY' (issue #311)"
fi

# 4. pull_request_template.md must carry the outcome validation section heading.
#    The em-dash (U+2014 — ) is part of the required literal.
if grep -qF "User outcome validation — PRIMARY" .github/pull_request_template.md; then
  pass ".github/pull_request_template.md contains 'User outcome validation — PRIMARY' (issue #311)"
else
  fail ".github/pull_request_template.md missing 'User outcome validation — PRIMARY' (issue #311)"
fi

# 5. .agents/judge.md must mention user-outcome validation in >= 2 distinct
#    contexts (the plan-gate and the diff-gate). Count >= 2 "User outcome"
#    matches is the pragmatic approximation per issue #311 plan Step 9.
#    We also verify at least one "diff" context exists in the file so the
#    diff-gate check is not solely inferred from the count.
_judge=".agents/judge.md"
# Use grep -c | || true so the pipeline exits 0 on zero matches and does
# not trigger set -e when the pattern is absent (RULE-01).
_judge_uo_count=$(grep -ic "User outcome" "$_judge" || true)
if [[ "${_judge_uo_count:-0}" -ge 2 ]]; then
  pass "$_judge mentions 'User outcome' >= 2 times (plan-gate + diff-gate contexts, issue #311)"
else
  fail "$_judge must mention 'User outcome' at least twice (plan+diff-gate); found ${_judge_uo_count:-0} (issue #311)"
fi

if grep -qF "diff-gate" "$_judge"; then
  pass "$_judge has diff-gate section (issue #311)"
else
  fail "$_judge missing diff-gate section with user-outcome mention (issue #311)"
fi

# 5b. Section-aware diff-gate check (PR #312 codex P2 review): the global
#     count above can pass even if both "User outcome" mentions sit in
#     plan-gate context, leaving the diff-gate without User-outcome
#     evidence. Require at least one "User outcome" mention to appear at
#     or after the first "diff-gate" line in judge.md.
_judge_diff_uo=$(awk '
  /diff-gate/ { seen = 1 }
  seen && tolower($0) ~ /user outcome/ { count++ }
  END { print count + 0 }
' "$_judge")
if [[ "${_judge_diff_uo:-0}" -ge 1 ]]; then
  pass "$_judge has 'User outcome' mention in diff-gate section (issue #311, PR #312)"
else
  fail "$_judge: 'User outcome' must appear at or after the first 'diff-gate' line; found 0 (issue #311, PR #312)"
fi
unset _judge_diff_uo
unset _judge _judge_uo_count

# 6. .agents/critic.md must call out outcome theater or equivalent so Critic
#    challenges superficial validation evidence.
#    Accepted equivalents (checked case-insensitively):
#      "outcome theater"     — canonical term (issue #311)
#      "validation theater"  — synonym for same anti-pattern
#      "outcome washing"     — alternate phrasing for same anti-pattern
_critic=".agents/critic.md"
if grep -qi "outcome theater" "$_critic" \
  || grep -qi "validation theater" "$_critic" \
  || grep -qi "outcome washing" "$_critic"; then
  pass "$_critic mentions outcome theater / validation theater / outcome washing (issue #311)"
else
  fail "$_critic must mention 'outcome theater' (or 'validation theater' / 'outcome washing') (issue #311)"
fi
unset _critic

# 7. process_role_selection.md must define "Parent Orchestrator" so the
#    default agent's OP role is explicit and unambiguous.
if grep -q "Parent Orchestrator" .context/rules/process_role_selection.md; then
  pass ".context/rules/process_role_selection.md defines 'Parent Orchestrator' (issue #311)"
else
  fail ".context/rules/process_role_selection.md missing 'Parent Orchestrator' definition (issue #311)"
fi

# 8. process_role_selection.md must include guidance that skipping subagents
#    requires explicit user wording or a documented exception. Any of the
#    following literals satisfies the check:
#      "do not use subagents"   — canonical user instruction form
#      "explicit special case"  — documented exception hook
_rsel=".context/rules/process_role_selection.md"
if grep -qi "do not use subagents" "$_rsel" \
  || grep -qi "explicit special case" "$_rsel"; then
  pass "$_rsel requires explicit wording to skip subagents (issue #311)"
else
  fail "$_rsel missing guidance on explicit subagent-skip wording (issue #311)"
fi
unset _rsel
