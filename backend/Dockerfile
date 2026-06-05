# ==========================================================
# CINEGRAM BACKEND DOCKERFILE
# Production-ready, ultra-lightweight, and memory-optimized.
# Targets low-memory environments (512MB RAM limits like Render Free Tier).
# ==========================================================

# --- Stage 1: Build & Dependency Resolution ---
FROM node:22-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Copy dependency files
COPY package*.json ./

# Install only production dependencies to minimize image size and memory footprint
RUN npm ci --only=production

# --- Stage 2: Production Runtime ---
FROM node:22-alpine

# Set secure environment variables
ENV NODE_ENV=production

# Enforce Node heap limits to prevent out-of-memory (OOM) kills inside 512MB RAM containers
# Capping old-space at 400MB leaves sufficient headroom for system libraries and connection pools
ENV NODE_OPTIONS="--max-old-space-size=400"

WORKDIR /usr/src/app

# Copy production node_modules from the builder stage
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./

# Copy application source code
COPY . .

# Expose the public port for the Express application
EXPOSE 3000

# Run container under a non-root system user for maximum container security
USER node

# Health check to ensure the gateway server and endpoints are reachable
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3000) + '/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Boot up the server
CMD ["node", "server.js"]
