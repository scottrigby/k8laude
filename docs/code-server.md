# Using the Web IDE (code-server)

## Access

### Via port-forward (Kind)

```bash
kubectl port-forward -n k8laude svc/k8laude-code-server 8080:8080
# Open http://localhost:8080
# Password: k8laude
```

### Via Ingress

code-server is served at `<namespace>.<domain>` using the wildcard cert:

```
https://k8laude.k8laude.dev    (namespace=k8laude, domain=k8laude.dev)
```

For Kind, add the hosts entry and port-forward:

```bash
echo "127.0.0.1 k8laude.k8laude.dev" | sudo tee -a /etc/hosts
kubectl port-forward -n k8laude svc/k8laude-traefik 8443:443 &
# Open https://k8laude.k8laude.dev:8443
```

## Shared Workspace

code-server mounts the same PVC as the Claude Code pod at `/workspace`.
Files created by Claude are immediately visible in the IDE and vice versa.

Note: On Kind (single node), both pods share the RWO PVC since they're
on the same node. For multi-node clusters, this requires RWX storage
(see PLAN.md follow-up phases).

## Password

Default password is `k8laude`, set via `code-server.password` in values.yaml.
