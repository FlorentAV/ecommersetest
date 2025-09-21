# Multi-stage Dockerfile for Paydusa Monorepo
FROM node:20-alpine AS base

# Install pnpm
RUN npm install -g pnpm

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY turbo.json ./

# Copy apps package.json files
COPY apps/medusa/package.json ./apps/medusa/
COPY apps/storefront/package.json ./apps/storefront/
COPY apps/email/package.json ./apps/email/
COPY packages/*/package.json ./packages/*/

# Install dependencies
FROM base AS deps
RUN pnpm install --frozen-lockfile

# Build stage
FROM base AS builder
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# Build all applications
RUN pnpm build

# Production runtime
FROM node:20-alpine AS runner
WORKDIR /app

# Install pnpm in runtime
RUN npm install -g pnpm

# Copy built applications and dependencies
COPY --from=builder /app/apps ./apps
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-workspace.yaml ./
COPY --from=builder /app/turbo.json ./

# Copy startup scripts
COPY scripts/ ./scripts/
RUN chmod +x ./scripts/*.sh

# Expose ports
EXPOSE 3000 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["./scripts/start.sh"]