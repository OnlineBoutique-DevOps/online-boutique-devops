FROM node:18-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --omit=dev

COPY app.js ./

EXPOSE 8080

CMD ["node", "app.js"]
