# Browser Demo (Vite)

This example shows how little code is required to stream browser console output
into Neovim via `@console-inline/service`.

## Quick start

```bash
cd examples/browser-vite
npm install
npm run dev
```

Then open `examples/browser-vite/main.ts` in Neovim with the
`console-inline.nvim` plugin enabled. As the page emits logs, the plugin will
render them inline in the buffer.

The demo just imports `@console-inline/service` and triggers a few `console.*`
calls on intervals—no custom relay or boilerplate required.
