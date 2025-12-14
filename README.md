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

### Smart Source Map Resolution

When you log from TypeScript, JSX, or bundled code, console-inline automatically maps back to the original source:

```lua
" Original (bundled): app.min.js:1234:56
" Resolved source: src/components/App.tsx:42

:ConsoleInlineStatus
" Shows: Source Maps: 44 hits, 3 misses (93.6% resolution rate)
```

**Configuration**:

```lua
opts = {
  resolve_source_maps = true,       -- enable (default)
  prefer_original_source = true,    -- trust emitted original_line if available
  show_original_and_transformed = false,  -- show both in popup if they differ
}
```

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

    -- Indexing & performance
    use_index = true,
    use_treesitter = false,          -- opt-in Tree-sitter for precise placement
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

    -- Advanced options (optional)
    open_missing_files = false,       -- auto-open files that don't exist yet
    replay_persisted_logs = false,    -- replay logs from file on buffer open
    show_original_and_transformed = false, -- show source-map before/after in popup
    benchmark_enabled = false,        -- collect timing statistics
    suppress_css_color_conflicts = true, -- disable css-color plugin on console buffers
    pattern_overrides = nil,          -- custom TODO/FIXME/NOTE icons & colors
    filters = nil,                    -- allow/deny rules for files & messages
    popup_formatter = nil,            -- custom formatter for popup content
  },
}
```

---

## Commands

### Essential Commands

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

### Advanced Commands

| Command                     | Description                                          |
| --------------------------- | ---------------------------------------------------- |
| `:ConsoleInlineReindex`     | Manually rebuild buffer index for placement accuracy |
| `:ConsoleInlineBenchmark [n]` | Run placement performance benchmark (n iterations)   |
| `:ConsoleInlineDiagnostics` | Show detailed index stats, timing, and buffer info   |

---

## Advanced Features

### Message Filtering

Use `filters` to control which messages are displayed based on file paths and message content.

#### Allow/Deny Rules

```lua
opts = {
  filters = {
    -- Only show messages from these files
    allow = {
      paths = { "src/**", "app/**" },
      messages = { "user:", "auth:" },  -- substring match
    },
    -- Hide messages from these files
    deny = {
      paths = { "node_modules/**", "dist/**" },
      messages = { "DEBUG" },
    },
  },
}
```

#### Severity Rules (Per-File)

```lua
filters = {
  -- Base severity applies to all files
  -- Then override for specific paths
  severity = {
    {
      paths = { "tests/**" },
      -- Only show errors and warnings in tests
      log = false,
      info = false,
      warn = true,
      error = true,
    },
    {
      messages = { pattern = "slow" },
      warn = true,  -- highlight slow ops as warnings
    },
  },
}
```

**Matching Options**:
- `glob` — File path glob pattern (e.g., `"src/**/*.ts"`)
- `pattern` — Lua regex pattern (default)
- `plain` — Literal substring match
- `contains` — Alias for substring match

### Pattern Overrides (Custom Icons & Highlights)

Automatically highlight specific patterns in console output with custom icons and colors.

**Default Patterns** (built-in):
- `TODO` → 📝 (Todo highlight)
- `FIXME` → 🛠 (WarningMsg)
- `NOTE` → 🗒 (SpecialComment)

**Custom Patterns**:

```lua
opts = {
  pattern_overrides = {
    -- Disable default patterns
    false,  -- or set to { } to clear

    -- Custom pattern with icon and highlight
    {
      pattern = "HACK",
      icon = "💡",
      highlight = "Title",
      plain = true,           -- literal substring match
      ignore_case = true,     -- case-insensitive
    },
    {
      pattern = "%[WARN%]",   -- Lua regex
      icon = "⚠️",
      highlight = "WarningMsg",
    },
  },
}
```

### Smart Message Placement

console-inline uses intelligent candidate resolution to find the correct source line even when source maps are unavailable.

**Strategies** (in order):
1. **Buffer index** — Pre-indexed console/network calls for O(1) lookup (enabled by default)
2. **Tree-sitter context** — Optional: uses syntax tree for more precise placement
3. **Fuzzy scan** — Fallback: searches nearby lines for matching patterns

**Enable Tree-sitter Support** (more accurate for complex code):

```lua
opts = {
  use_treesitter = true,
  treesitter_debounce_ms = 120,
}
```

**Tune Indexing Performance**:

```lua
opts = {
  use_index = true,                 -- enable/disable indexing
  incremental_index = true,         -- progressively build large indexes
  index_batch_size = 900,           -- lines per batch
  max_tokens_per_line = 120,        -- cap per-line complexity
  skip_long_lines_len = 4000,       -- skip minified code
}
```

Use `:ConsoleInlineReindex` to rebuild the buffer index if messages aren't placed correctly.

### Log Persistence & Replay

Persist console messages to disk and automatically replay them when reopening buffers.

```lua
opts = {
  replay_persisted_logs = true,  -- replay logs from file on buffer open
}
```

Logs are written to `console-inline.log` (or set `CONSOLE_INLINE_LOG_PATH` env var).

**Use Case**: Quickly switch between branches or restart Neovim without losing recent output.

### Custom Popup Formatting

Provide a custom formatter function for how messages appear in `:ConsoleInlinePopup`:

```lua
opts = {
  popup_formatter = function(entry)
    -- entry is a message object with:
    -- - file, line, kind (log/warn/error), args, payload, trace, time, network, etc.
    return {
      "Custom title",
      "Line 1 of formatted output",
      "Line 2 of formatted output",
    }
  end,
}
```

### Performance Diagnostics

**View detailed stats about placement accuracy and timing**:

```lua
:ConsoleInlineDiagnostics
```

Shows:
- Index status (complete/partial/building)
- Indexed line counts (console, network)
- Token count and method frequencies
- Timing stats (avg index time, avg scan time)
- Source map hit rate

**Run a placement benchmark**:

```lua
:ConsoleInlineBenchmark 100  -- 100 iterations
```

Useful for tuning `max_tokens_per_line`, `index_batch_size`, and other options for your codebase.

### Tree-sitter Integration (Beta)

For projects with complex syntax (JSX, TypeScript generics, etc.), opt-in Tree-sitter support for more reliable placement:

```lua
opts = {
  use_treesitter = true,
}
```

**Trade-off**: Slightly slower placement lookup, but more accurate for deeply nested code.

**View Tree-sitter stats**:

```lua
:ConsoleInlineDiagnostics
```

Shows: language, context cache size, rebuild counts.

### Suppressing CSS Color Plugin Conflicts

Some color plugins (like `colorizer.lua`) may conflict with console-inline's virtual text. Control this with:

```lua
opts = {
  suppress_css_color_conflicts = true,  -- disable conflicting plugins on console buffers
}
```

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

Control activation and behavior via environment variables:

```bash
# Activation
CONSOLE_INLINE_ENABLED=true        # Force enable (ignores autostart)
CONSOLE_INLINE_DISABLED=true       # Force disable completely

