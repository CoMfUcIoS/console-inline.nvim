# console-inline.nvim

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

## Advanced Usage

- Customize plugin options in your Neovim config
- Use environment variables to change TCP/WS ports
- See example projects in `examples/` for integration patterns

## License

GPLv3 License. See LICENSE for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
![CI](https://github.com/comfucios/console-inline.nvim/actions/workflows/ci.yml/badge.svg)
![Lint](https://github.com/comfucios/console-inline.nvim/actions/workflows/lint.yml/badge.svg)

Zero-config Neovim plugin that shows `console.log/info/warn/error` inline as virtual text at the emitting source line.

![Browser demo with virtual text](images/screenshot-browser.png)
![Node demo with virtual text](images/screenshot-node.png)

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

---

## Features

- Inline display of `console.log`, `console.info`, `console.warn`, and `console.error` output directly at the source line in Neovim
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

### Service environment variables

`@console-inline/service` (and its in-process relay) respond to a few optional environment variables:

- `CONSOLE_INLINE_WS_RECONNECT_MS` — delay between WebSocket reconnect attempts (default `1000`).
- `CONSOLE_INLINE_MAX_QUEUE` — max messages to buffer while the TCP server is offline (default `200`; oldest entries are dropped first).
- `CONSOLE_INLINE_DEBUG` — enable verbose logging in both the service and relay for troubleshooting.

## Browser Demo

`npm run build:relay` — regenerate the auto-relay bundle used by Neovim when autostarting the relay.

See `examples/browser-vite` for a barebones Vite app that simply imports
`@console-inline/service` and emits a few `console.*` calls. Run it with:

```bash
cd examples/browser-vite
npm install
npm run dev
```

Open `main.ts` in Neovim and the plugin will render logs sourced from the page.

Before running the browser demo for the first time, run `npm run build:relay` to regenerate the bundled relay used by the Neovim plugin.
Note: Node runtimes connect directly to the Neovim TCP server; browsers rely on the auto-started relay. Ensure the plugin is listening before importing the service.

## Publishing

Tagged releases following the pattern `@console-inline/service-v*` trigger the
GitHub Actions workflow that installs, builds, and publishes
`@console-inline/service` to npm. Double-check the package version in
`packages/service/package.json` before cutting a release.
