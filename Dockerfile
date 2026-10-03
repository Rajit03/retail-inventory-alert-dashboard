# syntax=docker/dockerfile:1
# Build stage for native dependencies
FROM node:22-bookworm-slim AS build

WORKDIR /app

# Install native build tools for compiling better-sqlite3
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
 && rm -rf /var/lib/apt/lists/*

# Copy package manifests and install production dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Runtime stage
FROM node:22-bookworm-slim AS runtime

# OCI Labels
LABEL org.opencontainers.image.title="Retail Inventory Alert Dashboard" \
      org.opencontainers.image.description="Containerized retail inventory dashboard with stock alerts" \
      org.opencontainers.image.source="https://github.com/Rajit03/retail-inventory-alert-dashboard" \
      org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Copy production node_modules from build stage
COPY --from=build /app/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY src ./src
COPY public ./public

# Environment configuration
ENV NODE_ENV=production \
    PORT=3000 \
    DB_PATH=/app/data/inventory.db

# Create data directory with proper ownership for non-root node user
RUN mkdir -p /app/data && chown -R node:node /app

# Declare persistent data volume
VOLUME ["/app/data"]

# Switch to non-root user
USER node

# Expose default application port
EXPOSE 3000

# Container health check using Node.js built-in fetch
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))"

# Start the application server
CMD ["node", "src/server.js"]
