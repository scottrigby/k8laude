# Iframe Elimination: Direct HTML Injection into ttyd

## Goal

Replace the current wrapper page + iframe approach with direct HTML injection into ttyd's response. The proxy already buffers and modifies ttyd's HTML (for Shift+Enter keybinding injection). This refactor expands that injection to include the full toolbar, SSE client, Service Worker, and notification JS.

## Current Architecture (iframe)

```
Browser requests /term/
  → Proxy serves wrapper HTML (index.html from extensions-configmap)
    → Wrapper has toolbar + iframe
    → iframe loads /term/ttyd/?arg=SESSION_ID
      → Proxy strips /term/ttyd prefix, forwards to ttyd on :7682
      → ttyd serves its own HTML with terminal
```

Problems:
- `window.term` (xterm.js instance) is inside the iframe, not accessible from the wrapper
- Shift+Enter keybinding must be injected separately into the iframe's HTML
- Two layers of HTML serving (wrapper + ttyd)
- The `/term/ttyd/` prefix routing adds complexity
- Reconnect button reloads the iframe, not the terminal connection

## Target Architecture (direct injection)

```
Browser requests /term/?arg=SESSION_ID
  → Proxy forwards to ttyd on :7682 with ?arg=SESSION_ID
  → ttyd serves its HTML
  → Proxy intercepts the HTML response and injects:
    - CSS for toolbar and toast notifications (before </head>)
    - Toolbar HTML (after <body>)
    - Toast container div (before </body>)  
    - JavaScript: SSE client, Service Worker, notifications, 
      preferences, audio, TTS, Shift+Enter keybinding (before </body>)
  → Browser receives a single page with terminal + toolbar + notifications
```

Benefits:
- `window.term` directly accessible — no iframe boundary
- Single page load, no iframe overhead
- Simpler proxy routing — no `/term/ttyd/` prefix needed
- Shift+Enter injection merged into the main script block
- Direct access to xterm.js addons and events

## What to Inject

### Before `</head>`:
- CSS for toolbar, toast notifications, notification checkboxes, badges

### After `<body>` (before terminal container):
- Toolbar HTML div with:
  - "CloudTTY" title
  - Connection status indicator
  - Notification checkboxes (Toast, Desktop, Sound, TTS)
  - "all on/all off" toggle
  - Reconnect button

### Before `</body>`:
- Toast container div
- JavaScript block containing:
  - Session ID generation (sessionStorage)
  - Service Worker registration at `/term/sw.js`
  - Notification preferences (localStorage)
  - Audio chime (AudioContext)
  - TTS (speechSynthesis)
  - SSE client connecting to `/term/api/events?sessionId=SESSION_ID`
  - Notification handler (toast + desktop + sound + TTS)
  - Shift+Enter keybinding (poll for `window.term`, attach custom key handler)
  - Unread count in title
  - Reconnect function

## Key Differences from Current Approach

### Session ID
Currently: wrapper page generates SESSION_ID and passes to iframe via `ttyd/?arg=SESSION_ID`.
New: the injected JS generates SESSION_ID, but ttyd needs it as a URL parameter for `--url-arg`. Options:
1. User navigates to `/term/?arg=SESSION_ID` (JS redirects if no arg present)
2. Proxy generates SESSION_ID and appends it to ttyd's URL before forwarding
3. JS sets SESSION_ID from URL params OR generates new one

Recommended: **Option 3** — the injected JS reads `?arg=` from the URL. If not present, generate one and redirect to `?arg=NEW_ID`. This way the URL always contains the session ID and ttyd receives it via `--url-arg`.

### Base Path
Currently: wrapper page computes `BASE = location.pathname.replace(/\/$/, '')` and uses it for SSE/SW URLs.
New: same approach works. The page is at `/term/` so BASE = `/term`.

### Reconnect
Currently: `document.getElementById('terminal-frame').src += ''` reloads the iframe.
New: need to reconnect the WebSocket. ttyd exposes reconnection — check `window.term` for reconnect method, or reload the page.

### Service Worker Scope
Currently: SW registered at `BASE + '/sw.js'` with `scope: BASE + '/'`.
New: same. The SW file is served by the proxy at `/term/sw.js` (already implemented).

## Proxy Server Changes

### Remove:
- Wrapper page route (`GET /term/` serving `index.html`)
- The `/term/ttyd/` prefix stripping for HTTP and WebSocket proxy
- The extensions-configmap (or repurpose it for the injection script)

### Modify:
- HTTP proxy: when ttyd responds with HTML, buffer it and inject content
- The injection already exists (for Shift+Enter). Expand it to inject ALL content.
- WebSocket proxy: simplify path handling (no `/term/ttyd/` prefix)
- Redirects: `/` and `/term` → `/term/` (keep, but `/term/` now goes to ttyd)

### Keep:
- `POST /term/api/notify` — notification endpoint
- `GET /term/api/events` — SSE stream
- `GET /term/api/health` — health check
- `GET /term/sw.js` — Service Worker file
- WebSocket proxy with query param forwarding

## ttyd's HTML Structure

ttyd serves a single HTML file. The key elements:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ttyd - Terminal</title>
  <style>/* xterm.js styles */</style>
</head>
<body>
  <div id="terminal-container">
    <div class="terminal"></div>
  </div>
  <!-- modals for file transfer -->
  <script>/* bundled app JS */</script>
</body>
</html>
```

We inject:
1. Our CSS in `<head>` (before `</head>`)
2. Our toolbar div after `<body>` (push terminal container down)
3. Our toast div + JS before `</body>`

The terminal container uses `height: 100%` — we'll need to adjust it to account for the toolbar height. Add `#terminal-container { height: calc(100% - 32px); }` or similar.

## Files to Modify

| File | Changes |
|------|---------|
| `configmap.yaml` (server.js) | Remove wrapper route, expand HTML injection, simplify proxy paths |
| `extensions-configmap.yaml` | Repurpose: instead of `index.html`, store the injection CSS + HTML + JS as separate keys |
| `deployment.yaml` | No changes (still mounts both configmaps) |

## Testing Checklist

- [ ] Terminal loads at /term/ (no iframe)
- [ ] Toolbar visible above terminal
- [ ] Notification checkboxes work (persist in localStorage)
- [ ] SSE connects with session ID
- [ ] `notify` command from terminal delivers to correct tab
- [ ] Desktop notifications via Service Worker
- [ ] Sound and TTS work
- [ ] Shift+Enter inserts newline
- [ ] Reconnect button works
- [ ] Multiple tabs: separate sessions, no cross-talk
- [ ] Health endpoint responds
- [ ] Terminal resizes properly with toolbar
