# Dockerfile.simple - Single container for all services
FROM node:20-alpine AS base

# Install required packages
RUN apk add --no-cache curl postgresql-client libc6-compat
RUN npm install -g pnpm pm2

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/*/package.json ./apps/*/
COPY packages/*/package.json ./packages/*/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build all applications
RUN pnpm build

# Create startup script inline
RUN cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Paydusa Platform..."

# Wait for database
echo "⏳ Waiting for database..."
until pg_isready -h "${DATABASE_HOST:-postgres}" -p 5432 -U "${POSTGRES_USER:-paydusa_user}"; do
  sleep 2
done

# Run migrations
echo "🔄 Running migrations..."
cd apps/medusa && npx medusa migrations run && cd ../..
cd apps/storefront && npx payload migrate && cd ../..

# Create PM2 ecosystem
cat > ecosystem.config.js << 'PM2_EOF'
module.exports = {
  apps: [
    {
      name: 'medusa',
      cwd: './apps/medusa',
      script: 'npm',
      args: 'run start',
      env: { PORT: 9000 },
    },
    {
      name: 'storefront',
      cwd: './apps/storefront',
      script: 'npm',
      args: 'run start',
      env: { PORT: 3000 },
    }
  ]
};
PM2_EOF

# Start with PM2
echo "🌟 Starting applications..."
exec pm2-runtime start ecosystem.config.js
EOF

RUN chmod +x start.sh

# Create uploads directories
RUN mkdir -p uploads

EXPOSE 3000 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || curl -f http://localhost:9000/health || exit 1

CMD ["./start.sh"]