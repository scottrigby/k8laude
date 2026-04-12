# Helm Chart

[< Back to docs](../README.md#documentation)

## Subcharts

| Chart | Purpose | Enable/disable | Default |
|-------|---------|----------------|---------|
| cloudtty | Browser terminal (Claude Code via ttyd) | `cloudtty.enabled` | `false` |
| code-server (Coder) | Web IDE (VS Code in browser) | `code-server.enabled` | `true` |
| postgresql (Bitnami) | Debug log storage via Fluent Bit | `postgresql.enabled` | `true` |
| traefik | Ingress controller + TLS termination | `traefik.enabled` | `true` |
| cert-manager | TLS certificate management | `cert-manager.enabled` | `true` |
| replicated | Replicated SDK (license, metrics, updates) | `replicated.enabled` | `false` |

All subcharts can be disabled for BYO alternatives.

## Prerequisites

Helm doesn't install CRDs from subcharts. Install before `helm install`:

```bash
# cert-manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.crds.yaml

# Traefik CRDs (extract from downloaded chart)
helm dependency update ./chart
tar -xzf chart/charts/traefik-*.tgz -C /tmp/
kubectl apply -f /tmp/traefik/crds/
```

## Install

```bash
helm install k8laude ./chart -n demo --create-namespace \
  -f custom-values.yaml
```

See [quickstart](quickstart.md) for a minimal install, or [kind-install](kind-install.md) for local development.

## Authentication Values

See [authentication.md](authentication.md) for full details.

```yaml
claude:
  # Option A: OAuth token (subscription billing) — Helm manages the secret
  oauthToken: ""
  # Or reference your own secret:
  oauthTokenSecret: ""

  # Option B: API key (API-based billing) — Helm manages the secret
  apiKey: ""
  # Or reference your own secret:
  apiKeySecret: ""
```

## CloudTTY Values

```yaml
cloudtty:
  enabled: true
  image:
    repository: ghcr.io/scottrigby/k8laude-cloudtty
    tag: latest
  command: "claude --dangerously-skip-permissions"
  shiftEnterNewline: true  # Shift+Enter for multi-line input
  rbac:
    clusterAdmin: true     # needed for kubectl exec into k8laude-0
  ingress:
    enabled: true
    subdomain: demo.k8laude.dev  # namespace.host
```

## Notification Hook Values

See [examples/hooks-values.yaml](../examples/hooks-values.yaml) for descriptions.

```yaml
claude:
  hooks:
    preciseTaskCompletion: false  # TaskCompleted hook
    untrackedCompletion: false    # Stop hook (keyword filter)
    questionDetection: false      # PreToolUse (AskUserQuestion)
    idlePrompt: false             # Notification (idle_prompt)
  customHooks: {}                 # Additional user-defined hooks (add-only)
```

Hooks are added to Claude's `settings.json` when `true`, removed by verbatim fixture match when `false`. User-defined hooks are never touched.

## Ingress and TLS Values

See [ingress.md](ingress.md) for full details including staging → production TLS workflow.

```yaml
ingress:
  enabled: true
  host: k8laude.dev
  tls:
    mode: auto          # auto | selfsigned | manual
    acme:
      email: you@example.com
      staging: false    # true for Let's Encrypt staging
      digitalocean:
        accessToken: "" # pass via --set, never in files
```

### TLS Staging → Production Workflow

Test with staging first (higher rate limits, not browser-trusted):

```bash
helm install k8laude ./chart -n demo --create-namespace \
  -f custom-values.yaml \
  --set ingress.tls.acme.staging=true \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"

# Wait for cert
kubectl get certificate -n demo  # READY=True
```

Switch to production:

```bash
# Delete staging cert resources
kubectl delete certificate k8laude-tls -n demo
kubectl delete secret k8laude-tls k8laude-letsencrypt-key -n demo

# Upgrade without staging flag
helm upgrade k8laude ./chart -n demo \
  -f custom-values.yaml \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"

# Verify production cert
kubectl get certificate -n demo  # READY=True
```

## Landing Page Values

```yaml
landingPage:
  terminalUrl: ""  # /term/ (behind ingress) or http://127.0.0.1:7681/term/ (port-forward)
  ideUrl: ""       # /ide/ (behind ingress) or http://127.0.0.1:8080 (port-forward)
```

When empty, the landing page shows `kubectl port-forward` commands with localhost URLs.

## Key Image Values

```yaml
image:
  repository: ghcr.io/scottrigby/k8laude  # or localhost/k8laude for Kind
  tag: latest
  pullPolicy: IfNotPresent                 # Never for Kind local images
```

## All Subcharts Quick Reference

```yaml
postgresql:
  enabled: true
  auth:
    username: k8laude
    password: k8laude
    database: k8laude

code-server:
  enabled: true
  password: k8laude
  persistence:
    existingClaim: workspace  # shared PVC

traefik:
  enabled: true

cert-manager:
  enabled: true

replicated:
  enabled: false
```
