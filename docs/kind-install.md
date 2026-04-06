# Installing on Kind (Local Development)

## Prerequisites

- [Kind](https://kind.sigs.k8s.io/)
- [Podman](https://podman.io/) (or Docker)
- [Helm](https://helm.sh/)
- For claudeman development: use the `k8s` profile — see
  [claudeman k8s profile docs](../../claudeman/profiles/k8s.md) for
  kubeconfig setup

## Build and Load Image

```bash
podman build -t k8laude:latest .
podman save k8laude:latest -o k8laude.tar
kind load image-archive ./k8laude.tar --name k8laude
```

Note: Podman tags images as `localhost/k8laude`. Set `image.repository=localhost/k8laude` and `image.pullPolicy=Never` in your values.

## Create Cluster and Install

```bash
kind create cluster --name k8laude

# Install CRDs (see docs/helm-chart.md#pre-requisites)

# Set DO PAT for TLS
read -s DO_PAT && echo "Token set (${#DO_PAT} chars)"

# Install with staging cert first
helm install k8laude ./chart -n k8laude --create-namespace \
  -f custom-values.yaml \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT" \
  --set ingress.tls.acme.staging=true

# Verify staging cert
kubectl get certificate -n k8laude  # READY=True

# Switch to production
kubectl delete certificate k8laude-tls -n k8laude
kubectl delete secret k8laude-tls k8laude-letsencrypt-key -n k8laude
helm upgrade k8laude ./chart -n k8laude \
  -f custom-values.yaml \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"
```

## Accessing Services

Kind doesn't expose ports externally. Use port-forward:

```bash
# HTTPS via Traefik
kubectl port-forward -n k8laude svc/k8laude-traefik 8443:443 &

# Add hosts entry
echo "127.0.0.1 k8laude.dev" | sudo tee -a /etc/hosts

# Verify
curl -k https://k8laude.dev:8443/healthz
```

| Service | Port-forward | URL |
|---------|-------------|-----|
| Health endpoint | `svc/k8laude-traefik 8443:443` | `https://k8laude.dev:8443/healthz` |
| Claude Code | `kubectl exec -it k8laude-0 -c claude -- claude` | N/A (CLI) |
| code-server | `svc/k8laude-code-server 8080:8080` | `http://localhost:8080` |

## Teardown

```bash
helm uninstall k8laude -n k8laude
kind delete cluster --name k8laude
```
