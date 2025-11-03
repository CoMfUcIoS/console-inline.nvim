# console-inline.nvim

![CI](https://github.com/comfucios/console-inline.nvim/actions/workflows/ci.yml/badge.svg)
![Lint](https://github.com/comfucios/console-inline.nvim/actions/workflows/lint.yml/badge.svg)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Zero-config Neovim plugin that shows `console.log/info/warn/error` inline as virtual text at the emitting source line.

> Inspired by the excellent [Console Ninja](https://marketplace.visualstudio.com/items?itemName=WallabyJs.console-ninja) experience—now tailored for Neovim.

![Browser demo with virtual text](images/screenshot-browser.png)
![Node demo with virtual text](images/screenshot-node.png)
![Popup view for long payloads](images/screenshot-popup.png)
![Console History](images/screenshot-history.png)

## Zero-config Usage (Recommended)

### Node.js

Just import the service package at the top of your entry file:

```js
import "@console-inline/service";
console.log("Hello from Node!");
```

### Browser/React (Vite, Next.js, etc)

Import the service package in your main entry file:

```js
import "@console-inline/service";
console.log("Hello from browser!");
```

All console output will be sent to Neovim as virtual text automatically. No manual relay setup required.

⚠️ The service only activates in development by default (based on `NODE_ENV`, `import.meta.env.DEV/PROD`, etc.). Set `CONSOLE_INLINE_ENABLED=true` to force enable, or `CONSOLE_INLINE_DISABLED=true` to opt out.

---

## Features

- Inline display of `console.log`, `console.info`, `console.warn`, and `console.error` output directly at the source line in Neovim
- `console.trace` call stacks rendered inline with detailed frames available in the history picker and popup
- `console.time` / `console.timeEnd` durations surfaced beside the terminating call for quick performance checks
- Runtime errors (`window.onerror`/`process.uncaughtException`) and unhandled promise rejections captured inline so crashes don’t fall through the cracks
- Network request logs for `fetch` and `XMLHttpRequest`, including status, errors, and timing inline beside the callsite
- Automatic hover popups (via `CursorHold`) to inspect the full payload without leaving your buffer
- Works with Node.js, browser (via WebSocket relay), and ESM/CJS projects
- No configuration required for basic usage
- Supports persistent logs and queued messages
- Customizable severity filtering, throttling, and output length
- Ships `@console-inline/service` for Node and browser runtimes and auto-starts the local relay
- Example projects for Node and browser (Vite)

## File Structure

- `plugin/console-inline.lua`: Neovim plugin entry point
- `lua/console_inline/`: Lua modules for state, server, rendering, commands
- `examples/`: Example Node and browser projects
- `tests/`: Lua specs (Plenary/Busted style)
- `shim/node/console-inline-shim.cjs`: optional legacy CommonJS shim for manual injection

## Install (Lazy.nvim)

```lua
{
  "comfucios/console-inline.nvim",
  version = "*",
  event = "VimEnter",
  opts = {
    -- Server settings
    host = '127.0.0.1',
    port = 36123,

    -- Behavior
    autostart = true,                      -- Start on VimEnter
    autostart_relay = true,                -- Auto-start WebSocket relay for browsers
    open_missing_files = false,            -- Don't auto-open files (can be disruptive)
    replay_persisted_logs = false,         -- Don't replay old logs on buffer open

    -- Performance & placement
    use_index = true,                      -- Enable fast buffer indexing (critical)
    use_treesitter = true,                 -- Enable Tree-sitter for accurate placement
    prefer_original_source = true,         -- Trust source maps (TypeScript/JSX locations)
    resolve_source_maps = true,            -- Enable source map resolution
    benchmark_enabled = false,             -- Disable benchmark overhead

    -- Display
    throttle_ms = 30,                      -- Debounce rapid updates
    max_len = 160,                         -- Truncate long messages
    suppress_css_color_conflicts = true,   -- Prevent css-color plugin crashes

    -- Filtering
    severity_filter = {
      log = true,
      info = true,
      warn = true,
      error = true,
    },

    -- History
    history_size = 200,                    -- Keep 200 entries for Telescope picker

    -- Hover popups (auto-show on CursorHold)
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

    -- Optional: Customize pattern highlighting
    -- pattern_overrides = {
    --   { pattern = 'CRITICAL', icon = '💥', highlight = 'ErrorMsg' },
    -- },

    -- Optional: Filter by path/message
    -- filters = {
    --   deny = {
    --     paths = { '**/node_modules/**' },
    --     messages = { { pattern = 'DEBUG', plain = true } },
    --   },
    -- },
  },
}
```

## Commands

- `:ConsoleInlineToggle` — Start or stop the console-inline server.
- `:ConsoleInlineClear` — Clear all inline console output from the current buffer.
- `:ConsoleInlineCopy` — Copy the inline console output from the current line.
- `:ConsoleInlinePopup` — Open a floating window with formatted output for the message under the cursor.
- `:ConsoleInlineHistory` — Search recent console output across buffers via Telescope.

## Options

```lua
require('console_inline').setup({
  host = '127.0.0.1',
  port = 36123,
  open_missing_files = false,
  throttle_ms = 30,
  max_len = 160,
  severity_filter = { log = true, info = true, warn = true, error = true },
  autostart_relay = true,
  replay_persisted_logs = false,
  suppress_css_color_conflicts = true,
  history_size = 200,
  pattern_overrides = nil,
  filters = nil,
  use_treesitter = true, -- leverage Tree-sitter (JS/TS/TSX) for accurate structural placement
  use_index = true, -- set false to disable buffer indexing & revert to full scans
  prefer_original_source = true, -- trust original_* coordinates from service (source maps / transforms)
  resolve_source_maps = true, -- attempt Node source map resolution (CONSOLE_INLINE_SOURCE_MAPS env overrides)
  show_original_and_transformed = false, -- popup shows both coord sets when they differ
})
```

- `host` / `port` — TCP endpoint the Neovim side listens on.
- `open_missing_files` — automatically `:edit` files that are not yet loaded when a message arrives.
- `severity_filter` — per-level switches for `log`/`info`/`warn`/`error` rendering.
- `throttle_ms` — minimum delay between virtual text updates for the same buffer+line.
- `max_len` — truncate serialized arguments to this many characters (adds ellipsis if exceeded).
- `autostart` — start the TCP server on `VimEnter` (default `true`); set `false` to manage it manually.
- `autostart_relay` — spawn a Node-based WebSocket→TCP relay so browser runtimes work without extra setup (default `true`).
- `replay_persisted_logs` — when `true`, replays entries from the JSON log file on `BufReadPost`.
- `suppress_css_color_conflicts` — disable known `css-color` style autocommands that crash when virtual text is replayed.
- `history_size` — maximum number of console entries retained for the Telescope history picker (`0` or lower keeps everything).
- `pattern_overrides` — array of `{ pattern, icon?, highlight?, plain? }` rules that customise the rendered icon or highlight when the payload matches (`nil` keeps built-in defaults, `false` disables them).
- `filters` — configure allow/deny lists and severity overrides for specific paths or payload patterns.
- `hover` — control automatic hover popups (set `enabled = false` to opt out, override `events`, `hide_events`, `border`, etc. to tweak behaviour).
- `popup_formatter` — optional function(entry) -> lines used for popup formatting; defaults to prettifying JSON via `vim.inspect`.
- `use_index` — when `true` (default) builds a lightweight per-buffer token index for fast, more accurate virtual text placement. Disable to fall back to naive scanning if you suspect indexing issues.
- `use_treesitter` — when `true` attempts a Tree-sitter parser (typescript, tsx, javascript) to extract structural context (function/class boundaries, console/fetch/error calls) for refined placement. Falls back silently if parser absent.
- `prefer_original_source` — when `true` (default) the renderer prefers `original_file`, `original_line`, and `original_column` emitted by the service over transformed coordinates.
- `resolve_source_maps` — when `true` (default) service tries to read sibling `*.js.map` files (Node) to recover authored locations; override with `CONSOLE_INLINE_SOURCE_MAPS=true|false`.
- `show_original_and_transformed` — when `true`, the popup lists both sets of coordinates if mapping succeeded and they differ.
- `benchmark_enabled` — `false` by default. Set `true` to collect timing stats for candidate resolution (used by `:ConsoleInlineBenchmark` / `:ConsoleInlineDiagnostics`). Disable in normal usage to avoid tiny overhead.

### Reindex Command

If you edit large portions of a file and want to force a full rebuild of the placement index, run:

`:ConsoleInlineReindex`

### Benchmark & Diagnostics

Run synthetic placement performance tests (default 100 iterations):

`:ConsoleInlineBenchmark 200` -- run with 200 iterations

Show index & timing stats:

`:ConsoleInlineDiagnostics`

Benchmark reports average/min/max render invocation times and counts of index vs scan candidate retrieval. Diagnostics show index composition and last placement metrics.

This clears and rebuilds the token index for the current buffer.

### Improved Placement Heuristic

Recent updates introduced:

- Proximity-first network call anchoring.
- Scoring-based candidate selection (method match, console presence, term overlap, comment penalties, line & column distance).
- Per-buffer indexing to avoid O(N) scans per message.
- Basic deletion handling and incremental token updates around recent edits.
- Optional Tree-sitter assisted bonuses (same function/class, explicit console/fetch/error call nodes) when `use_treesitter = true`.

### Tree-sitter Assisted Placement (Experimental)

Enable with:

```lua
require('console_inline').setup({
  use_treesitter = true,
})
```

Current enhancements:

- Detects `console.*` calls, `fetch(...)`, `new Error(...)`, `Promise.reject(...)`, and `throw` statements.
- Adds structural weighting: prefers same function or class scope, aligns exact console method names.
- Strong preference for actual error sites when displaying runtime errors (uncaught exceptions, unhandled rejections).
- Slight boosts for network (`fetch`) and error-centric locations for `warn`/`error` messages.
- Fallback: if a parser is not available for the buffer, regex-based pattern matching provides similar benefits.

**Note**: For best error positioning with runtime errors, enable Tree-sitter with `use_treesitter = true`. Without it, the plugin uses regex patterns which work but may be less precise for complex code.

**Browser Source Maps**: ✅ **Fully implemented and enabled by default**. The plugin automatically:

- Detects and fetches inline (`data:application/json;base64,...`) and external (`.map` files) source maps
- Preloads common entry points (`/main.ts`, `/src/main.ts`, etc.) during initialization
- Normalizes URLs to handle both full URLs (`http://localhost:5173/main.ts`) and paths (`/main.ts`)
- Translates transpiled coordinates to original source locations using `@jridgewell/trace-mapping`
- Works seamlessly with Vite, Next.js, and other modern bundlers

When source maps are available, console messages appear at their **true source locations** in your TypeScript/JSX files, not at transpiled JavaScript lines. No configuration required—just works in development mode.

**Fallback Heuristics**: If source maps are unavailable or disabled, the plugin uses intelligent heuristics (method matching, term matching, Tree-sitter context) as a robust fallback. This works well in practice, typically placing virtual text on the correct line even when coordinates are off by 20+ lines.

Planned expansions may include granular async/await boundary detection, JSX component scope weighting, and argument-sensitive proximity hints.

### Source Mapping

Source map resolution is **fully implemented and enabled by default** for both Node.js and browser environments. For each callsite:

1. Stack trace parsed → generated `file:line:column`.
2. Source map loaded & cached:
   - **Node.js**: Sibling `.js.map` files (e.g., `generated.js.map`)
   - **Browser**: Inline (`data:application/json;base64,...`) or external (`.map`) via `sourceMappingURL`
3. `@jridgewell/trace-mapping` resolves original authored coordinates.
4. Payload includes both generated and original fields plus explicit `transformed_*` duplicates for popup comparison.

#### Browser Source Maps

The browser implementation includes:

- **Automatic preloading**: Scans `<script>` tags and common entry points on page load
- **URL normalization**: Handles both full URLs and path-only formats
- **Promise coordination**: Prevents duplicate fetches for the same source map
- **Inline map support**: Parses base64-encoded inline source maps
- **External map support**: Fetches `.map` files via fetch API

To force-enable source maps for testing (bypasses dev environment check):

```html
<script>
  globalThis.__CONSOLE_INLINE_FORCE_SOURCEMAPS__ = true;
</script>
```

Options involved:

```lua
prefer_original_source = true          -- use mapped coordinates when available
resolve_source_maps = true             -- enable source map resolution (default: true in dev)
show_original_and_transformed = false  -- show both coordinate sets in popup
```

Environment overrides / tuning:

```bash
CONSOLE_INLINE_SOURCE_MAPS=false        # disable resolution entirely
CONSOLE_INLINE_SOURCE_MAPS=true         # force enable (e.g. production debug)
CONSOLE_INLINE_SOURCE_MAP_PRELOAD=false # disable background preload of Node map files
CONSOLE_INLINE_SOURCE_MAP_PRELOAD=true  # force enable preload (default true in dev)
CONSOLE_INLINE_SOURCE_MAP_MAX_QUEUE=50  # cap queued Node maps for preload (default 20)
```

`mapping_status` values exposed per payload:

- `hit` — original coordinates successfully resolved via source map
- `miss` — resolution attempted but no map / mapping failed (falls back to generated location)

If resolution fails, `original_*` simply mirrors generated coordinates; placement remains correct using fallback heuristics.

### Pattern overrides

By default the plugin highlights a few common tags:

- `TODO` → icon `📝`, highlight `Todo`
- `FIXME` → icon `🛠`, highlight `WarningMsg`
- `NOTE` → icon `🗒`, highlight `SpecialComment`

Use `pattern_overrides` to change how specific log lines look or add more rules:

```lua
require('console_inline').setup({
  pattern_overrides = {
    { pattern = 'TODO', icon = '✅', highlight = 'DiffAdd', plain = true, ignore_case = true }, -- overrides default
    { pattern = 'CRITICAL', icon = '💥', highlight = 'ErrorMsg' },                             -- extends defaults
  },
})
```

- `pattern` — Lua pattern matched against the full JSON payload string.
- `plain` — when `true`, performs a plain substring match instead of a Lua pattern.
- `ignore_case` — when `true`, compares case-insensitively (supported for `plain` matches and simple patterns).
- `icon` — overrides the virtual text icon.
- `highlight` — overrides the highlight group applied to the virtual text.

Set `pattern_overrides = false` to disable all pattern-based styling.

### Project filters

Use `filters` to scope which logs surface and to tune severity per path or payload:

```lua
require('console_inline').setup({
  filters = {
    allow = {
      paths = { vim.loop.cwd() .. '/apps/**' },
    },
    deny = {
      messages = { { pattern = 'DEBUG', plain = true }, 'trace:' },
      paths = { '**/node_modules/**' },
    },
    severity = {
      {
        paths = { '**/services/**' },
        allow = { log = false, info = true, warn = true, error = true },
      },
      {
        messages = { { pattern = 'SQL', plain = true } },
        allow = { log = false, info = false, warn = true, error = true },
      },
    },
  },
})
```

- `allow` — optional `paths`/`messages` lists (strings, globs, or rule tables) that must match for a log to render.
- `deny` — optional `paths`/`messages` lists that immediately suppress matched logs.
- `severity` — ordered rules that override the active severity filter when their `paths`/`messages` match (`allow` sets booleans; `only = { 'warn', 'error' }` keeps just those levels).

Strings under `paths` are treated as file globs (`**` supported). Message entries are plain substrings by default; provide `{ pattern = 'regex' }` for Lua pattern checks or `{ glob = 'glob/**' }` to match filenames explicitly. Set `filters = nil` (default) to keep all logs, or `filters = { deny = { ... } }` to layer selective suppression.

### Service environment variables

`@console-inline/service` (and its in-process relay) respond to a few optional environment variables:

- `CONSOLE_INLINE_WS_RECONNECT_MS` — delay between WebSocket reconnect attempts (default `1000`).
- `CONSOLE_INLINE_MAX_QUEUE` — max messages to buffer while the TCP server is offline (default `200`; oldest entries are dropped first).
- `CONSOLE_INLINE_DEBUG` — enable verbose logging in both the service and relay for troubleshooting.
- `CONSOLE_INLINE_SOURCE_MAPS` — force enable/disable source map resolution irrespective of dev environment.
- `CONSOLE_INLINE_SOURCE_MAP_PRELOAD` — enable/disable background Node source map preload queue.
- `CONSOLE_INLINE_SOURCE_MAP_MAX_QUEUE` — maximum number of Node map paths queued for preload.

## Advanced Usage

- `:ConsoleInlinePopup` — display the full console payload in a floating window for the message under cursor.

- Customize plugin options in your Neovim config
- Use environment variables to change TCP/WS ports
- See example projects in `examples/` for integration patterns

# Development

## Requirements

- Neovim 0.8+
- Node.js (for shims and relay)
- Mac, Linux, or Windows

## Testing

- Node.js: `npm install && npm test` (uses Vitest). Mapping tests validate presence of `mapping_status` in emitted payloads.
- Lua: Run tests in `tests/lua` with your preferred Lua test runner

## Contribution

Pull requests and issues are welcome! Please:

- Follow the coding style and conventions
- Add tests for new features or bug fixes
- Run linting (`.luacheckrc`, `selene.toml`) before submitting

### Developer setup

To keep the auto-relay bundle in sync before every commit, install the project hooks once:

```bash
pip install pre-commit  # or `brew install pre-commit`
pre-commit install
```

This registers the `build-relay` hook which runs `npm run build:relay` automatically. You can still regenerate it manually via that script or `:ConsoleInlineRelayBuild`.

## Browser Demo

See `examples/browser-vite` for a barebones Vite app that simply imports
`@console-inline/service` and emits a few `console.*` calls. Run it with:

```bash
cd examples/browser-vite
npm install
npm run dev
```

Open `main.ts` in Neovim and the plugin will render logs sourced from the page.

Before running the browser demo for the first time, run `npm run build:relay` to regenerate the bundled relay used by the Neovim plugin. Note: Node runtimes connect directly to the Neovim TCP server; browsers rely on the auto-started relay. Ensure the plugin is listening before importing the service.

## Publishing

Tagged releases following the pattern `@console-inline/service-v*` trigger the
GitHub Actions workflow that installs, builds, and publishes
`@console-inline/service` to npm. Double-check the package version in
`packages/service/package.json` before cutting a release.

## License

GPL-3.0-or-later. See [LICENSE](./LICENSE).
© 2025 Ioannis Karasavvaidis

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## Support

If console-inline.nvim saves you time, consider supporting development: [Buy Me a Coffee](https://buymeacoffee.com/comfucios).
