#!/bin/bash
# 30-build.sh — Run `npm run build` if package.json declares a build script.

log_step "Building project"

# Check specifically for scripts.build to avoid false positives
# Use node to properly parse JSON if available, otherwise fall back to grep
BUILD_EXISTS=false
if [[ -f "package.json" ]]; then
  if command -v node &>/dev/null; then
    # Use node to properly check for scripts.build
    # Avoid optional chaining (?.) for compatibility with Node <14
    BUILD_EXISTS=$(node -e "var p=require('./package.json'); console.log(!!(p.scripts && p.scripts.build))" 2>/dev/null || echo "false")
  fi

  # Fallback to grep if node failed or not available
  if [[ "$BUILD_EXISTS" != "true" ]]; then
    # Options before pattern for BSD grep compatibility
    if grep -q '"scripts"' package.json && grep -A100 '"scripts"' package.json | grep -q '^\s*"build":'; then
      BUILD_EXISTS="true"
    fi
  fi
fi

if [[ "$BUILD_EXISTS" == "true" ]]; then
  log_info "Running build..."
  npm run build
  log_info "Build complete"
else
  log_info "No build step configured"
fi
