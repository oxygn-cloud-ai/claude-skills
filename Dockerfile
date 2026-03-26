FROM node:22-slim

WORKDIR /app

# Copy and install dependencies
COPY server/package.json server/package-lock.json ./server/
RUN cd server && npm ci --omit=dev

# Copy application code
COPY server/*.js ./server/
COPY client/ ./client/

# Serverless handler on port 8000 (RunPod proxy port)
# Also works standalone: PORT=3000 node server/server.js
ENV PORT=8000
EXPOSE 8000

CMD ["node", "server/handler.js"]
