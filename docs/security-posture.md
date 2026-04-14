# Security Posture

Analysis of k8laude container images and security considerations.

## Image Inventory

| Image | Base | Purpose | Runs as |
|-------|------|---------|---------|
| `k8laude` | `node:20` (Debian Bookworm) | Claude Code + healthcheck.js | `node` (non-root) |
| `k8laude-cloudtty` | `node:20-bookworm-slim` | ttyd + proxy server | `node` (non-root) |
| `k8laude-code-server` | `codercom/code-server:4.109.5` | VS Code in browser | `coder` (non-root) |
| `postgresql` | `bitnami/postgresql:17.6.0` | Debug log storage | `1001` (non-root) |
| `fluent-bit` | `fluent/fluent-bit:3.2` | Log shipper sidecar | non-root |

## Known CVE Sources

### k8laude (highest attack surface)

**Base image `node:20`** (full Debian Bookworm):
- Includes development tools: git, vim, nano, zsh, man-db, procps, sudo, gnupg2
- These are intentional — Claude Code needs git and a shell environment to function
- Full Debian base has more CVEs than slim/alpine variants

**Mitigation options:**
- Switch to `node:20-bookworm-slim` and install only required packages
- Use Chainguard or Replicated securebuild images for reduced CVE surface
- Remove `sudo` (not needed at runtime, was for devcontainer compatibility)
- Remove `vim`, `nano`, `man-db` (convenience tools, not required)

### k8laude-cloudtty (moderate)

**Base image `node:20-bookworm-slim`**:
- Already using slim variant
- Includes ttyd binary (C, statically linked) and kubectl
- kubectl adds Go stdlib CVEs but is required for functionality

### k8laude-code-server (moderate)

**Base image `codercom/code-server:4.109.5`**:
- Upstream maintained image, CVEs depend on upstream patching
- Custom layer only adds `chmod` for workbench modification

### Third-party images (low control)

- **PostgreSQL**: Bitnami-maintained, well-patched
- **Fluent Bit**: Official image, regularly updated
- **cert-manager, Traefik**: Upstream maintained subcharts

## Recommendations

### Immediate (low effort)
1. Pin all image tags to digests in production (not `:latest`)
2. Remove `sudo` package from k8laude Dockerfile (runtime doesn't need it)
3. Remove `vim`, `nano`, `man-db` (users access files via code-server, not shell editors)

### Medium-term
1. Switch k8laude base to `node:20-bookworm-slim` + explicit package installs
2. Use Replicated securebuild base images if available for Node.js
3. Add image scanning to CI pipeline (trivy, grype)
4. Set `readOnlyRootFilesystem: true` where possible in pod security contexts

### Container runtime security
- All containers run as non-root users
- No privileged containers
- No host networking or host PID
- Network access controlled via Kubernetes NetworkPolicies (not iptables)
- Secrets mounted as environment variables, not files (except credentials)

## Image Signing (Tier 7.3)

To sign images with cosign:
```bash
# Generate key pair (once)
cosign generate-key-pair

# Sign after each CI build
cosign sign --key cosign.key ghcr.io/scottrigby/k8laude:$VERSION

# Verify
cosign verify --key cosign.pub ghcr.io/scottrigby/k8laude:$VERSION
```

Integration with CI: add cosign sign step after `docker/build-push-action` in `.github/workflows/release.yaml`.