# Connection
CONSOLE_INLINE_HOST=localhost      # Custom server host
CONSOLE_INLINE_PORT=36124          # Custom server port
CONSOLE_INLINE_WS_PORT=36125       # WebSocket relay port

# Relay & Logging
CONSOLE_INLINE_RECONNECT_MS=1000   # Reconnection delay (ms)
CONSOLE_INLINE_MAX_QUEUE=200       # Max buffered messages
CONSOLE_INLINE_LOG_PATH=/tmp/console-inline.log
CONSOLE_INLINE_LOG_FLUSH_MS=100    # Log flush interval
CONSOLE_INLINE_LOG_MAX_BYTES=1000000  # Max log file size
CONSOLE_INLINE_LOG_MAX_FILES=3     # Rotated log file count
CONSOLE_INLINE_DEBUG=true          # Enable debug logging
```

---

## Performance Tuning

### Slow Message Placement?

If messages take several seconds to appear, check these options:

```lua
-- 1. Use index (faster, default)
opts = {
  use_index = true,
  incremental_index = true,
  index_batch_size = 900,
}

-- 2. Skip very long lines (likely minified)
max_tokens_per_line = 80,    -- reduce if index is memory-heavy
skip_long_lines_len = 3000,  -- skip minified files

-- 3. Run diagnostics to see where time is spent
:ConsoleInlineDiagnostics
:ConsoleInlineBenchmark 50

