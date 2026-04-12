# Quickstart

[< Back to docs](../README.md#documentation)

Get Claude Code running in your browser in 5 minutes.

## Prerequisites

- Kubernetes cluster (Kind, GKE, EKS, etc.)
- [Helm](https://helm.sh/)
- `claude` CLI installed locally (for `setup-token`)

## 1. Install

```bash
# Generate auth token
claude setup-token
# Copy the token

# Install k8laude with CloudTTY
helm install k8laude ./chart -n demo --create-namespace \
  --set cloudtty.enabled=true \
  --set cloudtty.rbac.clusterAdmin=true \
  --set claude.oauthToken=<YOUR_TOKEN>
```

## 2. Access

```bash
kubectl port-forward -n demo svc/k8laude-cloudtty 7681
```

Open http://127.0.0.1:7681/term/ — Claude Code is running in your browser.

## 3. Notifications

Click "all on" in the toolbar to enable browser notifications. When Claude completes a task or has a question, you'll get a desktop notification.

Enable notification hooks for unattended use:

```bash
helm upgrade k8laude ./chart -n demo \
  --set claude.hooks.questionDetection=true \
  --set claude.hooks.preciseTaskCompletion=true
```

## Next Steps

- [Authentication options](authentication.md)
- [Ingress and TLS](ingress.md)
- [Local Kind development](kind-install.md)
- [Architecture](../ARCHITECTURE.md)
