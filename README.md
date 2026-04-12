![k8laude](branding/bot/k8laude-horizontal-color.svg)

Claude Code on Kubernetes — a Helm chart that deploys Claude Code as a web-accessible development workspace.

## What you get

One Helm release per namespace:

- **Web Terminal** — Claude Code CLI in the browser via [CloudTTY](ARCHITECTURE.md#cloudtty-browser-terminal) (optional)
- **Web IDE** — VS Code in the browser via code-server (optional)
- **Landing Page** — health, status, links to terminal and IDE
- **Debug Logging** — Fluent Bit sidecar ships Claude debug logs to PostgreSQL (optional)
- **TLS** — Let's Encrypt wildcard cert via Traefik + cert-manager (optional)
- **Notifications** — desktop, toast, sound, TTS from Claude to your browser

All components share a single workspace PVC.

## Quick start

```bash
claude setup-token  # generate auth token, copy it

helm install k8laude ./chart -n demo --create-namespace \
  --set cloudtty.enabled=true \
  --set cloudtty.rbac.clusterAdmin=true \
  --set claude.oauthToken=<TOKEN>

kubectl port-forward -n demo svc/k8laude-cloudtty 7681
```

Open http://127.0.0.1:7681/term/

## Documentation

| Doc | Description |
|-----|-------------|
| [Quickstart](docs/quickstart.md) | Get running in 5 minutes |
| [Authentication](docs/authentication.md) | OAuth token, API key, plans |
| [Kind (local dev)](docs/kind-install.md) | Build images, install on Kind |
| [CMX (Replicated)](docs/cmx-install.md) | Install on Replicated CMX clusters |
| [Ingress and TLS](docs/ingress.md) | Traefik routing, Let's Encrypt, port-forwarding |
| [Helm chart](docs/helm-chart.md) | Subcharts, values reference |
| [Claude Code](docs/claude-code.md) | Using Claude Code in k8laude |
| [Web IDE](docs/code-server.md) | code-server setup and usage |
| [Architecture](ARCHITECTURE.md) | Design decisions and data flows |
| [Plan](PLAN.md) | Roadmap and task tracking |

## Chart structure

```
chart/
  Chart.yaml           # Dependencies
  values.yaml          # All defaults (with comments)
  templates/           # Main k8laude pod, services, ingress, TLS, hooks
  hooks/               # Notification hook fixture files (JSON)
  charts/
    cloudtty/          # Web terminal subchart
    code-server/       # VS Code subchart
    *.tgz              # Vendored upstream subcharts
```
