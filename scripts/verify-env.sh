#!/bin/bash
# Description: Verify development environment is properly configured
# Usage: ./scripts/verify-env.sh
#
# This script checks that all required tools and configurations are in place.
# Run this before starting development or when troubleshooting issues.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=scripts/lib/assertions.sh
source "$SCRIPT_DIR/lib/assertions.sh"
# shellcheck source=scripts/lib/versions.sh
source "$SCRIPT_DIR/lib/versions.sh"
# ---------------------------------------------------------------------------
# Argument parsing and --fix mode infrastructure (issue #365)
# ---------------------------------------------------------------------------
_FIX_MODE=false
for _arg in "$@"; do
  case "$_arg" in
    --fix) _FIX_MODE=true ;;
    *)
      log_error "Unknown option: $_arg"
      exit 1
      ;;
  esac
done
unset _arg

# Static fix allowlist: only these three tools are eligible for --fix
# remediation. Expansion requires a PR updating this list and the plan.
_fix_package_for_tool() {
  case "$1" in
    rg)
      printf '%s\n' "ripgrep"
      ;;
    shellcheck)
      printf '%s\n' "shellcheck"
      ;;
    jq)
      printf '%s\n' "jq"
      ;;
    *)
      return 1
      ;;
  esac
}

# Repo-required tools checked on every run.
_REQUIRED_TOOLS=(rg shellcheck jq)

# Test injection only: append extra tool names to _REQUIRED_TOOLS for bats
# fixture coverage of the non-allowlisted rejection path. Leave unset in
# production use.
if [[ -n "${_VERIFY_ENV_EXTRA_REQUIRED_TOOLS:-}" ]]; then
  read -ra _extra <<<"$_VERIFY_ENV_EXTRA_REQUIRED_TOOLS"
  _REQUIRED_TOOLS+=("${_extra[@]}")
  unset _extra
fi

# Helper: attempt to install a tool via the platform package manager.
# Logs each action to stdout. Exits non-zero if privilege is absent on
# Linux or if the install command fails.
_fix_install() {
  local tool="$1" pkg="$2"
  local _os
  _os=$(uname -s)
  if [[ "$_os" == "Darwin" ]]; then
    if ! command -v brew &>/dev/null; then
      log_error "[fix] Cannot install $tool: brew is required on macOS — install Homebrew or install $pkg manually"
      exit 1
    fi
    log_info "[fix] Installing $tool via brew install $pkg"
    brew install "$pkg"
  else
    if ! command -v apt-get &>/dev/null; then
      log_error "[fix] Cannot install $tool: apt-get is required on this Linux system — install $pkg manually"
      exit 1
    fi
    if [[ "$(id -u)" == "0" ]]; then
      log_info "[fix] Installing $tool via apt-get install -y $pkg (root)"
      apt-get install -y "$pkg"
    elif command -v sudo &>/dev/null; then
      log_info "[fix] Installing $tool via sudo apt-get install -y $pkg"
      sudo apt-get install -y "$pkg"
    else
      log_error "[fix] Cannot install $tool: root or sudo required — re-run as root or grant sudo access"
      exit 1
    fi
  fi
}

echo "========================================"
echo "Environment Verification"
echo "========================================"
echo ""

# --- Git ---
echo "Checking Git..."
if command -v git &>/dev/null; then
  pass "git is installed ($(git --version | head -1))"
else
  fail "git is not installed"
fi

if git rev-parse --git-dir &>/dev/null; then
  pass "Current directory is a git repository"
else
  fail "Current directory is not a git repository"
fi

echo ""

