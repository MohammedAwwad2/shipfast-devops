FROM node:24-alpine

WORKDIR /app
ENV APP_ENV=production
COPY package*.json ./

RUN if [ "$APP_ENV" = "production" ]; then \
      npm ci --omit=dev; \
    else \
      npm ci; \
    fi



RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --chown=appuser:appgroup . .
USER appuser

EXPOSE 3000



ARG REPO_URL
LABEL org.opencontainers.image.source=${REPO_URL}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

  CMD ["node", "index.js"]