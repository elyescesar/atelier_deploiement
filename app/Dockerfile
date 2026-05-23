FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY server.js db.js seed.js ecosystem.config.cjs ./
COPY public ./public

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["npx", "pm2-runtime", "start", "ecosystem.config.cjs"]
