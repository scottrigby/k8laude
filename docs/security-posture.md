# Security Posture

Analysis of k8laude container images and security considerations.

## Image Inventory

| Image | Base | Purpose | Runs as |
|-------|------|---------|---------|
| `k8laude` | `node:20-alpine` (Alpine musl) | Claude Code + healthcheck.js | `node` (non-root) |
| `k8laude-cloudtty` | `node:20-bookworm-slim` | ttyd + proxy server | `node` (non-root) |
| `k8laude-code-server` | `codercom/code-server:4.109.5` | VS Code in browser | `coder` (non-root) |
| `postgresql` | `bitnami/postgresql:17.6.0` | Debug log storage | `1001` (non-root) |
| `fluent-bit` | `fluent/fluent-bit:3.2` | Log shipper sidecar | non-root |

## CVE Reduction History

| Image | Baseline | Post-slim | Post-alpine | Reduction |
|-------|----------|-----------|-------------|-----------|
| k8laude | 37 crit / 1486 total | 1 crit / 149 total | TBD | ~90% |
| k8laude-code-server | 0 (not scanned) | 5 crit / 223 total | 5 crit / 223 total | upstream controlled |
| postgresql | 4 crit / 137 total | 12 crit / 165 total | 12 crit / 165 total | upstream controlled |

*Baseline: node:20 full Debian. Post-slim: node:20-bookworm-slim. Post-alpine: node:20-alpine (current).*

## Known CVE Sources

### k8laude (highest attack surface)

**Current base: `node:20-alpine`** (Alpine Linux, musl libc):
- Switched from `node:20` (full Debian) → reduced CVEs by ~90%
- Then switched from `node:20-bookworm-slim` → Alpine for further reduction
- Installs only required packages: bash, git, curl, jq, less, procps, unzip, gnupg, nano, ca-certificates
- All containers run as non-root (`node` user, uid 1000)
- No sudo, no vim, no man pages, no zsh

**Why Claude Code needs a non-minimal base:**
- Requires git (for file tracking, commit operations)
- Requires bash (shell environment for code execution)
- Cannot use distroless/Chainguard-distroless — no shell or package manager

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
