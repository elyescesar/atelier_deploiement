FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY server.js ecosystem.config.cjs ./

ENV NODE_ENV=production
ENV PORT=3000
ENV MONGO_URI=mongodb://mongo:27017/shop

EXPOSE 3000

CMD ["npx", "pm2-runtime", "start", "ecosystem.config.cjs"]
