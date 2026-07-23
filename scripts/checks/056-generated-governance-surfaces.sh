#!/usr/bin/env bash
# Sourced by test.sh; relies on pass()/fail() and CWD == repo root.

echo "Checking generated governance surfaces..."

if python3 scripts/generate-pap-catalog.py --repo . --check; then
  pass "generated P/AP catalog is current"
else
  fail "generated P/AP catalog is stale"
fi

if python3 scripts/generate-issue-plans.py --repo . --check; then
  pass "generated issue-plan blocks are current"
else
  fail "generated issue-plan blocks are stale"
fi

if python3 scripts/validate-active-labels.py --repo .; then
  pass "active structured label references are declared"
else
  fail "active structured label references include undeclared labels"
fi

if python3 scripts/generate-agent-runtime.py --repo . --check; then
  pass "generated agent runtime profiles are current"
else
  fail "generated agent runtime profiles are stale"
fi

if python3 scripts/generate-mcp-configs.py --repo . --check; then
  pass "generated MCP host configurations are current"
else
  fail "generated MCP host configurations are stale"
fi

if python3 scripts/skill-supply-chain.py render-license-inventory \
  --repo . --lock skills-lock.json --check; then
  pass "generated skill license inventory is current"
else
  fail "generated skill license inventory is stale"
fi

echo ""
