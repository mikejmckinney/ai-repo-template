#!/bin/bash
# 20-install-dependencies.sh — Install Node.js / Python deps + database stub.
#
# Sourced by scripts/setup.sh. Bundles legacy Step 2 (deps) + Step 3 (database)
# because the database step is currently a placeholder for project customization.

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

# --- Database Setup (if applicable) ---
log_step "Setting up database"

# Uncomment and customize for your project:
# if [[ -f "prisma/schema.prisma" ]]; then
#     log_info "Running Prisma migrations..."
#     npx prisma migrate dev
#     log_info "Database migrations complete"
# fi

# if [[ -f "alembic.ini" ]]; then
#     log_info "Running Alembic migrations..."
#     alembic upgrade head
#     log_info "Database migrations complete"
# fi

log_info "No database configuration detected (customize setup.sh if needed)"
