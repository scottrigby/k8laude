# k8laude: Claude Code on Kubernetes

## Concept

k8laude packages Claude Code as a Kubernetes-native web application.
One Helm release = one Claude workspace instance with all needed tools,
UIs, and storage in a single namespace.

## Architecture

```
Browser (user)
    ↓ HTTPS (Ingress)
┌──────────────────────────────────────────────┐
│  Namespace: k8laude                          │
│                                              │
│  ┌────────────────┐  ┌────────────────────┐  │
│  │ code-server    │  │ Claude Code pod    │  │
│  │ (web IDE)      │  │ ├─ claude container│  │
│  │                │  │ └─ fluentbit sidecar│ │
│  └───────┬────────┘  └────────┬───────────┘  │
│          └────────┬───────────┘              │
│              PVC: workspace                  │
│                                              │
│  Subcharts: PostgreSQL, code-server,         │
│             Traefik, cert-manager            │
└──────────────────────────────────────────────┘
```

## Subcharts

| Chart | Purpose | BYO toggle |
|-------|---------|------------|
| PostgreSQL (Bitnami) | Debug log storage via Fluent Bit | `postgresql.enabled` |
| code-server (Coder) | Web IDE at namespace.domain | `code-server.enabled` |
| Traefik | Ingress + TLS termination | `traefik.enabled` |
| cert-manager | Let's Encrypt DNS01 certs | `cert-manager.enabled` |

## Key Decisions

- **Standalone PVC** — `<release>-workspace`, shared by Claude + code-server
- **Wildcard cert** — `*.k8laude.dev` covers namespace subdomains
- **Traefik IngressRoute** — for wildcard subdomain routing
- **CRDs pre-installed** — Helm subchart limitation, documented in setup
- **No iptables** — K8s NetworkPolicies planned for network isolation

## Follow-up

- ReadWriteMany storage (NFS Ganesha) for multi-node PVC sharing
- K8s NetworkPolicies for egress control
- Voice mode (PulseAudio bridge or browser WebRTC)
- Multi-agent: multiple Claude pods on shared workspace
