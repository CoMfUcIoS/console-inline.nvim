# console-inline.nvim

![CI](https://github.com/comfucios/console-inline.nvim/actions/workflows/ci.yml/badge.svg)
![Lint](https://github.com/comfucios/console-inline.nvim/actions/workflows/lint.yml/badge.svg)

Zero-config Neovim plugin that shows `console.log/info/warn/error` inline as virtual text at the emitting source line.
Includes a Node `--require` shim and optional browser shim.

## Install (Lazy.nvim)

```lua
{
  "comfucios/console-inline.nvim",
  version = "*",
  event = "VimEnter",
  opts = {},
}
```

## Run with Node

```bash
npx @console-inline/shim node app.js
# or
NODE_OPTIONS="--require /path/to/console-inline.nvim/shim/node/console-inline-shim.js" node app.js
```

## Commands

- `:ConsoleInlineToggle` — start/stop server
- `:ConsoleInlineClear` — clear current buffer inline output
- `:ConsoleInlineCopy` — copy latest inline text on the cursor line

## Options

```lua
require('console_inline').setup({
  host = '127.0.0.1',
  port = 36123,
  open_missing_files = false,
  throttle_ms = 30,
  max_len = 160,
  severity_filter = { log = true, info = true, warn = true, error = true },
})
```

## CommonJS shim usage (when your project uses ESM)

If your project has `"type": "module"` or uses ESM, use the **CJS shim** with `NODE_OPTIONS`:

```bash
NODE_OPTIONS="--require /absolute/path/to/console-inline.nvim/shim/node/console-inline-shim.cjs" node app.js
```

Or via the CLI (auto-uses CJS shim internally):

```bash
npx @console-inline/shim node app.js
```

## Browser (dev) via WebSocket relay

The Neovim plugin listens on TCP; for browser logs, run a tiny WS→TCP relay:

```bash
# in project root
node tools/ws-relay.cjs
# WebSocket listens on ws://127.0.0.1:36124 and forwards to TCP 127.0.0.1:36123
```

Then import the browser shim (e.g., in Vite):

```ts
// main.ts
import "../../shim/browser/console-inline-shim.mjs";
```

Optionally configure env vars:

- `CONSOLE_INLINE_PORT` (TCP, Neovim) default `36123`
- `CONSOLE_INLINE_WS_PORT` (WS relay) default `36124`
