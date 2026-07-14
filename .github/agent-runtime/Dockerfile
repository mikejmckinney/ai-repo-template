FROM golang:1.25.12-bookworm@sha256:9b8bad821dbd3993215fb06ff9193cf34087f684ff113f391cb04c7cc3ecea15 AS github-mcp-build

ARG GITHUB_MCP_COMMIT=c36e4e4493c76eafe2c1a9cbc5272e8eede29189
ARG GITHUB_MCP_COMMIT_DATE=2026-07-10T17:25:32Z
RUN git clone --filter=blob:none https://github.com/github/github-mcp-server.git /src \
  && git -C /src checkout --detach "$GITHUB_MCP_COMMIT" \
  && CGO_ENABLED=0 go -C /src build -trimpath \
    -ldflags="-s -w -X main.version=${GITHUB_MCP_COMMIT} -X main.commit=${GITHUB_MCP_COMMIT} -X main.date=${GITHUB_MCP_COMMIT_DATE}" \
    -o /github-mcp-server ./cmd/github-mcp-server

FROM node:24-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash bats ca-certificates curl gh git jq python3 ripgrep shellcheck \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/agent-runtime
COPY package.json package-lock.json ./
RUN npm install --global npm@11.18.0 \
  && npm ci --omit=dev \
  && ln -s /opt/agent-runtime/node_modules/.bin/opencode /usr/local/bin/opencode

COPY --from=github-mcp-build /github-mcp-server /usr/local/bin/github-mcp-server
RUN github-mcp-server --version \
  && opencode --version

ENV OPENCODE_SDK_MODULE=/opt/agent-runtime/node_modules/@opencode-ai/sdk/dist/v2/index.js
WORKDIR /workspace
