# CloudTTY: Thin web terminal (ttyd + kubectl + Node.js proxy)
#
# Build and load into Kind:
#   podman build -t localhost/k8laude-cloudtty -f chart/charts/cloudtty/Dockerfile .
#   podman save localhost/k8laude-cloudtty -o /tmp/k8laude-cloudtty.tar
#   kind load image-archive /tmp/k8laude-cloudtty.tar --name k8laude

FROM node:20-bookworm-slim

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    TTYD_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -sL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" && \
    chmod +x /usr/local/bin/ttyd && \
    curl -sL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x /usr/local/bin/kubectl && \
    apt-get remove -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /tmp
