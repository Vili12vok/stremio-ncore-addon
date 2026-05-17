FROM golang:1.24-alpine AS go-build
WORKDIR /app
COPY torrent-server/go.mod ./go.mod
COPY torrent-server/go.sum ./go.sum
RUN go mod download
COPY ./torrent-server ./
RUN CGO_ENABLED=0 GOOS=linux go build -o ./torrent-server

FROM node:20.16.0-alpine AS node-base
WORKDIR /app

COPY package.json ./
COPY ./patches ./patches
COPY ./server/package.json ./server/package.json
COPY ./client/package.json ./client/package.json

FROM node-base AS prod-deps
RUN npm install --omit=dev

FROM node-base AS build-deps
RUN npm install

FROM build-deps AS build
COPY . .
RUN npm run build:server
RUN npm run build:client

FROM node-base AS runtime
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/server/dist ./server/dist
COPY --from=build /app/client/dist ./client/dist
COPY --from=go-build /app/torrent-server ./torrent-server

EXPOSE 3000
CMD ["node", "server/dist/index.js"]
