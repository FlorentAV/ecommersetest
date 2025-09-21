#!/bin/bash
# scripts/medusa-start.sh - Medusa Backend Startup

set -e

echo "🚀 Starting Medusa Backend..."

# Wait for database
echo "⏳ Waiting for database connection..."
until pg_isready -h "${DATABASE_HOST:-postgres}" -p "${DATABASE_PORT:-5432}" -U "${POSTGRES_USER:-paydusa_user}"; do
  echo "Database is unavailable - sleeping..."
  sleep 2
done

echo "✅ Database is ready!"

# Run migrations
echo "🔄 Running Medusa migrations..."
npx medusa migrations run

# Create admin user if specified
if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  echo "👤 Creating admin user..."
  npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" || echo "Admin user might already exist"
fi

# Seed data if in development
if [ "$SEED_DATA" = "true" ]; then
  echo "🌱 Seeding data..."
  npm run seed || echo "Seeding failed or already completed"
fi

# Start Medusa
echo "🌟 Starting Medusa server..."
exec npm run start

---

#!/bin/bash
# scripts/storefront-start.sh - Storefront Startup

set -e

echo "🚀 Starting Next.js Storefront..."

# Wait for database
echo "⏳ Waiting for database connection..."
until pg_isready -h "${DATABASE_HOST:-postgres}" -p "${DATABASE_PORT:-5432}" -U "${POSTGRES_USER:-paydusa_user}"; do
  echo "Database is unavailable - sleeping..."
  sleep 2
done

echo "✅ Database is ready!"

# Wait for Medusa backend
echo "⏳ Waiting for Medusa backend..."
until curl -f "${MEDUSA_BACKEND_URL:-http://medusa:9000}/health" >/dev/null 2>&1; do
  echo "Medusa backend is unavailable - sleeping..."
  sleep 2
done

echo "✅ Medusa backend is ready!"

# Run PayloadCMS migrations
echo "🔄 Running PayloadCMS migrations..."
npx payload migrate || echo "Migration failed or already completed"

# Start Next.js
echo "🌟 Starting Next.js server..."
exec node server.js

---

#!/bin/bash
# scripts/email-start.sh - Email Service Startup

set -e

echo "🚀 Starting Email Service..."

# Start email service
echo "📧 Starting React Email server..."
exec npm run start

---

#!/bin/bash
# scripts/wait-for-services.sh - Wait for all services

wait_for_service() {
  local service_name=$1
  local service_url=$2
  local timeout=${3:-60}
  
  echo "⏳ Waiting for $service_name at $service_url..."
  
  for i in $(seq 1 $timeout); do
    if curl -f "$service_url" >/dev/null 2>&1; then
      echo "✅ $service_name is ready!"
      return 0
    fi
    echo "Attempt $i/$timeout: $service_name not ready, waiting..."
    sleep 2
  done
  
  echo "❌ $service_name failed to start within $timeout attempts"
  return 1
}

# Wait for PostgreSQL
until pg_isready -h "${DATABASE_HOST:-postgres}" -p "${DATABASE_PORT:-5432}" -U "${POSTGRES_USER:-paydusa_user}"; do
  echo "Database is unavailable - sleeping..."
  sleep 2
done

# Wait for Redis
until redis-cli -h "${REDIS_HOST:-redis}" -p "${REDIS_PORT:-6379}" ping >/dev/null 2>&1; do
  echo "Redis is unavailable - sleeping..."
  sleep 2
done

# Wait for services
wait_for_service "Medusa Backend" "${MEDUSA_BACKEND_URL:-http://medusa:9000}/health"
wait_for_service "Storefront" "${FRONTEND_URL:-http://storefront:3000}/api/health"

echo "🎉 All services are ready!"