#!/bin/bash
# 20-install-dependencies.sh — Install dependencies declared by project manifests.

log_step "Installing dependencies"

# Node.js
if [[ -f "package.json" ]]; then
  log_info "Found package.json, installing Node.js dependencies..."
  if [[ -f "package-lock.json" ]]; then
    npm ci
  else
    npm install
  fi
  log_info "Node.js dependencies installed"
fi

# Python
if [[ -f "requirements.txt" ]]; then
  log_info "Found requirements.txt, installing Python dependencies..."
  pip install -r requirements.txt
  log_info "Python dependencies installed"
elif [[ -f "pyproject.toml" ]]; then
  log_info "Found pyproject.toml, installing Python dependencies..."
  pip install -e .
  log_info "Python dependencies installed"
fi