-- 4. Optional: disable Tree-sitter if not needed
use_treesitter = false,
```

### Large Files Not Indexed?

Indexing is intentionally **incremental** to avoid blocking the UI:

```lua
-- View incremental build progress
:ConsoleInlineDiagnostics

-- Force immediate full reindex
:ConsoleInlineReindex
```

### Too Much History Consuming Memory?

```lua
-- Limit history size
opts = {
  history_size = 100,  -- instead of 200
}

-- Clear history manually
:ConsoleInlineHistory  -- then press 'c' in Telescope picker
```

---

## Troubleshooting

**"No connection" in status command?**

- Run `:ConsoleInlineToggle` to start the server
- Verify `@console-inline/service` is imported in your app
- Check `:ConsoleInlineStatus` for connection details
- Ensure the port is not in use: `lsof -i :36123`

**Messages not appearing?**

- Ensure the file is saved (extmarks are placed on saved buffers)
- Check `:ConsoleInlineStatus` for active filters (may be hiding output)
- Try `:ConsoleInlineClear` to reset the display
- Verify the file path matches (check source map resolution in `:ConsoleInlineStatus`)
- Run `:ConsoleInlineReindex` to force candidate re-scan

**Placement is incorrect (off by N lines)?**

- Enable Tree-sitter: `use_treesitter = true` (more accurate for complex syntax)
- Run `:ConsoleInlineReindex` to rebuild the buffer index
- Check `:ConsoleInlineDiagnostics` to see index status
- If using bundled/minified code, ensure source maps are resolved

**Port already in use?**

- Change `opts.port` to a different value (e.g., 36124)
- Or kill the existing process: `lsof -i :36123 | grep node | awk '{print $2}' | xargs kill`

**Console output in wrong file?**

- This usually means source maps aren't being resolved
- Check `:ConsoleInlineStatus` for "Source Maps: X hits, Y misses"
- Ensure `resolve_source_maps = true` (default)
- Verify your build tool generates `.map` files

**Relay crashes frequently?**

- Check relay logs: `tail -f console-inline.log`
- Increase heap: `NODE_OPTIONS=--max-old-space-size=512` before running
- Report with `CONSOLE_INLINE_DEBUG=true node ...` output

---

## Tips & Best Practices

### Use Keymaps for Quick Access

```lua
local ci = require("console_inline")

-- Quick toggles
vim.keymap.set("n", "<leader>cx", ":ConsoleInlineToggle<CR>", { noremap = true })
vim.keymap.set("n", "<leader>cs", ":ConsoleInlineStatus<CR>", { noremap = true })
vim.keymap.set("n", "<leader>cd", ":ConsoleInlinePopup<CR>", { noremap = true })
vim.keymap.set("n", "<leader>ci", ":ConsoleInlineInspector<CR>", { noremap = true })
vim.keymap.set("n", "<leader>ch", ":ConsoleInlineHistory<CR>", { noremap = true })

-- Per-line cycling (already has defaults <leader>cn/cp)
vim.keymap.set("n", "[c", ":ConsoleInlinePrev<CR>", { noremap = true })
vim.keymap.set("n", "]c", ":ConsoleInlineNext<CR>", { noremap = true })
```

### Combine with Other Tools

- **DAP (Debugger)**: console-inline complements breakpoint debugging; use together for best results
- **Copilot**: Ask AI to explain unexpected console values in `:ConsoleInlinePopup`
- **Telescope**: History picker integrates seamlessly for cross-buffer log search

### Filter Out Noisy Messages

```lua
opts = {
  filters = {
    deny = {
      messages = {
        "GET /socket.io",        -- WebSocket noise
        "debug:",                -- Framework logs
        pattern = "%[HMR%]",     -- Hot module reload
      },
    },
  },
}
```

### Customize Icons for Your Workflow

```lua
-- Highlight critical sections in your code
opts = {
  pattern_overrides = {
    { pattern = "CRITICAL", icon = "🚨", highlight = "Error", plain = true },
    { pattern = "REVIEW", icon = "👀", highlight = "Title", plain = true },
    { pattern = "DEPRECATED", icon = "💀", highlight = "WarningMsg" },
  },
}
```

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
