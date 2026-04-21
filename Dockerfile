FROM node:20-bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/scottrigby/k8laude

ARG TZ=UTC
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install required tools only (slim base for reduced CVE surface)
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  unzip \
  gnupg2 \
  jq \
  curl \
  ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

ENV DEVCONTAINER=true

# Create workspace and config directories
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

# Install kubectl and support-bundle plugin (for support bundle generation via UI)
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl && \
  curl -fsSL "https://github.com/replicatedhq/troubleshoot/releases/latest/download/support-bundle_linux_${ARCH}.tar.gz" \
    | tar xzf - -C /usr/local/bin support-bundle && chmod +x /usr/local/bin/support-bundle

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
