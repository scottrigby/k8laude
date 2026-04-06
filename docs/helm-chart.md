# Helm Chart

## Subcharts

| Chart | Purpose | BYO toggle |
|-------|---------|------------|
| postgresql (Bitnami) | Debug log storage | `postgresql.enabled=false` + `externalDatabase.*` |
| code-server (Coder) | Web IDE | `code-server.enabled=false` |
| traefik | Ingress controller | `traefik.enabled=false` |
| cert-manager | TLS certificates | `cert-manager.enabled=false` |

## Pre-requisites

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
helm install k8laude ./chart -n k8laude --create-namespace \
  -f custom-values.yaml \
  --set ingress.tls.acme.digitalocean.accessToken="$DO_PAT"
```

## TLS Modes

| Mode | Description |
|------|-------------|
| `selfsigned` | cert-manager self-signed (default) |
| `auto` | Let's Encrypt via DNS01 (DigitalOcean) |
| `manual` | User-provided TLS secret |

Set `ingress.tls.acme.staging=true` for Let's Encrypt staging (higher rate limits).

## Key Values

```yaml
image:
  repository: localhost/k8laude  # or your registry
  pullPolicy: Never              # IfNotPresent for registry

ingress:
  host: k8laude.dev
  tls:
    mode: auto
    acme:
      email: you@example.com
      staging: false
      digitalocean:
        accessToken: ""  # pass via --set, never in files

postgresql:
  enabled: true  # false for BYO (RDS, CloudSQL, etc.)

code-server:
  enabled: true
  password: k8laude
```
