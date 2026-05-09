#!/bin/bash
# Description: Reset database to clean state
# Usage: ./scripts/db-reset.sh
#
# WARNING: This will DELETE all data in the database!
#
# TEMPLATE_PLACEHOLDER: Customize this for your database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

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
