# Plan

## Done

- [x] Browser terminal via ttyd + Node.js proxy (kubectl exec into k8laude-0)
- [x] Per-session notification routing (ttyd `--url-arg` + SSE scoping)
- [x] Service Worker desktop notifications with correct tab targeting
- [x] Notification channels: toast, desktop, sound, TTS (user-selectable checkboxes)
- [x] Auth via `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`
- [x] `hasCompletedOnboarding` auto-set/removed for OAuth token interactive mode
- [x] Shared workspace PVC across Claude pod, cloudtty, and code-server
- [x] CloudTTY as a Helm subchart (`cloudtty.enabled=false` by default)
- [x] Custom Docker images: k8laude-cloudtty (ttyd + kubectl), k8laude-code-server (writable workbench)
- [x] Configurable command (`cloudtty.command` helm value)
- [x] code-server: hidden files, dark theme, clean UI, app-name branding
- [x] Notification hooks with fixture-based add/remove (4 built-in hooks)
- [x] Plugin management with fixture-based add/remove (askQuestions built-in)
- [x] IDE banner injection (innerHeight override + cat-based HTML injection)
- [x] Breadcrumb navigation across all pages (Home, Terminal, IDE)
- [x] k8laude icon in all banners (K8s shield + Claude asterisk)
- [x] Landing page: dark theme, configurable links, port 3000
- [x] Shift+Enter keybinding for multi-line input (xterm.js CSI u injection)
- [x] Basic auth for cloudtty (ttyd --credential)
- [x] Branding: logos (asterisk + bot variants), icon/horizontal/stacked layouts
- [x] GHCR image push (k8laude, k8laude-cloudtty, k8laude-code-server)
- [x] CI: GH Action builds all three multi-arch images
- [x] Traefik ingress routing for all services (tested on Kind with TLS)
- [x] CMX deployment verified with Replicated image proxy
- [x] Configmap checksum annotations for auto-restart on changes
- [x] imagePullSecrets support for Replicated proxy

## To do

- [ ] Eliminate iframe: inject toolbar + SSE + SW directly into ttyd HTML ([detailed plan](docs/iframe-elimination.md))
- [ ] Fix Shift+Enter newline when text is present (only works with empty input)
- [ ] OAuth2 proxy for all web services (Traefik ForwardAuth + oauth2-proxy)
- [ ] Helm chart tests (`helm test`) for hooks, plugins, auth, notifications
- [ ] Voice mode via browser (getUserMedia → AudioWorklet → WebSocket → PulseAudio pipe source)
- [ ] Investigate `claude --chrome` flag interaction with cloudtty
- [ ] IDE banner injection (VS Code extensions can't inject into the workbench UI — options: fork Traefik rewritebody plugin with Content-Type fix, or proxy in front of code-server like ttyd)
- [ ] ReadWriteMany storage for multi-node PVC sharing
- [ ] K8s NetworkPolicies for egress control
- [ ] Devcontainer-style features for k8s — investigate: sidecar containers with tools mounted into Claude pod PATH (like claudeman profiles), operator with CRD declarations, or reuse devcontainer.json spec. See: DevPod (Loft Labs), Envbuilder (Coder), OpenShift Dev Spaces for prior art.
- [ ] Multi-agent: multiple Claude pods on shared workspace
- [ ] KOTS config screen: networking/access section — Access Method (port-forward, NodePort, custom domain), landing page URLs, ingress toggle, TLS mode (self-signed, Let's Encrypt staging→prod, manual), domain config. Currently EC installs hardcode ingress disabled.
- [ ] Remove `ImagePullSecretName` from HelmChart CR — returns `k8laude-registry` which doesn't exist. `enterprise-pull-secret` handles all pulls.
# 2026-04-16T20:32:26Z
