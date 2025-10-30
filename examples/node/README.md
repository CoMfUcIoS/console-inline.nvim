# Node Demo

Small CLI app that exercises the most common console APIs used by
`console-inline.nvim` during manual testing.

## Run it

```bash
cd examples/node
npm install
npm start
```

Open `examples/node/app.js` in Neovim with the plugin enabled. Every few
seconds the script emits:

- `console.warn`, `console.log`, `console.info`, and `console.error`
- A nested `console.trace` call so you can verify inline stack rendering
- A `console.time`/`console.timeEnd` pair to confirm timing output behaviour
- An unhandled rejection and an uncaught exception (they’ll terminate the demo)
  so you can see runtime failures show up in Neovim before the process exits

Feel free to tweak intervals or add additional messages specific to your
project before cutting a release.
