/* eslint-disable */
const net = require("net");
const fs = require("fs");
const HOST = process.env.CONSOLE_INLINE_HOST || "127.0.0.1";
const PORT = Number(process.env.CONSOLE_INLINE_PORT || 36123);
const DEBUG = !!process.env.CONSOLE_INLINE_DEBUG;

let client = null;
function connect() {
  try {
    client = net.createConnection({ host: HOST, port: PORT });
    client.on("error", () => {});
  } catch (_) {}
}
connect();

function normalizeFsPath(p) {
  try {
    if (!p) return p;
    if (p.startsWith("file://")) {
      const u = new URL(p);
      p = decodeURIComponent(u.pathname);
    }
    if (fs.realpathSync.native) return fs.realpathSync.native(p);
    return fs.realpathSync(p);
  } catch {
    return p;
  }
}

function extractPathLineCol(frame) {
  const s = String(frame).trim();
  // Prefer the LAST occurrence of "<path>:line:col"
  const re = /(file:\/\/\S+|\/[^:\s)]+(?:\/[^:\s)]+)*):(\d+):(\d+)\)?$/;
  const m = s.match(re);
  if (!m) return null;
  return { file: m[1], line: Number(m[2]), col: Number(m[3]) };
}

function callsite() {
  const o = {};
  Error.captureStackTrace(o, callsite);
  const lines = (o.stack || "")
    .split("\n")
    .map((l) => l.trim())
    .slice(1);
  let picked = lines.find(
    (l) =>
      !l.includes("console-inline-shim.cjs") &&
      !l.includes("console-inline-shim.js") &&
      !l.includes("node:internal"),
  );
  if (!picked) picked = lines[0] || "";
  const plc = extractPathLineCol(picked);
  if (!plc) return {};
  plc.file = normalizeFsPath(plc.file);
  return plc;
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
    if (DEBUG) process.stderr.write("[console-inline] " + safe(payload) + "\n");
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
