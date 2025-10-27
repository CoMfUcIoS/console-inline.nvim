/* eslint-disable */
const net = require("net");
const HOST = process.env.CONSOLE_INLINE_HOST || "127.0.0.1";
const PORT = Number(process.env.CONSOLE_INLINE_PORT || 36123);

let client = null;
function connect() {
  try {
    client = net.createConnection({ host: HOST, port: PORT });
    client.on("error", () => {});
  } catch (_) {}
}
connect();

function callsite() {
  const o = {};
  Error.captureStackTrace(o, callsite);
  const lines = (o.stack || "").split("\n").slice(1);
  const frame =
    lines.find((l) => !l.includes("console-inline-shim.js")) || lines[0] || "";
  const m = frame.match(/(?:at\s+.*\()?(.+?):(\d+):(\d+)\)?/);
  return m ? { file: m[1], line: Number(m[2]), col: Number(m[3]) } : {};
}

function safe(v) {
  const seen = new WeakSet();
  return JSON.stringify(v, function (k, value) {
    if (typeof value === "object" && value !== null) {
      if (seen.has(value)) return "[Circular]";
      seen.add(value);
    }
    if (value instanceof Error) {
      return { name: value.name, message: value.message, stack: value.stack };
    }
    return value;
  });
}

function send(kind, args) {
  const site = callsite();
  const payload = { kind, args, ...site, ts: Date.now() };
  try {
    if (!client || client.destroyed) connect();
    client && client.write(safe(payload) + "\n");
  } catch (_) {}
}

["log", "info", "warn", "error"].forEach((k) => {
  const orig = (console[k] && console[k].bind(console)) || function () {};
  console[k] = (...a) => {
    try {
      send(k, a);
    } catch (_) {}
    return orig(...a);
  };
});
