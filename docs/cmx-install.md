# Installing on CMX (Replicated Compatibility Matrix)

> TODO: This is planned for Tier 1+. See [CMX docs](https://docs.replicated.com/vendor/testing-about).

## Overview

CMX provides on-demand Kubernetes clusters for testing Replicated applications.
Unlike Kind, CMX clusters have real external IPs and can serve HTTPS directly.

## Prerequisites

- Replicated Vendor Portal account with CMX credits
- `replicated` CLI installed
- Application created in Vendor Portal

## Planned Steps

1. Create CMX cluster via Vendor Portal or CLI:
   ```bash
   replicated cluster create --distribution eks --version 1.31 \
     --instance-type r1.medium --disk 100
   ```

2. Get kubeconfig:
   ```bash
   replicated cluster kubeconfig --id <cluster-id> > kubeconfig.yaml
   export KUBECONFIG=kubeconfig.yaml
   ```

3. Push images to Replicated registry (Tier 1 CI pipeline)

4. Install CRDs + Helm chart (same as local, but with registry images)

5. Point DNS A record for `k8laude.dev` to cluster's external IP

6. Cert-manager provisions real Let's Encrypt cert via DNS01

## Differences from Kind

| Concern | Kind | CMX |
|---------|------|-----|
| Image loading | `kind load image-archive` | Push to registry |
| External access | Port-forward only | Real external IP |
| DNS | `/etc/hosts` hack | Real DNS A record |
| TLS | Works but port 8443 | Standard port 443 |
| Storage | Local provisioner | Cloud-backed PVCs |
