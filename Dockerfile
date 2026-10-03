# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim

# OCI Labels
LABEL org.opencontainers.image.title="Retail Inventory Alert Dashboard" \
      org.opencontainers.image.description="Containerized retail inventory dashboard with stock alerts" \
      org.opencontainers.image.source="https://github.com/Rajit03/retail-inventory-alert-dashboard" \
      org.opencontainers.image.version="1.0.0"

# Set working directory
WORKDIR /app

# Copy dependency definitions and install production dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copy application source code and public assets
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
