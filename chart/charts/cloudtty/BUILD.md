# Building the CloudTTY Image

## Local Kind Cluster

```bash
cd /workspace/k8laude

# Build for local architecture
podman build -t localhost/k8laude-cloudtty -f chart/charts/cloudtty/Dockerfile .

# Load into Kind
podman save localhost/k8laude-cloudtty -o /tmp/k8laude-cloudtty.tar
kind load image-archive /tmp/k8laude-cloudtty.tar --name k8laude
```

## Push to GHCR (multi-arch)

```bash
# Authenticate with write:packages scope
gh auth login --scopes write:packages
gh auth token | podman login ghcr.io -u scottrigby --password-stdin

cd /workspace/k8laude

# k8laude-cloudtty
podman manifest rm ghcr.io/scottrigby/k8laude-cloudtty 2>/dev/null
podman build --platform linux/amd64,linux/arm64 \
  --manifest ghcr.io/scottrigby/k8laude-cloudtty \
  -f chart/charts/cloudtty/Dockerfile .
podman manifest push --all --rm ghcr.io/scottrigby/k8laude-cloudtty

# Make package public (UI only):
# https://github.com/users/scottrigby/packages/container/k8laude-cloudtty/settings
# → Change visibility → Public
```
