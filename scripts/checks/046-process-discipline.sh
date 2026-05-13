#!/usr/bin/env bash
# scripts/checks/046-process-discipline.sh — ADR-026 compliance contract invariants.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

make_private_tmp() {
  local prefix=$1
  local old_umask
  local tmp

  old_umask=$(umask)
  umask 077
  if tmp=$(mktemp "${TMPDIR:-/tmp}/ai-repo-template-${USER:-user}-${prefix}.XXXXXX"); then
    umask "$old_umask"
    printf '%s\n' "$tmp"
  else
    umask "$old_umask"
    return 1
  fi
}

# --- Process Discipline / Compliance Contract Checks ---
echo "Checking process discipline contracts..."

if grep -q "process_subagent_bootstrap.md" AGENTS.md; then
  pass "AGENTS.md links process_subagent_bootstrap.md (ADR-026)"
else
  fail "AGENTS.md missing process_subagent_bootstrap.md link (ADR-026)"
fi

if grep -q "plan_compliance:" .github/PLAN_TEMPLATE.md; then
  pass "PLAN_TEMPLATE.md includes plan_compliance block (ADR-026)"
else
  fail "PLAN_TEMPLATE.md missing plan_compliance block (ADR-026)"
fi

if grep -q "parent_compliance:" .github/pull_request_template.md; then
  pass "pull_request_template.md includes parent_compliance block (ADR-026)"
else
  fail "pull_request_template.md missing parent_compliance block (ADR-026)"
fi

if grep -q "subagent_compliance" .github/copilot-instructions.md; then
  pass "copilot-instructions.md requires subagent_compliance on dispatch (ADR-026)"
else
  fail "copilot-instructions.md missing subagent_compliance dispatch guidance (ADR-026)"
fi

if python3 - <<'PY'; then
from pathlib import Path
import re
import sys
try:
    import yaml
except ImportError as exc:
    print(f"PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)
errors = []
for path in [Path('.github/PLAN_TEMPLATE.md'), Path('.github/pull_request_template.md')]:
    text = path.read_text(encoding='utf-8')
    blocks = list(re.finditer(r'^[ \t]*```yaml[ \t]*\n(.*?)\n[ \t]*```[ \t]*(?:\n|$)', text, re.S | re.M))
    if not blocks:
        errors.append(f"{path}: no yaml fenced blocks found")
        continue
    for idx, block in enumerate(blocks, start=1):
        try:
            yaml.safe_load(block.group(1))
        except yaml.YAMLError as exc:
            errors.append(f"{path}: yaml block {idx} does not parse: {exc}")
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
PY
  pass "plan and PR template YAML compliance scaffolds parse"
else
  fail "plan and PR template YAML compliance scaffolds must parse"
fi

if python3 - <<'PY'; then
from pathlib import Path
import re
import sys
try:
    import yaml
except ImportError as exc:
    print(f"PyYAML unavailable: {exc}", file=sys.stderr)
    sys.exit(1)
root = Path('.')
frontmatter_re = re.compile(r'\A[ \t]*---[ \t]*\n(.*?)\n[ \t]*---[ \t]*(?:\n|$)', re.S)
errors = []
for path in sorted((root / '.agents').glob('*.md')):
    if path.name in {'README.md', '_TEMPLATE.md'}:
        continue
    text = path.read_text(encoding='utf-8')
    match = frontmatter_re.search(text)
    if not match:
        errors.append(f"{path}: missing frontmatter")
        continue
    data = yaml.safe_load(match.group(1)) or {}
    version = data.get('role_contract_version')
    if type(version) is not int or version < 1:
        errors.append(f"{path}: role_contract_version must be a positive integer")
    if 'subagent_compliance' not in text:
        errors.append(f"{path}: missing subagent_compliance return guidance")
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
PY
  pass "canonical role files declare role_contract_version and subagent_compliance guidance"
else
  fail "canonical role files must declare role_contract_version and subagent_compliance guidance"
fi

overlay_hits=$(grep -RInw --include='*.md' --include='*.yml' --include='*.yaml' 'overlay_version:' \
  .agents .github/agents .claude/agents .github/PLAN_TEMPLATE.md .github/pull_request_template.md docs scripts \
  | grep -v '^scripts/tests/fixtures/compliance/invalid/' || true)
if [[ -z "$overlay_hits" ]]; then
  pass "no v1 role/platform files use overlay_version:"
else
  fail "overlay_version: is forbidden in ADR-026 v1 evidence"
  printf '%s\n' "$overlay_hits"
fi

compliance_examples_out=
compliance_examples_err=
if ! compliance_examples_out=$(make_private_tmp compliance-examples-out); then
  fail "docs/compliance_schemas.md YAML examples failed validation"
  echo "could not create private temporary output file"
elif ! compliance_examples_err=$(make_private_tmp compliance-examples-err); then
  fail "docs/compliance_schemas.md YAML examples failed validation"
  echo "could not create private temporary error file"
  rm -f "$compliance_examples_out"
elif python3 scripts/validate-compliance-examples.py >"$compliance_examples_out" 2>"$compliance_examples_err"; then
  pass "docs/compliance_schemas.md YAML examples validate"
else
  fail "docs/compliance_schemas.md YAML examples failed validation"
  cat "$compliance_examples_out" "$compliance_examples_err"
fi
rm -f "${compliance_examples_out:-}" "${compliance_examples_err:-}"

compliance_fixtures_out=
compliance_fixtures_err=
if ! compliance_fixtures_out=$(make_private_tmp compliance-fixtures-out); then
  fail "ADR-026 compliance fixtures failed validation"
  echo "could not create private temporary output file"
elif ! compliance_fixtures_err=$(make_private_tmp compliance-fixtures-err); then
  fail "ADR-026 compliance fixtures failed validation"
  echo "could not create private temporary error file"
  rm -f "$compliance_fixtures_out"
elif python3 scripts/validate-compliance-fixtures.py >"$compliance_fixtures_out" 2>"$compliance_fixtures_err"; then
  pass "ADR-026 compliance fixtures validate expected pass/fail behavior"
else
  fail "ADR-026 compliance fixtures failed validation"
  cat "$compliance_fixtures_out" "$compliance_fixtures_err"
fi
rm -f "${compliance_fixtures_out:-}" "${compliance_fixtures_err:-}"

echo ""

# End of process discipline checks.
