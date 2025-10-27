// @console-inline/service: Patch console methods and send output to relay
// Auto-start relay server for Neovim integration (Node only)

// Detect runtime
const isBrowser =
  typeof window !== "undefined" && typeof window.document !== "undefined";
const isNode =
  typeof process !== "undefined" &&
  process.versions != null &&
  process.versions.node != null;

// Relay config
const RELAY_URL = "ws://localhost:36124";
const DEFAULT_RECONNECT_DELAY = 1000;
let relay: any = null;
const originalError = console.error.bind(console);
const originalDebug = console.log.bind(console);

const isTruthy = (value: unknown): boolean | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    if (Number.isNaN(value)) {
      return undefined;
    }
    return value !== 0;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed === "") {
      return undefined;
    }
    if (/^(0|false|off)$/i.test(trimmed)) {
      return false;
    }
    return true;
  }
  return true;
};

const debugEnabled = (() => {
  if (typeof process !== "undefined" && process.env) {
    const value = process.env.CONSOLE_INLINE_DEBUG;
    const result = isTruthy(value);
    if (result !== undefined) {
      return result;
    }
  }
  if (typeof globalThis !== "undefined") {
    const globalValue = (globalThis as Record<string, unknown>)
      .CONSOLE_INLINE_DEBUG;
    const result = isTruthy(globalValue);
    if (result !== undefined) {
      return result;
    }
  }
  return false;
})();

const debug = (...args: unknown[]) => {
  if (!debugEnabled) {
    return;
  }
  originalDebug("[console-inline]", ...args);
};

if (isNode) {
  try {
    require("./relay-server");
  } catch (err) {
    originalError("[console-inline] Failed to start relay server", err);
  }
}

const getNumber = (value: unknown): number | undefined => {
  if (typeof value === "number" && !Number.isNaN(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return undefined;
};

const reconnectDelay = (() => {
  const envValue =
    typeof process !== "undefined" && process.env
      ? getNumber(process.env.CONSOLE_INLINE_WS_RECONNECT_MS)
      : undefined;
  if (envValue && envValue > 0) {
    return envValue;
  }
  const globalValue =
    typeof globalThis !== "undefined"
      ? getNumber(
          (globalThis as Record<string, unknown>)
            .CONSOLE_INLINE_WS_RECONNECT_MS,
        )
      : undefined;
  if (globalValue && globalValue > 0) {
    return globalValue;
  }
  return DEFAULT_RECONNECT_DELAY;
})();

let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let nodeWebSocket: any = null;

const clearReconnectTimer = () => {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
};

const scheduleReconnect = (reason?: unknown) => {
  if (debugEnabled && reason) {
    debug("Relay reconnect scheduled", reason);
  }
  if (reconnectTimer) {
    return;
  }
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connectRelay();
  }, reconnectDelay);
};

const isOpen = (socket: any) => socket && socket.readyState === 1;
const isConnecting = (socket: any) => socket && socket.readyState === 0;

function connectRelay() {
  if (isOpen(relay) || isConnecting(relay)) {
    return;
  }

  if (isBrowser) {
    try {
      const ws = new WebSocket(RELAY_URL);
      relay = ws;
      ws.addEventListener("open", () => {
        debug("Relay connected");
        clearReconnectTimer();
      });
      ws.addEventListener("close", (event) => {
        debug("Relay closed", event);
        relay = null;
        scheduleReconnect(event);
      });
      ws.addEventListener("error", (evt) => {
        debug("Relay error", evt);
        relay = null;
        scheduleReconnect(evt);
        try {
          ws.close();
        } catch (_err) {
          // ignore
        }
      });
    } catch (err) {
      relay = null;
      scheduleReconnect(err);
    }
    return;
  }

  if (!isNode) {
    return;
  }

  if (!nodeWebSocket) {
    try {
      nodeWebSocket = require("ws");
    } catch (err) {
      originalError("[console-inline] Failed to load ws package:", err);
      nodeWebSocket = null;
      return;
    }
  }

  try {
    const ws = new nodeWebSocket(RELAY_URL);
    relay = ws;
    ws.on("open", () => {
      debug("Relay connected");
      clearReconnectTimer();
    });
    ws.on("close", () => {
      debug("Relay closed");
      relay = null;
      scheduleReconnect();
    });
    ws.on("error", (e: unknown) => {
      debug("Relay error", e);
      try {
        if (ws.readyState === 0 || ws.readyState === 1) {
          ws.close();
        }
      } catch (_err) {
        // ignore
      }
      relay = null;
      scheduleReconnect(e);
    });
  } catch (err) {
    relay = null;
    scheduleReconnect(err);
  }
}

