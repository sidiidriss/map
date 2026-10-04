# Image du serveur Sahla. Construire depuis le dossier sahla/ :
#   docker build -t sahla .
#   docker run -p 8787:8787 -e ANTHROPIC_API_KEY=... sahla
FROM node:22-alpine AS construction
WORKDIR /app/serveur
COPY serveur/package.json serveur/package-lock.json ./
RUN npm ci
COPY serveur/ ./
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
ENV NODE_ENV=production PORT=8787
WORKDIR /app/serveur
COPY --from=construction /app/serveur/node_modules ./node_modules
COPY --from=construction /app/serveur/dist ./dist
COPY serveur/package.json ./
COPY serveur/public ./public
COPY connaissances /app/connaissances
USER node
EXPOSE 8787
CMD ["node", "dist/index.js"]