# --- Repo-required tools ---
echo "Checking repo-required tools..."
for _tool in "${_REQUIRED_TOOLS[@]}"; do
  if command -v "$_tool" &>/dev/null; then
    pass "$_tool is installed"
  else
    if [[ "$_FIX_MODE" == "true" && "$FAIL" -eq 0 ]]; then
      if _pkg=$(_fix_package_for_tool "$_tool"); then
        _fix_install "$_tool" "$_pkg"
        unset _pkg
        if command -v "$_tool" &>/dev/null; then
          pass "$_tool installed successfully via --fix"
        else
          fail "$_tool install attempted but tool still not found"
        fi
      else
        log_error "[fix] $_tool is not on the fix allowlist — install it manually"
        exit 1
      fi
    else
      fail "$_tool is not installed"
    fi
  fi
done
unset _tool
echo ""

echo "Checking managed runtime prerequisites..."
if command -v uvx &>/dev/null; then
  pass "uvx is installed ($(uvx --version 2>&1 | head -1))"
else
  fail "uvx is not installed; install the pinned uv tool profile"
fi

bats_minimum="$(jq -r '.tools.bats.minimum_version' \
  "$SCRIPT_DIR/../.config/codespace-tools.json")"
if command -v bats &>/dev/null; then
  bats_output="$(bats --version 2>&1 || true)"
  bats_version="$(extract_version "$bats_output")"
  if [[ -n "$bats_version" ]] && version_at_least "$bats_version" "$bats_minimum"; then
    pass "bats $bats_version satisfies minimum version $bats_minimum"
  else
    fail "bats $bats_version is below required version $bats_minimum"
  fi
else
  fail "bats is not installed; required version is $bats_minimum or newer"
fi
echo ""

# --- Node.js (if package.json exists) ---
if [[ -f "package.json" ]]; then
  echo "Checking Node.js..."
  if command -v node &>/dev/null; then
    pass "node is installed ($(node --version))"
  else
    fail "node is not installed"
  fi

  if command -v npm &>/dev/null; then
    pass "npm is installed ($(npm --version))"
  else
    fail "npm is not installed"
  fi

  if [[ -d "node_modules" ]]; then
    pass "node_modules exists"
  else
    warn "node_modules missing - run 'npm install'"
  fi
  echo ""
fi

# --- Python (if requirements.txt or pyproject.toml exists) ---
if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
  echo "Checking Python..."
  if command -v python3 &>/dev/null; then
    pass "python3 is installed ($(python3 --version))"
  else
    fail "python3 is not installed"
  fi

  if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    pass "pip is installed"
  else
    fail "pip is not installed"
  fi
  echo ""
fi

# --- Environment Variables ---
echo "Checking environment files..."
if [[ -f ".env" ]]; then
  pass ".env file exists"
elif [[ -f ".env.example" ]]; then
  warn ".env missing but .env.example exists - copy and configure"
else
  warn "No .env file found"
fi

echo ""

# --- Docker (if docker-compose exists) ---
if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
  echo "Checking Docker..."
  if command -v docker &>/dev/null; then
    pass "docker is installed"
    if docker info &>/dev/null; then
      pass "docker daemon is running"
    else
      fail "docker daemon is not running"
    fi
  else
    fail "docker is not installed"
  fi
  echo ""
fi

# --- Context Pack ---
echo "Checking context pack..."
if [[ -f ".context/00_INDEX.md" ]]; then
  pass ".context/00_INDEX.md exists"
else
  warn ".context/00_INDEX.md missing - run repo-onboarding"
fi

echo ""

# --- Summary ---
echo "========================================"
echo "Summary"
echo "========================================"
printf '%bPassed:%b %d\n' "$GREEN" "$NC" "$PASS"
printf '%bWarnings:%b %d\n' "$YELLOW" "$NC" "$WARN"
printf '%bFailed:%b %d\n' "$RED" "$NC" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  printf '%bEnvironment verification FAILED%b\n' "$RED" "$NC"
  echo "Fix the failed checks before proceeding."
  exit 1
elif [[ $WARN -gt 0 ]]; then
  printf '%bEnvironment verification PASSED with warnings%b\n' "$YELLOW" "$NC"
  exit 0
else
  printf '%bEnvironment verification PASSED%b\n' "$GREEN" "$NC"
  exit 0
fi
