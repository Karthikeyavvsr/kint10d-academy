FROM node:24-bookworm-slim
WORKDIR /app
COPY package.json server.mjs ./
ENV NODE_ENV=production
CMD ["node", "server.mjs"]
