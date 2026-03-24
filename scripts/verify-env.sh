#!/bin/bash
# Description: Verify development environment is properly configured
# Usage: ./scripts/verify-env.sh
#
# This script checks that all required tools and configurations are in place.
# Run this before starting development or when troubleshooting issues.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { printf "${GREEN}✓${NC} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}✗${NC} %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; WARN=$((WARN + 1)); }

echo "========================================"
echo "Environment Verification"
echo "========================================"
echo ""

# --- Git ---
echo "Checking Git..."
if command -v git &> /dev/null; then
    pass "git is installed ($(git --version | head -1))"
else
    fail "git is not installed"
fi

if git rev-parse --git-dir &> /dev/null; then
    pass "Current directory is a git repository"
else
    fail "Current directory is not a git repository"
fi

echo ""

# --- Node.js (if package.json exists) ---
if [[ -f "package.json" ]]; then
    echo "Checking Node.js..."
    if command -v node &> /dev/null; then
        pass "node is installed ($(node --version))"
    else
        fail "node is not installed"
    fi
    
    if command -v npm &> /dev/null; then
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
    if command -v python3 &> /dev/null; then
        pass "python3 is installed ($(python3 --version))"
    else
        fail "python3 is not installed"
    fi
    
    if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
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
    if command -v docker &> /dev/null; then
        pass "docker is installed"
        if docker info &> /dev/null; then
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

if [[ -f ".context/state/_active.md" ]]; then
    pass ".context/state/_active.md exists"
else
    warn ".context/state/_active.md missing"
fi

echo ""

# --- Template Verification ---
echo "Checking for template placeholders..."
# Prefer excluding directories during traversal; fall back to find-based scan
if grep --help 2>&1 | grep -q -- "--exclude-dir"; then
    # grep supports --exclude-dir (GNU grep)
    PLACEHOLDER_COUNT=$(grep -rl --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=venv --exclude-dir=.venv --exclude-dir=__pycache__ "TEMPLATE_PLACEHOLDER" . 2>/dev/null | wc -l | tr -d ' ')
else
    # Portable fallback using find -prune to avoid descending into heavy directories
    PLACEHOLDER_COUNT=$(find . \( -name .git -o -name node_modules -o -name venv -o -name .venv -o -name __pycache__ \) -prune -o -type f -exec grep -l "TEMPLATE_PLACEHOLDER" {} + 2>/dev/null | wc -l | tr -d ' ')
fi
if [[ "$PLACEHOLDER_COUNT" -gt 0 ]]; then
    warn "$PLACEHOLDER_COUNT files still contain TEMPLATE_PLACEHOLDER"
else
    pass "No TEMPLATE_PLACEHOLDER markers found"
fi

echo ""

# --- Summary ---
echo "========================================"
echo "Summary"
echo "========================================"
printf "${GREEN}Passed:${NC} %d\n" "$PASS"
printf "${YELLOW}Warnings:${NC} %d\n" "$WARN"
printf "${RED}Failed:${NC} %d\n" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    printf "${RED}Environment verification FAILED${NC}\n"
    echo "Fix the failed checks before proceeding."
    exit 1
elif [[ $WARN -gt 0 ]]; then
    printf "${YELLOW}Environment verification PASSED with warnings${NC}\n"
    exit 0
else
    printf "${GREEN}Environment verification PASSED${NC}\n"
    exit 0
fi
