// Browser shim -> sends logs over WebSocket to a local relay.
// NOTE: Neovim plugin speaks TCP only; use the provided ws-relay to bridge.
const HOST =
  (import.meta.env && import.meta.env.VITE_CONSOLE_INLINE_HOST) || "127.0.0.1";
const PORT = Number(
  (import.meta.env && import.meta.env.VITE_CONSOLE_INLINE_PORT) || 36124,
); // relay default
let ws;

function connect() {
  ws = new WebSocket(`ws://${HOST}:${PORT}`);
  ws.onclose = () => setTimeout(connect, 1000);
}
connect();

function extractPathLineCol() {
  try {
    const e = new Error();
    const lines = (e.stack || "")
      .split("\n")
      .map((l) => l.trim())
      .slice(1);
    // pick first non-internal
    let picked =
      lines.find((l) => !l.includes("console-inline-shim.mjs")) ||
      lines[0] ||
      "";
    // match "... (/path/or/file:///...:line:col)"
    let m = picked.match(/\(?([^)]+):(\d+):(\d+)\)?$/);
    if (!m) return {};
    let file = m[1];
    // strip "file://" scheme if present
    if (file.startsWith("file://")) {
      try {
        file = new URL(file).pathname;
      } catch {}
    }
    return { file, line: Number(m[2]), col: Number(m[3]) };
  } catch {
    return {};
  }
}

function send(kind, args) {
  try {
    const plc = extractPathLineCol();
    const payload = { kind, args, ...plc, ts: Date.now() };
    if (ws && ws.readyState === 1) ws.send(JSON.stringify(payload));
  } catch {}
}

["log", "info", "warn", "error"].forEach((k) => {
  const orig = console[k].bind(console);
  console[k] = (...a) => {
    try {
      send(k, a);
    } catch {}
    return orig(...a);
  };
});
