# console-inline.nvim

![CI](https://github.com/comfucios/console-inline.nvim/actions/workflows/ci.yml/badge.svg)
![Lint](https://github.com/comfucios/console-inline.nvim/actions/workflows/lint.yml/badge.svg)

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
  opts = {},
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
- `popup_formatter` — optional function(entry) -> lines used for popup formatting; defaults to prettifying JSON via `vim.inspect`.

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

- Node.js: `npm install && npm test` (uses Vitest)
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

MIT License. See LICENSE for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---
