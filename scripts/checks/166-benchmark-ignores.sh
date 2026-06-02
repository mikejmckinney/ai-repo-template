#!/usr/bin/env bash
# scripts/checks/166-benchmark-ignores.sh — benchmark secrecy contract guard.
# Sourced by test.sh; relies on pass()/fail() and CWD == repo root.

echo "Checking benchmark ignore rules..."

if [[ -f "scripts/benchmark/.gitignore" ]]; then
  pass "scripts/benchmark/.gitignore exists"
else
  fail "scripts/benchmark/.gitignore is missing"
fi

for path in "scripts/benchmark/candidates.tsv" "scripts/benchmark/runs/" "scripts/benchmark/worktrees/"; do
  if git check-ignore -q -- "${path}"; then
    pass "${path} is ignored by git"
  else
    fail "${path} is not ignored by git"
  fi
done