function sendToRelay(msg: string) {
  if (relay && isOpen(relay)) {
    try {
      relay.send(msg);
      return;
    } catch (err) {
      debug("Relay send failed", err);
    }
  }
  connectRelay();
  scheduleReconnect();
}

function normalizePath(rawFile: string) {
  let file = rawFile.trim();
  const platform =
    typeof process !== "undefined" && process.platform
      ? process.platform
      : undefined;
  if (file.startsWith("file://")) {
    try {
      const url = new URL(file);
      file = url.pathname || file;
    } catch {
      file = file.slice("file://".length);
    }
    if (platform === "win32" && file.startsWith("/")) {
      file = file.slice(1);
    }
    try {
      file = decodeURIComponent(file);
    } catch {
      // ignore
    }
  }
  if (file.startsWith("webpack-internal://")) {
    file = file.replace("webpack-internal://", "");
  }
  return file;
}

function parseStackFrame(frame: string) {
  const trimmed = frame.trim();
  let match = trimmed.match(/\((.+):(\d+):(\d+)\)$/);
  if (!match) {
    match = trimmed.match(/at\s+(.+):(\d+):(\d+)$/);
  }
  if (!match) {
    match = trimmed.match(/(.+):(\d+):(\d+)$/);
  }
  if (!match) {
    return null;
  }
  const rawFile = normalizePath(match[1]);
  const lineNum = parseInt(match[2], 10);
  const columnNum = parseInt(match[3], 10);
  if (!rawFile || Number.isNaN(lineNum)) {
    return null;
  }
  return { file: rawFile, line: lineNum, column: columnNum };
}

function patchConsole() {
  ["log", "warn", "error", "info", "debug"].forEach((method) => {
    const orig = console[method as keyof typeof console];
    (console[method as keyof typeof console] as (...args: any[]) => void) = (
      ...args: any[]
    ) => {
      // Get stack trace for file/line
      let file = "unknown";
      let line = 1;
      try {
        const err = new Error();
        const stack = err.stack?.split("\n");
        if (stack && stack.length > 2) {
          for (let i = 2; i < stack.length; i++) {
            const frame = stack[i];
            const parsed = parseStackFrame(frame);
            if (!parsed) {
              continue;
            }
            const candidateFile = parsed.file;
            const candidateLine = parsed.line;
            const isInternal =
              candidateFile.includes("node_modules") ||
              candidateFile.includes("internal/") ||
              candidateFile.startsWith("node:") ||
              candidateFile.includes("bootstrap/");
            if (isInternal) {
              if (file === "unknown") {
                file = candidateFile;
                line = candidateLine;
              }
              continue;
            }
            file = candidateFile;
            line = candidateLine;
            break;
          }
        }
        if (file === "unknown" && stack) {
          debug("Could not parse file from stack", stack.join("\n"));
        }
      } catch (e) {
        debug("Error parsing stack trace", e);
      }
      // Map method to kind
      let kind = method;
      if (kind === "warn") kind = "warn";
      else if (kind === "error") kind = "error";
      else if (kind === "info") kind = "info";
      else kind = "log";
      const msgObj = { method, kind, args, file, line };
      // Prevent recursive logging from relay-server.js
      if (!file.endsWith("relay-server.js")) {
        sendToRelay(JSON.stringify(msgObj));
      }
      (orig as Function).apply(console, args);
    };
  });
}

connectRelay();
patchConsole();

// Optionally export API
export {};
