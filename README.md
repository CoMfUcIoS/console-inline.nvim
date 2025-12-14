# console-inline.nvim

[![CI](https://github.com/CoMfUcIoS/console-inline.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/CoMfUcIoS/console-inline.nvim/actions/workflows/ci.yml)
[![Lint](https://github.com/CoMfUcIoS/console-inline.nvim/actions/workflows/lint.yml/badge.svg)](https://github.com/CoMfUcIoS/console-inline.nvim/actions/workflows/lint.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](./LICENSE)

**Zero-config Neovim plugin that shows runtime output inline as virtual text** — logs, errors, traces, network requests, and timers all rendered directly at their source lines.

> Inspired by the Console Ninja experience — re-designed for Neovim power users with trace support, network logging, and source-map awareness built-in.

---

## Quick Start

### 1. Import the service in your app

**Node.js:**

```js
import "@console-inline/service";
console.log("Hello from Node");
```

**Browser (React, Vue, Vite, Next.js, etc.):**

```js
import "@console-inline/service";
console.log("Hello from the browser");
```

### 2. Install the plugin

**Lazy.nvim:**

```lua
{
  "CoMfUcIoS/console-inline.nvim",
  version = "*",
  event = "VimEnter",
  opts = {},  -- zero-config defaults work great
}
```

### 3. Run your app

- **Node.js:** `node app.js`
- **Browser:** `npm run dev` (or your build command)
- **Vite:** `vite`

That's it! Console output appears inline as you code.

---

## Features

### Core Capabilities

- ✅ **Console methods** — `log`, `info`, `warn`, `error` rendered inline
- ✅ **Stack traces** — Full `console.trace` with clickable source links
- ✅ **Runtime errors** — Uncaught exceptions and unhandled promise rejections
- ✅ **Network logging** — `fetch` and `XMLHttpRequest` events with status codes
- ✅ **Timer tracking** — `console.time` / `console.timeEnd` durations inline
- ✅ **Source maps** — Accurate placement for TypeScript, JSX, and bundled code
- ✅ **Per-line history** — Cycle through multiple outputs on the same line with `<leader>cn`/`<leader>cp`
- ✅ **Type-aware highlighting** — Strings, numbers, booleans, objects, arrays render in different colors
- ✅ **Interactive inspector** — Browse all messages with filtering, sorting, and jump-to-source
- ✅ **Single-file runner** — Execute current file with `:ConsoleInlineRun` (auto-detects Node/Deno/Bun)

### Quality of Life

- Auto-reconnection on network failures
- Relay auto-restart for robustness
- Comprehensive diagnostic dashboard (`:ConsoleInlineStatus`)
- Hover popups for detailed inspection
- Telescope history picker for cross-buffer searches
- Copy output to clipboard with a keystroke

---

## Workflows

### Debugging a single file

```lua
-- Execute current file with auto-detected runtime
:ConsoleInlineRun

-- Or specify runtime explicitly
:ConsoleInlineRun node
:ConsoleInlineRun deno
:ConsoleInlineRun bun
```

Console output appears inline. Errors are displayed in a split or popup. No terminal context switch needed.

### Cycling through multiple outputs on the same line

When a line logs multiple times:

```js
for (let i = 0; i < 3; i++) {
  console.log("count:", i); // logs 3 times
}
```

Use the keyboard bindings to cycle:

```lua
" In your nvim config, optional custom keymaps:
vim.keymap.set("n", "<leader>cn", ":ConsoleInlineNext<CR>")
vim.keymap.set("n", "<leader>cp", ":ConsoleInlinePrev<CR>")
```

The display shows `[1/3]`, `[2/3]`, `[3/3]` so you know where you are.

### Inspecting all messages

Open the interactive inspector:

```lua
:ConsoleInlineInspector
```

Browse all messages grouped by severity. Jump to source with `<CR>`, search with `/`, yank with `y`, clear history with `c`. Press `q` to close.

### Viewing the diagnostic dashboard

```lua
:ConsoleInlineStatus
```

Shows:

- Server status (✓ running / ✗ stopped)
- Active socket count
- Total message count by severity
- Source map resolution rate
- Active filters and what's being filtered
- Last message timestamp

### Using the Telescope history picker

```lua
:ConsoleInlineHistory
```

Search across all logged messages and jump to their source files. Press `<C-d>` to clear history.

---

## Type-Aware Syntax Highlighting

By default, output is highlighted by type:

- **Strings** → `String` highlight (typically green)
- **Numbers** → `Number` highlight (typically orange)
- **Booleans** → `Boolean` highlight
- **null/undefined** → `Comment` highlight
- **Objects/Arrays** → `Structure` highlight
- **Functions** → `Function` highlight
- **Dates** → `Special` highlight
- **Regexes** → `Special` highlight

Disable with:

```lua
require("console_inline").setup({
  type_highlighting = false,  -- falls back to single-color output
})
```

Customize highlight groups in your config:

```lua
vim.cmd("highlight ConsoleInlineString ctermfg=2 guifg=#90EE90")
vim.cmd("highlight ConsoleInlineNumber ctermfg=3 guifg=#FFD700")
```

---

## Configuration

### Installation with Lazy.nvim

```lua
{
  "CoMfUcIoS/console-inline.nvim",
  version = "*",
  event = "VimEnter",
  opts = {
    -- Server options
    host = "127.0.0.1",
    port = 36123,

    -- Startup behavior
    autostart = true,
    autostart_relay = true,
    replay_persisted_logs = false,

    -- Indexing & performance
    use_index = true,
    use_treesitter = false,
    incremental_index = true,
    index_batch_size = 900,
    treesitter_debounce_ms = 120,
    max_tokens_per_line = 120,
    skip_long_lines_len = 4000,

    -- Source mapping & display
    prefer_original_source = true,
    resolve_source_maps = true,
    throttle_ms = 30,
    max_len = 160,

    -- Type highlighting
    type_highlighting = true,

    -- Runner options
    runner = {
      default = "node",        -- auto-detect by default
      show_output = true,
      auto_clear = false,
    },

    -- Inspector options
    inspector = {
      floating = true,
      width = 80,
      height = 30,
    },

    -- Message filtering
    severity_filter = {
      log = true,
      info = true,
      warn = true,
      error = true,
    },

    -- Hover behavior
    hover = {
      enabled = true,
      events = { "CursorHold" },
      hide_events = { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" },
      border = "rounded",
      focusable = false,
      relative = "cursor",
      row = 1,
      col = 0,
    },

    -- History
    history_size = 200,
  },
}
```

---

## Commands

| Command                       | Description                                          |
| ----------------------------- | ---------------------------------------------------- |
| `:ConsoleInlineToggle`        | Start/stop the TCP server                            |
| `:ConsoleInlineStatus`        | Show diagnostic dashboard                            |
| `:ConsoleInlineClear`         | Clear inline output in current buffer                |
| `:ConsoleInlineCopy`          | Copy message at cursor to clipboard                  |
| `:ConsoleInlinePopup`         | Open detailed inspection popup for message at cursor |
| `:ConsoleInlineNext`          | Cycle to next message on current line                |
| `:ConsoleInlinePrev`          | Cycle to previous message on current line            |
| `:ConsoleInlineRun [runtime]` | Execute current file (auto-detects runtime)          |
| `:ConsoleInlineInspector`     | Open interactive message inspector                   |
| `:ConsoleInlineHistory`       | Telescope picker for all messages                    |

---

## How It Works

1. **Service layer** — Lightweight JavaScript library in `packages/service` instruments `console`, errors, and network APIs
2. **Relay** — Node.js process forwards events from browser to Neovim over WebSocket
3. **TCP bridge** — Neovim listens on `127.0.0.1:36123` for messages from Node.js apps
4. **Rendering** — Virtual text extmarks place output at source lines (with source-map resolution)
5. **UI** — Popups, Telescope pickers, and the interactive inspector for browsing/filtering

---

## Connection Reliability

### Auto-Reconnection

- **Relay auto-restart** — If the relay process crashes, it's automatically respawned after 1 second
- **WebSocket reconnection** — Browser clients automatically reconnect on network interruptions
- **TCP reconnection** — Node.js clients detect disconnections and attempt to re-establish

### Diagnostic Commands

Use `:ConsoleInlineStatus` to check:

- Whether the server is running
- How many sockets are connected
- Source map resolution success rate
- Active filters and their impact

---

## Environment Variables

Control activation:

```bash
CONSOLE_INLINE_ENABLED=true       # Force enable
CONSOLE_INLINE_DISABLED=true      # Force disable
CONSOLE_INLINE_HOST=localhost     # Custom host
CONSOLE_INLINE_PORT=36124         # Custom port
```

---

## Troubleshooting

**"No connection" in status command?**

- Run `:ConsoleInlineToggle` to start the server
- Verify `@console-inline/service` is imported in your app
- Check `:ConsoleInlineStatus` for connection details

**Messages not appearing?**

- Ensure the file is saved
- Check `:ConsoleInlineStatus` for active filters
- Try `:ConsoleInlineClear` to reset the display

**Port already in use?**

- Change `opts.port` to a different value (e.g., 36124)
- Or kill the existing process: `lsof -i :36123`

---

## Examples

See the [examples/](./examples) directory for complete setup examples:

- [Node.js](./examples/node) — Plain Node.js with TypeScript
- [Browser (Vite)](./examples/browser-vite) — React + Vite + console-inline

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for release history.

---

## Contributing

Contributions are welcome! Please open an issue or PR.

---

## Support

If console-inline.nvim saves you time, consider sponsoring:

- [GitHub Sponsors](https://github.com/sponsors/CoMfUcIoS)
- [Buy Me a Coffee](https://www.buymeacoffee.com/CoMfUcIoS)

---

## License

GPL-3.0-or-later  
© 2025 Ioannis Karasavvaidis
