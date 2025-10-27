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

MIT License. See LICENSE for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
![CI](https://github.com/comfucios/console-inline.nvim/actions/workflows/ci.yml/badge.svg)
![Lint](https://github.com/comfucios/console-inline.nvim/actions/workflows/lint.yml/badge.svg)

Zero-config Neovim plugin that shows `console.log/info/warn/error` inline as virtual text at the emitting source line.
Includes a Node `--require` shim and optional browser shim.

## Features

- Inline display of `console.log`, `console.info`, `console.warn`, and `console.error` output directly at the source line in Neovim
- Works with Node.js, browser (via WebSocket relay), and ESM/CJS projects
- No configuration required for basic usage
- Supports persistent logs and queued messages
- Customizable severity filtering, throttling, and output length
- Provides CLI and shims for Node and browser environments
- Example projects for Node and browser (Vite)

## File Structure

- `plugin/console-inline.lua`: Neovim plugin entry point
- `lua/console_inline/`: Lua modules for state, server, rendering, commands
- `shim/node/console-inline-shim.cjs`: Node.js CommonJS shim
- `shim/browser/console-inline-shim.mjs`: Browser shim
- `tools/ws-relay.cjs`: WebSocket relay for browser logs
- `examples/`: Example Node and browser projects
- `tests/`: Lua and Node.js tests

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
