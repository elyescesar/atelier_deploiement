FROM public.ecr.aws/amazonlinux/amazonlinux:2023

WORKDIR /app

RUN dnf install -y nodejs npm && dnf clean all

COPY package.json ./
RUN npm install --production

COPY server.js ecosystem.config.cjs ./

ENV NODE_ENV=production
ENV PORT=3000
ENV MONGO_URI=mongodb://mongo:27017/shop

EXPOSE 3000

CMD ["npx", "pm2-runtime", "start", "ecosystem.config.cjs"]
