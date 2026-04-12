# Authentication

[< Back to docs](../README.md#documentation)

Claude Code supports multiple authentication methods. See the [official docs](https://code.claude.com/docs/en/authentication) for full details.

## Methods (in precedence order)

| Method | Env Var | Billing | Plan Required |
|--------|---------|---------|---------------|
| OAuth token | `CLAUDE_CODE_OAUTH_TOKEN` | Subscription | Pro, Max, Team, Enterprise |
| API key | `ANTHROPIC_API_KEY` | API pay-per-use | Any Console account |

## Option A: OAuth Token (recommended)

Uses your Claude subscription. One-year token, no browser auth needed.

```bash
# Generate token (run locally, one-time)
claude setup-token

# Deploy (Helm creates and manages the secret)
helm install k8laude ./chart -n demo --create-namespace \
  --set claude.oauthToken=<TOKEN>
```

To manage the secret yourself instead:

```bash
kubectl create secret generic claude-token -n demo --from-literal=token=<TOKEN>
helm install k8laude ./chart -n demo \
  --set claude.oauthTokenSecret=claude-token
```

The chart automatically sets `hasCompletedOnboarding: true` in Claude's config when an OAuth token is configured (required for interactive mode). When the token is removed, this flag is also removed.

## Option B: API Key

From console.anthropic.com. Pay-per-use, no subscription required.

```bash
# Deploy (Helm creates and manages the secret)
helm install k8laude ./chart -n demo --create-namespace \
  --set claude.apiKey=sk-ant-...
```

To manage the secret yourself instead:

```bash
kubectl create secret generic claude-api-key -n demo --from-literal=api-key=sk-ant-...
helm install k8laude ./chart -n demo \
  --set claude.apiKeySecret=claude-api-key
```

In interactive mode, Claude prompts once to approve the key (choice is remembered).

## Security Warning

When `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` is configured, anyone with terminal access to the k8laude-0 pod can extract the credentials:

```bash
echo $CLAUDE_CODE_OAUTH_TOKEN
echo $ANTHROPIC_API_KEY
```

**This means the CloudTTY web terminal must be protected by authentication.** Without it, anyone who can reach the URL can use your Claude credits and extract your token.

Current protection options:
- **ttyd basic auth** — `cloudtty.auth.password` value (browser login prompt)
- **Traefik basic auth middleware** — proxy-level auth
- **Network isolation** — restrict access via NetworkPolicies or private ingress

**Do not expose CloudTTY on a public URL without authentication.** This setup is designed for trusted environments (development, internal teams) where the terminal operator and end user are the same person. It is NOT suitable for multi-tenant SaaS where application operators and end users are different.

## Web Terminal Auth

The CloudTTY web terminal should always be protected. Set a password to enable basic auth:

```bash
helm install k8laude ./chart -n demo \
  --set cloudtty.enabled=true \
  --set cloudtty.auth.password=k8laude
```

This adds a browser login prompt (username: `k8laude`, password: your value). The same password can be used for both CloudTTY and code-server for simplicity:

```yaml
cloudtty:
  auth:
    password: k8laude
code-server:
  password: k8laude
```

**Limitations of basic auth**: The browser caches credentials per-origin until all tabs close. There is no logout button — closing all browser windows clears the session. For proper session management with logout, see the [OAuth2 proxy plan item](../PLAN.md).

## Without Pre-configured Auth

If no token or API key is provided, Claude falls back to the interactive `/login` browser flow. In k8s this requires manually completing auth — not recommended for unattended use.

---
See also: [Helm chart reference](helm-chart.md)
