# Using Claude Code

[< Back to docs](../README.md#documentation)

## Quick Start

```bash
kubectl exec -it -n k8laude k8laude-0 -c claude -- claude --dangerously-skip-permissions
```

Add `--debug --verbose` to enable debug logging (shipped to PostgreSQL via Fluent Bit sidecar).

## Workspace

Files are stored on a PersistentVolumeClaim at `/workspace`. Data survives pod restarts.

```bash
# Run a file created by Claude
kubectl exec -n k8laude k8laude-0 -c claude -- node hello.js

# List workspace contents
kubectl exec -n k8laude k8laude-0 -c claude -- ls /workspace
```

## Debug Logs

When running with `--debug --verbose`, logs are written to `/workspace/.claude-debug/claude-debug.txt` and automatically shipped to PostgreSQL by the Fluent Bit sidecar.

```bash
# Count log lines
kubectl exec -n k8laude k8laude-0 -c claude -- wc -l /workspace/.claude-debug/claude-debug.txt

# Query logs in PostgreSQL
kubectl exec -n k8laude k8laude-postgresql-0 -- env PGPASSWORD=k8laude \
  psql -U k8laude -d k8laude -c "SELECT count(*) FROM claude_logs;"

# View recent entries
kubectl exec -n k8laude k8laude-postgresql-0 -- env PGPASSWORD=k8laude \
  psql -U k8laude -d k8laude -c "SELECT tag, data FROM claude_logs ORDER BY timestamp DESC LIMIT 5;"
```

## Authentication

Claude Code requires authentication. Options:

1. **Run `/login` inside the pod** — triggers OAuth flow (requires browser access)
2. **Pre-populate credentials** — create a Secret with `.credentials.json` and set `claude.credentialsSecret` in values
