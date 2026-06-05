# ==========================================================
# CINEGRAM ROOT DOCKERFILE
# Packages the backend application from the repository root.
# ==========================================================

FROM node:22-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production

FROM node:22-alpine
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=400"
ENV PORT=7860
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./
COPY . .
EXPOSE 7860 3000
USER node
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "const ports = [process.env.PORT, 7860, 3000].filter(Boolean); (async () => { for (const p of ports) { try { const r = await fetch('http://localhost:' + p + '/health'); if (r.ok) process.exit(0); } catch {} } process.exit(1); })()"
CMD ["node", "server.js"]
