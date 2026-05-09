#!/usr/bin/env bash
# scripts/checks/100-config-templates.sh — extracted from test.sh by issue #255 Phase 4d.
# Sourced by test.sh; relies on $PASS/$FAIL/$WARN, pass()/fail()/warn() from
# scripts/lib/{logging,assertions}.sh and CWD == repo root.

# --- Config Templates Check ---
echo "Checking config templates..."

CONFIG_FILES=(
  "config/README.md"
  "config/vercel.json.template"
  "config/railway.toml.template"
  "config/render.yaml.template"
  "config/docker-compose.yml.template"
  ".pre-commit-config.yaml.template"
  ".cursorignore"
)

for file in "${CONFIG_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

echo ""
