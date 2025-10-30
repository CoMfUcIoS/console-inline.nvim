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
calls on intervals—no custom relay or boilerplate required. Use the buttons on
the page to manually exercise `console.trace`, structured errors, a fetch
request that produces a `404`, and a paired `console.time`/`console.timeEnd`
sequence that measures the fetch duration. We also fire an unhandled promise
rejection and throw an uncaught error after a short delay so you can confirm
runtime failures surface inline before shipping.
