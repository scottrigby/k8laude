# Architecture

k8laude packages Claude Code as a Kubernetes-native web application. One Helm release = one Claude workspace with terminal, IDE, and storage in a single namespace.

## Overview

```
Browser
  ├─ /term/  → CloudTTY (interactive Claude Code CLI)
  ├─ /ide/   → code-server (VS Code editor)
  └─ /       → Landing page (health, status, links)
       ↓ HTTPS (Traefik IngressRoute) or port-forward
┌──────────────────────────────────────────────────────────────┐
│  Namespace                                                   │
│                                                              │
│  ┌─ k8laude-cloudtty (Deployment) ────────────────────────┐ │
│  │  Image: k8laude-cloudtty (node + ttyd + claude-code)   │ │
│  │  Node.js proxy (:7681) → ttyd (:7682) → Claude Code   │ │
│  │  Auth: CLAUDE_CODE_OAUTH_TOKEN env var                 │ │
│  │  Notifications: notify cmd → SSE → browser             │ │
│  └──────────────────────┬─────────────────────────────────┘ │
│                         │                                    │
│                    workspace PVC ← shared filesystem         │
│                         │                                    │
│  ┌─ k8laude-0 (SS) ────┤   ┌─ code-server ───────┤        │
│  │  Image: k8laude      │   │  VS Code browser IDE │        │
│  │  Landing page (:3000)│   └─────────────────────┘         │
│  │  Health/license API  │                                    │
│  │  Fluentbit sidecar ──┼──→ postgresql (debug logs)        │
│  └──────────────────────┘                                    │
│                                                              │
│  Note: k8laude-0 and k8laude-cloudtty are independent pods. │
│  They share the workspace PVC but do NOT communicate         │
│  directly. Each has its own Claude Code installation.        │
└──────────────────────────────────────────────────────────────┘
```

## CloudTTY: Browser Terminal

### Why a custom subchart instead of the CloudTTY operator?

