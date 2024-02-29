ARG GIT_TAG=${GIT_TAG:-main}
ARG BASE_IMAGE=${BASE_IMAGE:-ghcr.io/linuxserver/baseimage-alpine:3.18}

### STAGE 1: Build ###
FROM node:20-alpine AS build

RUN apk add --no-cache yarn && \
    apk add --no-cache git

ARG GIT_TAG
RUN git clone --branch ${GIT_TAG} https://github.com/njfamirm/decap-cms-github-backend.git /app

RUN cd /app && \
    yarn install --frozen-lockfile --non-interactive --production false && \
    yarn build && \
    rm -rf node_modules && \
    yarn install --frozen-lockfile --non-interactive --production true

COPY ./root /final

RUN mkdir -p /final/app
RUN mv /app/package.json /final/app/
RUN mv /app/node_modules /final/app/
RUN mv /app/dist /final/app/dist/

### STAGE 2: Runner ###
FROM ${BASE_IMAGE} AS runner

ARG \
    BUILDPLATFORM \
    BUILDOS \
    BUILDARCH \
    TARGETPLATFORM \
    TARGETOS \
    TARGETARCH \
    TARGETOS \
    GIT_TAG \
    BASE_IMAGE

ENV \
    NODE_ENV=${NODE_ENV:-production} \
    NODE_OPTIONS=--enable-source-maps \
    ALWATR_DEBUG=${ALWATR_DEBUG:-0} \
    TZ=${TZ:-UTC} \
    HOST=${HOST:-0.0.0.0} \
    PORT=${PORT:-3000} \
    PUID=${PUID:-1000} \
    PGID=${PGID:-1000}

COPY --from=build /final/ /

RUN \
    apk --update --upgrade --no-cache add \
    ca-certificates \
    tzdata \
    nodejs \
    npm \
    yarn \
    jq && \
    update-ca-certificates && \
    cd /app && \
    yarn install --production --frozen-lockfile && \
    echo -e "\n\n[√] Finished Docker build successfully. Saving build summary in: /VERSION.txt\n" && \
    ( \
    echo -e "     **** BUILD INFO ****\n" && \
    echo -e "$(date +"%Y-%m-%d %H:%M:%S %s") ${TZ}\n" && \
    echo -e "Builder:     ${BUILDOS}/${BUILDARCH}\n" && \
    echo -e "Final Image: ${BASE_IMAGE}" && \
    echo -e "OS/Arch:     $(uname -m) (${TARGETOS}/${TARGETARCH})\n" && \
    echo -e "App:         v$(cat /app/package.json | jq -r '.version')" && \
    echo -e "Tag:         ${GIT_TAG}" && \
    echo -e "Commit:      $(curl -s https://api.github.com/repos/njfamirm/decap-cms-github-backend/commits/${GIT_TAG} | jq -r '.sha' | cut -c 1-7)\n" && \
    echo -e "Node:        $(node --version)" && \
    echo -e "NPM:         v$(npm --version)" && \
    echo -e "Yarn:        v$(yarn --version)" && \
    ) | tee -a /VERSION.txt

EXPOSE 3000
