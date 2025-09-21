#!/bin/bash
set -e

echo "🚀 Starting Paydusa Platform..."

# Wait for database
echo "⏳ Waiting for database..."
until pg_isready -h "${DATABASE_HOST:-postgres}" -p 5432 -U "${POSTGRES_USER:-paydusa_user}"; do
  echo "Database is unavailable - sleeping..."
  sleep 2
done

echo "✅ Database is ready!"

# Run migrations
echo "🔄 Running Medusa migrations..."
cd apps/medusa
npx medusa migrations run || echo "Medusa migration failed or already completed"
cd ../..

echo "🔄 Running PayloadCMS migrations..."
cd apps/storefront  
npx payload migrate || echo "Payload migration failed or already completed"
cd ../..

# Create admin user if specified
if [ -n "$MEDUSA_ADMIN_EMAIL" ] && [ -n "$MEDUSA_ADMIN_PASSWORD" ]; then
  echo "👤 Creating admin user..."
  cd apps/medusa
  npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" || echo "Admin user might already exist"
  cd ../..
fi

# Create PM2 ecosystem config
echo "🌟 Creating PM2 configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'medusa',
      cwd: './apps/medusa',
      script: 'npm',
      args: 'run start',
      env: {
        NODE_ENV: 'production',
        PORT: 9000
      },
      restart_delay: 1000,
      max_restarts: 10
    },
    {
      name: 'storefront',
      cwd: './apps/storefront',
      script: 'npm', 
      args: 'run start',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      restart_delay: 1000,
      max_restarts: 10
    }
  ]
};
EOF

# Start applications with PM2
echo "🌟 Starting applications with PM2..."
exec pm2-runtime start ecosystem.config.js --web