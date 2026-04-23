#!/bin/bash
# Description: Reset database to clean state
# Usage: ./scripts/db-reset.sh
#
# WARNING: This will DELETE all data in the database!
#
# TEMPLATE_PLACEHOLDER: Customize this for your database

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf '%b[INFO]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn() { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1"; }

echo "========================================"
echo "Database Reset"
echo "========================================"
echo ""

# Safety check
printf '%bWARNING: This will DELETE all data in the database!%b\n' "$RED" "$NC"
echo ""
read -r -p "Are you sure? Type 'yes' to continue: " confirm

if [[ "$confirm" != "yes" ]]; then
    log_info "Aborted."
    exit 0
fi

echo ""
log_info "Starting database reset..."

# =====================================================
# CUSTOMIZE THIS SECTION FOR YOUR DATABASE
# =====================================================

# Prisma (Node.js)
# if [[ -f "prisma/schema.prisma" ]]; then
#     log_info "Resetting Prisma database..."
#     npx prisma migrate reset --force
#     log_info "Prisma database reset complete"
# fi

# Django (Python)
# if [[ -f "manage.py" ]]; then
#     log_info "Resetting Django database..."
#     python manage.py flush --no-input
#     python manage.py migrate
#     log_info "Django database reset complete"
# fi

# Alembic (Python)
# if [[ -f "alembic.ini" ]]; then
#     log_info "Resetting Alembic database..."
#     alembic downgrade base
#     alembic upgrade head
#     log_info "Alembic database reset complete"
# fi

# Raw PostgreSQL
# if [[ -n "$DATABASE_URL" ]]; then
#     log_info "Dropping and recreating database..."
#     psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
#     log_info "PostgreSQL database reset complete"
# fi

# Docker Compose
# if [[ -f "docker-compose.yml" ]]; then
#     log_info "Resetting Docker database volumes..."
#     docker-compose down -v
#     docker-compose up -d db
#     sleep 5  # Wait for DB to start
#     log_info "Docker database reset complete"
# fi

# =====================================================
# PLACEHOLDER
# =====================================================
log_warn "No database configuration detected."
log_warn "Customize scripts/db-reset.sh for your database."

echo ""
log_info "Database reset complete!"
