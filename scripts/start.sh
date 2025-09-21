#!/bin/bash
# scripts/start.sh - Main startup script

set -e

echo "🚀 Starting Paydusa Ecommerce Platform..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
./scripts/wait-for-db.sh

# Run database migrations
echo "🔄 Running database migrations..."
./scripts/migrate.sh

# Create admin user if not exists (optional)
echo "👤 Setting up admin user..."
./scripts/setup-admin.sh

# Start all services
echo "🌟 Starting applications..."
exec ./scripts/run-services.sh

---

#!/bin/bash
# scripts/wait-for-db.sh - Database readiness check

host="${DATABASE_HOST:-localhost}"
port="${DATABASE_PORT:-5432}"
user="${POSTGRES_USER:-ecom_user_7f29a4}"
database="${POSTGRES_DB:-postgres_db}"

echo "Waiting for PostgreSQL at $host:$port..."

while ! pg_isready -h "$host" -p "$port" -U "$user" -d "$database"; do
  echo "PostgreSQL is unavailable - sleeping..."
  sleep 2
done

echo "PostgreSQL is ready!"

---

#!/bin/bash
# scripts/migrate.sh - Database migrations

set -e

echo "Running Medusa migrations..."
cd apps/medusa
pnpm migrate
cd ../..

echo "Running PayloadCMS migrations..."
cd apps/storefront
npx payload migrate
cd ../..

echo "✅ All migrations completed successfully!"

---

#!/bin/bash
# scripts/setup-admin.sh - Admin user setup

set -e

if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  echo "Creating Medusa admin user..."
  cd apps/medusa
  npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" || echo "Admin user might already exist"
  cd ../..
fi

---

#!/bin/bash
# scripts/run-services.sh - Service orchestration

set -e

# Install PM2 for process management
npm install -g pm2

# Start services with PM2
pm2 start ecosystem.config.js

# Keep container running
pm2 logs

---

// ecosystem.config.js - PM2 configuration
module.exports = {
  apps: [
    {
      name: 'medusa-backend',
      cwd: './apps/medusa',
      script: 'npm',
      args: 'run start',
      env: {
        NODE_ENV: 'production',
        PORT: 9000,
      },
    },
    {
      name: 'storefront',
      cwd: './apps/storefront',
      script: 'npm',
      args: 'run start',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
    },
  ],
};