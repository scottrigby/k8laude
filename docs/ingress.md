# Ingress and TLS

[< Back to docs](../README.md#documentation)

k8laude uses Traefik for ingress routing and cert-manager for TLS certificates.

## How Routing Works

With ingress enabled, all services are accessible through a single domain using path-based routing:

| Path | Service | Description |
|------|---------|-------------|
| `/` | k8laude-0 | Landing page, health API |
| `/term/` | k8laude-cloudtty | Browser terminal (Claude Code) |
| `/ide/` | k8laude-code-server | VS Code IDE |

The domain uses namespace subdomains: `<namespace>.k8laude.dev`. For example, `demo.k8laude.dev/term/`.

## Enabling Ingress

```yaml
# values.yaml
ingress:
  enabled: true
  host: k8laude.dev
  tls:
    mode: auto  # or selfsigned, manual
    acme:
      email: you@example.com
```

CloudTTY also needs its own ingress:

```yaml
cloudtty:
  enabled: true
  ingress:
    enabled: true
    subdomain: demo.k8laude.dev  # must match namespace.host
```

## TLS Modes

### `auto` — Let's Encrypt via DNS-01 (DigitalOcean)

```bash
helm install k8laude ./chart -n demo \
  --set ingress.enabled=true \
  --set ingress.host=k8laude.dev \
  --set ingress.tls.mode=auto \
  --set ingress.tls.acme.email=you@example.com \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"
```

Issues a wildcard cert (`*.k8laude.dev`) via DNS-01 challenge. Works even without public HTTP access (good for local Kind clusters).

**Tip**: Use `--set ingress.tls.acme.staging=true` first to test with Let's Encrypt staging. Switch to production after verifying:

```bash
kubectl get certificate -n demo  # Wait for READY=True
kubectl delete certificate k8laude-tls -n demo
kubectl delete secret k8laude-tls k8laude-letsencrypt-key -n demo
helm upgrade k8laude ./chart -n demo ... # without staging flag
```

### `selfsigned` — Self-signed certificate

```bash
helm install k8laude ./chart -n demo \
  --set ingress.enabled=true \
  --set ingress.tls.mode=selfsigned
```

Browser will show a security warning. Accept to proceed.

### `manual` — Bring your own TLS secret

```bash
kubectl create secret tls k8laude-tls -n demo \
  --cert=tls.crt --key=tls.key

helm install k8laude ./chart -n demo \
  --set ingress.enabled=true \
  --set ingress.tls.mode=manual
```

## Local Kind Access

Kind doesn't expose a LoadBalancer IP. Use port-forwarding to Traefik:

```bash
# Non-privileged port (requires :8443 in URLs)
kubectl port-forward -n demo svc/k8laude-traefik 8443:443

# Privileged port (clean URLs, needs sudo)
sudo kubectl port-forward -n demo svc/k8laude-traefik 443:443
```

Add `/etc/hosts` entries:

```bash
echo "127.0.0.1 k8laude.dev demo.k8laude.dev" | sudo tee -a /etc/hosts
```

Then access: `https://demo.k8laude.dev:8443/term/` (or `https://demo.k8laude.dev/term/` with sudo).

## Without Ingress (port-forward only)

When `ingress.enabled=false`, each service is accessed via separate port-forwards:

```bash
kubectl port-forward -n demo svc/k8laude-cloudtty 7681  # http://127.0.0.1:7681/term/
kubectl port-forward -n demo svc/k8laude-code-server 8080  # http://127.0.0.1:8080
kubectl port-forward -n demo svc/k8laude 3000              # http://127.0.0.1:3000
```

The landing page shows port-forward commands. With ingress enabled, set `landingPage.terminalUrl=/term/` and `landingPage.ideUrl=/ide/` for clean links.

---
See also: [Helm chart reference](helm-chart.md)
