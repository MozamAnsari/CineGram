# ==========================================================
# CINEGRAM ROOT DOCKERFILE
# Packages the backend application from the repository root.
# ==========================================================

FROM node:22-alpine AS builder
WORKDIR /usr/src/app
COPY backend/package*.json ./
RUN npm ci --only=production

FROM node:22-alpine
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=400"
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY backend/package*.json ./
COPY backend/ .
EXPOSE 3000
USER node
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"
CMD ["node", "server.js"]