The [CloudTTY project](https://github.com/cloudtty/cloudtty) provides a Kubernetes operator that creates web terminal pods via a `CloudShell` CRD. We evaluated it and built our own subchart instead because:

- **The operator adds complexity** — a controller pod, CRD installation, and worker pool management. We just need one terminal pod per namespace.
- **We need a custom proxy** — the notification system (SSE, Service Worker, per-session routing) requires a Node.js proxy in front of ttyd. The operator's stock cloudshell image doesn't support this.
- **kubectl exec architecture** — our terminal execs into the existing Claude pod rather than running Claude directly. The operator creates standalone pods, not exec bridges.
- **Helm-native** — a subchart with `condition: cloudtty.enabled` integrates cleanly with the parent chart. An operator would be a separate deployment with its own lifecycle.

We borrowed the name and concept (web terminal via ttyd in k8s) but the implementation is purpose-built for Claude Code.

### Why a proxy server in front of ttyd?

The primary reason: we needed a custom wrapper page with a toolbar (notification checkboxes, connection status, reconnect button), SSE client for real-time notifications, and Service Worker registration for desktop notifications. ttyd serves its own HTML and has no plugin or extension mechanism — you can't add UI elements or JavaScript to its page without modifying the source.

The proxy wraps ttyd by serving our custom HTML at `/term/` (which embeds ttyd in an iframe) and reverse-proxying all ttyd traffic (including WebSocket upgrades). It also:
- Injects the Shift+Enter keybinding script into ttyd's HTML response
- Serves the Service Worker at `/term/sw.js`
- Hosts the notification API (`/term/api/notify`, `/term/api/events`)
- Strips `accept-encoding` to enable HTML injection without decompression

### Proxy server routes

```
Proxy (Node.js, :7681)
  ├── GET  /term/           → HTML wrapper (toolbar + iframe)
  ├── GET  /term/sw.js      → Service Worker for desktop notifications
  ├── GET  /term/ttyd/*     → reverse proxy to ttyd (:7682)
  ├── WS   /term/ttyd/ws    → WebSocket proxy to ttyd (must forward query params)
  ├── POST /term/api/notify → receive notification, route to matching SSE session
  ├── GET  /term/api/events → SSE stream (scoped by ?sessionId)
  └── GET  /term/api/health → health check
```

### Per-session notification routing

Each browser tab gets its own notification channel via ttyd's `--url-arg` flag:

1. Wrapper page generates `SESSION_ID = crypto.randomUUID()` (stored in `sessionStorage`)
2. iframe connects to `ttyd/?arg=SESSION_ID`
3. ttyd passes the arg to the entry script as `$1` → exported as `CLOUDTTY_SESSION`
4. The `notify` command includes `$CLOUDTTY_SESSION` in its POST to the proxy
5. SSE connects with `?sessionId=SESSION_ID`
6. Proxy maintains `Map<sessionId, Set<response>>` and routes to the matching client only

**Why this matters**: Without per-session routing, all browser tabs connected to the same pod receive all notifications, causing duplicates and non-deterministic tab focusing.

**Critical implementation detail**: The WebSocket proxy must forward `url.search` (query parameters) to ttyd, not just the pathname. Without this, ttyd's `--url-arg` silently fails — the session starts but `$1` is empty.

### Notification channels

The wrapper page toolbar has four independently toggleable checkboxes (persisted in `localStorage`):

| Channel | API | Notes |
|---------|-----|-------|
| Toast | DOM overlay | Default on. In-page, bottom-right corner. |
| Desktop | Service Worker `showNotification()` | Requires browser + macOS permission. Action buttons: View/Dismiss. |
| Sound | `AudioContext` (two-tone sine wave) | |
| TTS | `speechSynthesis.speak()` | Prefixes message with type ("Complete: ...") |

**Why Service Worker instead of `new Notification()`?** Direct `Notification` objects from the main page don't reliably target the creating tab when multiple tabs exist. The SW's `notificationclick` handler uses `clients.matchAll()` + `client.focus()` for deterministic tab targeting.

**Why do Service Workers work on HTTP?** `localhost` and `127.0.0.1` are treated as secure contexts by browsers per the [W3C Secure Contexts spec](https://www.w3.org/TR/secure-contexts/).

### Configurable command

The command ttyd runs is a helm value: `cloudtty.command` (default: `claude --dangerously-skip-permissions`). The full command string is exposed rather than individual flags because Claude Code evolves quickly and our chart shouldn't lag behind new flags.

### Shift+Enter keybinding

Claude Code supports Shift+Enter for multi-line input, but requires the terminal to send a distinct CSI u escape sequence (`\x1b[13;2u`) instead of a plain carriage return. Native terminals each need their own configuration (iTerm2, Ghostty, Kitty, etc. — see [terminal config docs](https://code.claude.com/docs/en/terminal-config)).

CloudTTY bypasses all of this. The proxy intercepts ttyd's HTML response and injects a script that attaches a custom key handler to xterm.js:

```javascript
window.term.attachCustomKeyEventHandler(e => {
  if (e.key === 'Enter' && e.shiftKey && e.type === 'keydown') {
    window.term.input('\x1b[13;2u');
    return false;
  }
  return true;
});
```

Since the terminal is xterm.js in the browser (not a native terminal emulator), this works identically on macOS, Linux, and Windows — no per-terminal or per-OS configuration needed. The browser always reports `shiftKey: true` regardless of platform.

Configurable via `cloudtty.shiftEnterNewline` (default: `true`). Disable for non-Claude commands.

### Notification hooks

Claude Code supports [hooks](https://code.claude.com/docs/en/hooks) — shell commands triggered by lifecycle events. We use four notification hooks, matching the [claudeman hook strategy](https://github.com/scottrigby/claudeman/blob/main/ARCHITECTURE.md#notifications):

| Hook | Event | Purpose |
|------|-------|---------|
| `TaskCompleted` | Task marked complete | Precise completion signal for tracked work |
| `Stop` | Every response turn | Catches untracked completions via keyword filter |
| `PreToolUse` (AskUserQuestion) | Claude asks a question | Immediate question detection |
| `Notification` (idle_prompt) | Claude waiting for input | Idle detection (~25% reliability) |

Each hook calls the `notify` command which posts to the cloudtty proxy's SSE endpoint, delivering browser notifications to the correct tab.

**Why helm values instead of hardcoding?** Different teams have different notification needs. Some want all hooks (unattended agents), others want only question detection (interactive use). The `claude.hooks.*` values let operators configure this per-release. Custom hooks are supported via `claude.customHooks`.

**Why merge instead of overwrite?** Users may have their own hooks in `settings.json`. The postStart script deduplicates by comparing JSON-serialized hook definitions before inserting.

### Entry script pattern

The ttyd command runs `/tmp/cloudtty-entry.sh` (created by `start.sh` via heredoc) rather than inline `bash -c '...'`. This avoids quoting issues when shell commands are embedded in YAML configmaps that are then passed as arguments to ttyd.

## Authentication

Browser-based OAuth doesn't work in k8s: PKCE binds the auth code to the original `redirect_uri`, so rewriting the port causes a 400 during token exchange. The browser can't listen on TCP ports, so claudeman's host-side proxy approach can't be replicated.

**Solution**: Pre-configured auth via environment variables. Two options matching Claude Code's [auth precedence](https://code.claude.com/docs/en/authentication):

| Method | Env var | Billing | Plan required |
|--------|---------|---------|---------------|
| OAuth token (`claude setup-token`) | `CLAUDE_CODE_OAUTH_TOKEN` | Subscription | Pro, Max, Team, Enterprise |
| API key (console.anthropic.com) | `ANTHROPIC_API_KEY` | API pay-per-use | Any Console account |

**Key detail**: `CLAUDE_CODE_OAUTH_TOKEN` requires `hasCompletedOnboarding: true` in `.claude.json` to work in interactive mode (not just `-p` mode). The startup script merges this flag automatically when an OAuth token is configured.

## Shared Workspace PVC

All pods mount the same `workspace` PVC:
- Claude Code writes files → visible in code-server's file browser immediately
- code-server edits → visible to Claude and `kubectl exec`
- Three access methods, one filesystem

## code-server IDE Banner

A k8laude banner is injected into the VS Code workbench UI via a postStart lifecycle hook. The hook copies a JS file into the workbench directory and adds a `<script>` tag to `workbench.html`.

**How it works**: A postStart lifecycle hook appends a `<script>` tag to `workbench.html` using `cat` (not `sed` — see below). The script does two things:

1. **Overrides `window.innerHeight`** before VS Code initializes. VS Code reads `innerHeight` to calculate all panel heights. By returning `clientHeight - 37` (banner height), VS Code's entire layout accounts for the banner from the start — no bottom clipping.

2. **Inserts the banner div** into `<body>` as the first child. Since VS Code already sized itself 37px shorter, the banner fits above the workbench without overlap.

**Why `cat` not `sed`?** The banner JS contains a 3.5KB inline SVG data URI with URL-encoded characters (`%3C`, `%22`, etc.). When expanded via `${BANNER_JS}` in a `sed` command, shell special characters (`$`, `&`, backticks) corrupt the JS, causing `SyntaxError: Unexpected end of input`. The `cat`-based approach writes the JS file directly into the HTML without shell expansion: `head -c -8` strips `</html>`, `cat` appends the raw JS, then closes the tags.

**Why `innerHeight` override?** VS Code's layout engine uses `window.innerHeight` to set pixel heights on its split views, editors, panels, and status bar. These heights are cached and not recalculated on DOM changes. Overriding `innerHeight` before VS Code's JS executes is the only way to make the layout correct without fighting VS Code's layout recalculation (which ignores `resize` events from external code).

**Why a custom image?** code-server's workbench files are root-owned and the container runs as user 1000. A custom Dockerfile (`chart/charts/code-server/Dockerfile`) extends the upstream image with `chmod -R a+w` on the workbench directory, allowing the postStart hook to modify files at runtime.

**Why not a VS Code extension?** Extensions are sandboxed — they can't inject HTML/CSS into the workbench UI. The postStart injection approach is simpler and doesn't depend on extension APIs.

## code-server Settings

An init container merges `files.exclude` into VS Code's `settings.json` to hide internal directories (`.cache`, `.config`, `.local`, `.vscode-settings`, `.claude-config`, `.claude-debug`). Uses `jq -s '.[0] * .[1]'` to merge with existing settings rather than overwriting.

## Subchart Design

CloudTTY is a subchart at `chart/charts/cloudtty/` with `cloudtty.enabled=false` by default. This means:
- Existing deployments are unaffected
- Enable with `--set cloudtty.enabled=true`
- The subchart has its own `values.yaml` with all defaults
- Can reference the parent's workspace PVC via `persistence.existingWorkspaceClaim`

## Multi-tab / Multi-instance

**Supported**: Multiple tabs to the same pod (per-session SSE routing) and multiple pods each in their own tab (separate proxy servers).

**Known limitation**: Multiple Claude sessions in the same container may conflict on shared state (auth, config). This is an upstream Claude Code limitation (anthropics/claude-code#39637).

**Notification preferences** (`localStorage`) are shared across tabs on the same origin — intentional so users don't re-configure per tab.

## Custom Docker Image

`chart/charts/cloudtty/Dockerfile` builds a multi-arch image (`linux/amd64,linux/arm64`) including:
- Node.js 20, ttyd 1.7.7, Claude Code (latest)
- git, jq, curl
- Audio tools (alsa-utils, sox, pulseaudio-utils, libasound2-plugins) for future voice mode

See `chart/charts/cloudtty/BUILD.md` for build commands.

## Preflight Checks & Support Bundles

k8laude uses the [troubleshoot.sh](https://troubleshoot.sh) framework for pre-install validation and diagnostic data collection.

**Dual-spec architecture**: Specs exist in two forms to support both install methods:

| Install Method | Spec Location | Discovery |
|---|---|---|
| **Helm CLI** (`helm install`) | `chart/templates/preflight.yaml`, `supportbundle.yaml` (Secrets with `troubleshoot.sh/kind` labels) | `kubectl preflight --load-cluster-specs` / `kubectl support-bundle --load-cluster-specs` |
| **KOTS / Embedded Cluster** | `replicated/kots-preflight.yaml`, `kots-support-bundle.yaml` (standalone CRs) | KOTS Admin Console reads them directly |

The Helm chart Secrets use Helm template functions (`.Release.Name`, `.Release.Namespace`, `.Values.*`) for dynamic values. The KOTS CRs use `repl{{ Namespace }}` template functions.

**Support bundle from app UI** (Helm installs with SDK): The landing page has a "Generate Support Bundle" button that runs `support-bundle --load-cluster-specs` asynchronously (non-blocking `exec` to keep the health endpoint responsive during collection), then uploads the tarball to the Vendor Portal via `POST /api/v1/supportbundle`. Analyzer results are extracted from `analysis.json` in the tarball and displayed as a summary.

## KOTS Config Screen

The Admin Console config screen (`replicated/kots-config.yaml`) provides install-time configuration for Embedded Cluster and KOTS installs:

- **Authentication**: OAuth token vs API key selection with conditional fields
- **Database**: Embedded PostgreSQL vs external, with conditional connection fields and hostname regex validation. Generated password (`RandomString 24`) persists across upgrades.
- **Features**: CloudTTY, code-server, debug logging toggles. Each toggle controls whether the corresponding Deployment/StatefulSet is created. Voice mode gated by license entitlement.

The landing page adapts to feature toggles: when CloudTTY is disabled, it shows `kubectl exec` instructions instead of a terminal link; when code-server is disabled, it shows a "bring your own tools" message.
