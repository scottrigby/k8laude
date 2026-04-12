# Installing on Kind (Local Development)

[< Back to docs](../README.md#documentation)

## Prerequisites

- [Kind](https://kind.sigs.k8s.io/)
- [Podman](https://podman.io/) (or Docker)
- [Helm](https://helm.sh/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## 1. Create Cluster

```bash
kind create cluster --name k8laude
```

## 2. Build and Load Images

```bash
cd k8laude

# Main image (Claude Code + healthcheck)
podman build -t localhost/k8laude .
podman save localhost/k8laude -o /tmp/k8laude.tar
kind load image-archive /tmp/k8laude.tar --name k8laude

# CloudTTY image (ttyd + kubectl web terminal)
podman build -t localhost/k8laude-cloudtty -f chart/charts/cloudtty/Dockerfile .
podman save localhost/k8laude-cloudtty -o /tmp/k8laude-cloudtty.tar
kind load image-archive /tmp/k8laude-cloudtty.tar --name k8laude
```

Note: Podman tags images as `localhost/<name>`. Set `pullPolicy: Never` in your values.

## 3. Install CRDs

Helm doesn't install subchart CRDs automatically:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.crds.yaml
helm dependency update ./chart
tar -xzf chart/charts/traefik-*.tgz -C /tmp/
kubectl apply -f /tmp/traefik/crds/
```

## 4. Set Up Authentication

Generate a long-lived OAuth token (requires Claude Pro/Max/Team/Enterprise):

```bash
claude setup-token
# Copy the token

kubectl create secret generic claude-token -n demo --from-literal=token=<TOKEN>
```

Or use an API key from console.anthropic.com (API-based billing):

```bash
kubectl create secret generic claude-api-key -n demo --from-literal=api-key=sk-ant-...
```

See [authentication.md](authentication.md) for details.

## 5. Install

```bash
helm install k8laude ./chart -n demo --create-namespace \
  -f custom-values.yaml \
  --set cloudtty.enabled=true \
  --set cloudtty.rbac.clusterAdmin=true \
  --set cloudtty.image.repository=localhost/k8laude-cloudtty \
  --set cloudtty.image.pullPolicy=Never \
  --set claude.oauthTokenSecret=claude-token
```

See [ingress.md](ingress.md) for TLS setup. Without ingress, use port-forwarding.

## 6. Access via Port-Forward

```bash
kubectl port-forward -n demo svc/k8laude-cloudtty 7681  # Web terminal
kubectl port-forward -n demo svc/k8laude-code-server 8080  # VS Code IDE
kubectl port-forward -n demo svc/k8laude 3000              # Landing page
```

| Service | URL |
|---------|-----|
| Web Terminal | http://127.0.0.1:7681/term/ |
| Web IDE | http://127.0.0.1:8080 (password: `k8laude`) |
| Landing Page | http://127.0.0.1:3000 |

## 7. Access via Ingress (optional)

With Traefik + TLS enabled (see [ingress.md](ingress.md)):

```bash
# Add hosts entries
echo "127.0.0.1 k8laude.dev demo.k8laude.dev" | sudo tee -a /etc/hosts

# Port-forward Traefik
kubectl port-forward -n demo svc/k8laude-traefik 8443:443
```

All services at one URL: `https://demo.k8laude.dev:8443/`

| Path | Service |
|------|---------|
| `/term/` | Web Terminal (Claude Code) |
| `/ide/` | Web IDE (code-server) |
| `/` | Landing page |

The `:8443` is because port-forwarding uses a non-privileged port. With `sudo kubectl port-forward ... 443:443` or a real LoadBalancer, the URLs are just `https://demo.k8laude.dev/term/`.

## Teardown

```bash
helm uninstall k8laude -n demo
kind delete cluster --name k8laude
```

---
See also: [Helm chart reference](helm-chart.md)
