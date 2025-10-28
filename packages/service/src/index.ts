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
const TCP_HOST =
  (typeof process !== "undefined" && process.env?.CONSOLE_INLINE_HOST) ||
  "127.0.0.1";
const TCP_PORT = (() => {
  if (typeof process !== "undefined" && process.env?.CONSOLE_INLINE_PORT) {
    const parsed = Number(process.env.CONSOLE_INLINE_PORT);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return 36123;
})();
const MAX_QUEUE = (() => {
  if (typeof process !== "undefined" && process.env?.CONSOLE_INLINE_MAX_QUEUE) {
    const parsed = Number(process.env.CONSOLE_INLINE_MAX_QUEUE);
    if (!Number.isNaN(parsed)) {
      return Math.max(0, parsed);
    }
  }
  return 200;
})();
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
let netModulePromise: Promise<typeof import("node:net")> | null = null;
let tcpClient: any = null;
let tcpConnecting = false;
let tcpRetryTimer: ReturnType<typeof setTimeout> | null = null;
const tcpQueue: string[] = [];

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

const clearTcpRetry = () => {
  if (tcpRetryTimer) {
    clearTimeout(tcpRetryTimer);
    tcpRetryTimer = null;
  }
};

const scheduleTcpReconnect = () => {
  if (tcpRetryTimer) {
    return;
  }
  tcpRetryTimer = setTimeout(() => {
    tcpRetryTimer = null;
    connectTcp();
  }, reconnectDelay);
};

const enqueueTcp = (payload: string) => {
  if (MAX_QUEUE > 0 && tcpQueue.length >= MAX_QUEUE) {
    tcpQueue.shift();
  }
  tcpQueue.push(payload);
};

const flushTcpQueue = (socket: any) => {
  while (tcpQueue.length > 0) {
    const payload = tcpQueue.shift();
    if (payload !== undefined) {
      socket.write(payload + "\n");
    }
  }
};

function connectTcp() {
  if (!isNode) {
    return;
  }
  if (tcpConnecting || (tcpClient && !tcpClient.destroyed)) {
    return;
  }
  tcpConnecting = true;
  if (!netModulePromise) {
    netModulePromise = import("node:net");
  }
  netModulePromise
    .then((net) => {
      const socket = net.createConnection({ host: TCP_HOST, port: TCP_PORT });
      socket.setKeepAlive(true);
      socket.on("connect", () => {
        debug("TCP connected");
        tcpConnecting = false;
        tcpClient = socket;
        clearTcpRetry();
        flushTcpQueue(socket);
      });
      const handleFailure = (reason?: unknown) => {
        if (debugEnabled && reason) {
          debug("TCP connection issue", reason);
        }
        if (tcpClient === socket) {
          tcpClient = null;
        }
        socket.destroy();
        tcpConnecting = false;
        scheduleTcpReconnect();
      };
      socket.on("error", handleFailure);
      socket.on("close", handleFailure);
    })
    .catch((err) => {
      debug("Failed to load node:net", err);
      tcpConnecting = false;
      scheduleTcpReconnect();
    });
}

function connectRelay() {
  if (!isBrowser) {
    return;
  }
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
  if (isBrowser) {
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
    return;
  }

  if (isNode) {
    if (tcpClient && !tcpClient.destroyed) {
      try {
        tcpClient.write(msg + "\n");
        return;
      } catch (err) {
        debug("TCP send failed", err);
        tcpClient.destroy();
        tcpClient = null;
      }
    }
    enqueueTcp(msg);
    connectTcp();
    return;
  }
}

function normalizePath(rawFile: string) {
  let file = rawFile.trim();
  const platform =
    typeof process !== "undefined" && process.platform
      ? process.platform
      : undefined;
  if (file.startsWith("http://") || file.startsWith("https://")) {
    try {
      const url = new URL(file);
      file = url.pathname || file;
    } catch {
      // ignore
    }
  }
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

function isServiceFrame(file: string) {
  const lower = file.toLowerCase();
  return (
    lower.includes("@console-inline/service") ||
    lower.includes("console-inline_service") ||
    lower.includes("console-inline.nvim") ||
    lower.includes("auto-relay") ||
    lower.includes("relay-server")
  );
}

function sanitizeArgs(values: any[]) {
  const seen = new WeakSet<object>();
  const sanitize = (value: any): any => {
    if (value === undefined) {
      return "undefined";
    }
    if (value === null) {
      return null;
    }
    const type = typeof value;
    if (type === "number" || type === "boolean" || type === "string") {
      return value;
    }
    if (type === "bigint") {
      return value.toString() + "n";
    }
    if (type === "symbol") {
      return value.description ? `Symbol(${value.description})` : "Symbol()";
    }
    if (type === "function") {
      return value.toString();
    }
    if (value instanceof Error) {
      const plain: Record<string, unknown> = {
        name: value.name,
        message: value.message,
      };
      if (value.stack) {
        plain.stack = value.stack;
      }
      const cause = (value as any).cause;
      if (cause) {
        plain.cause = sanitize(cause);
      }
      for (const key of Object.getOwnPropertyNames(value)) {
        if (!(key in plain)) {
          try {
            plain[key] = sanitize((value as any)[key]);
          } catch (_err) {
            // ignore getters that throw
          }
        }
      }
      return plain;
    }
    if (value && typeof value === "object") {
      if (seen.has(value)) {
        return "[Circular]";
      }
      seen.add(value);
      if (Array.isArray(value)) {
        return value.map((item) => sanitize(item));
      }
      const out: Record<string, unknown> = {};
      for (const [key, val] of Object.entries(value)) {
        out[key] = sanitize(val);
      }
      return out;
    }
    return value;
  };

  return values.map((value) => sanitize(value));
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
      let column = 1;
      let stackString: string | undefined;
      try {
        const err = new Error();
        const stack = err.stack?.split("\n");
        stackString = err.stack ?? undefined;
        let best: { file: string; line: number; column: number } | null = null;
        if (stack && stack.length > 2) {
          for (let i = 2; i < stack.length; i++) {
            const frame = stack[i];
            const parsed = parseStackFrame(frame);
            if (!parsed) {
              continue;
            }
            const candidateFile = parsed.file;
            const candidateLine = parsed.line;
            const candidateColumn = parsed.column;
            const isInternal =
              candidateFile.includes("node_modules") ||
              candidateFile.includes("internal/") ||
              candidateFile.startsWith("node:") ||
              candidateFile.includes("bootstrap/") ||
              candidateFile.includes("/@vite/client") ||
              candidateFile.includes("vite/dist/client") ||
              isServiceFrame(candidateFile);
            if (isInternal) {
              if (file === "unknown") {
                file = candidateFile;
                line = candidateLine;
                column = candidateColumn;
              }
              continue;
            }
            if (
              !best ||
              candidateLine > best.line ||
              (candidateLine === best.line && candidateColumn > best.column)
            ) {
              best = {
                file: candidateFile,
                line: candidateLine,
                column: candidateColumn,
              };
            }
          }
        }
        if (best) {
          file = best.file;
          line = best.line;
          column = best.column;
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
      const payload = {
        method,
        kind,
        args: sanitizeArgs(args),
        file,
        line,
        column,
        stack: stackString,
      };
      // Prevent recursive logging from relay-server.js
      if (!file.endsWith("relay-server.js")) {
        sendToRelay(JSON.stringify(payload));
      }
      (orig as Function).apply(console, args);
    };
  });
}

if (isBrowser) {
  connectRelay();
} else if (isNode) {
  connectTcp();
}
patchConsole();

// Optionally export API
export {};
