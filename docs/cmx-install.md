# Installing on CMX (Replicated Compatibility Matrix)

[< Back to docs](../README.md#documentation)

## Prerequisites

- Replicated Vendor Portal account with CMX credits
- `replicated` CLI (downloaded to `.claude/claudeman/bin/` or installed via brew)
- `REPLICATED_API_TOKEN` env var set
- k8laude multi-arch image pushed to GHCR (`ghcr.io/scottrigby/k8laude:latest`)
  ```bash
  # Build multi-arch (CMX uses amd64, local dev may be arm64)
  podman build --platform linux/amd64,linux/arm64 --manifest ghcr.io/scottrigby/k8laude .
  podman manifest push --all ghcr.io/scottrigby/k8laude
  ```

## Create CMX Cluster

```bash
replicated cluster create --distribution kind --version 1.33 \
  --instance-type r1.small --ttl 192h --name k8laude-cmx --app k8laude

# Watch it come up
replicated cluster ls --watch

# Get kubeconfig (auto-merges into KUBECONFIG)
replicated cluster kubeconfig k8laude-cmx
```

## Claudeman Access to CMX

CMX kubeconfigs use raw IPs. To access from inside claudeman:

1. Add the CMX cluster IP to your bootcamp profile's `extraDomains`
2. Run claudeman from local source (patched firewall handles raw IPs):
   ```bash
   read -s REPLICATED_API_TOKEN && echo "Replicated token set (${#REPLICATED_API_TOKEN} chars)"
   read -s GH_TOKEN && echo "GH token set (${#GH_TOKEN} chars)"

   ./claudeman/claudeman run --profile=bootcamp \
     --env KUBECONFIG=/workspace/.claude-config/kubeconfig \
     --env REPLICATED_API_TOKEN=$REPLICATED_API_TOKEN \
     --env GH_TOKEN=$GH_TOKEN \
     -- --continue
   ```

## Pre-install CRDs

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.crds.yaml
tar -xzf chart/charts/traefik-*.tgz -C /tmp/
kubectl apply -f /tmp/traefik/crds/
```

## Install

```bash
helm install k8laude ./chart -n k8laude --create-namespace
```

For TLS with Let's Encrypt:
```bash
read -s DO_PAT && echo "Token set (${#DO_PAT} chars)"
helm install k8laude ./chart -n k8laude --create-namespace \
  -f custom-values.yaml \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"
```

## Differences from Kind

| Concern | Kind | CMX |
|---------|------|-----|
| Image source | `kind load image-archive` | Pull from GHCR |
| Image pullPolicy | `Never` | `IfNotPresent` |
| External access | Port-forward only | Real external IP |
| DNS | `/etc/hosts` hack | Real DNS A record |
| TLS | Works but port 8443 | Standard port 443 |
| Cluster access from claudeman | `host.containers.internal` | Raw IP in `extraDomains` (patched firewall) |
