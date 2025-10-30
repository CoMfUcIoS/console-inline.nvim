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

const toBool = (value: unknown): boolean | null => {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    if (Number.isNaN(value)) return null;
    return value !== 0;
  }
  if (typeof value === "string") {
    const trimmed = value.trim().toLowerCase();
    if (!trimmed) return null;
    if (["true", "1", "yes", "on", "force", "enabled"].includes(trimmed))
      return true;
    if (["false", "0", "no", "off", "disabled"].includes(trimmed)) return false;
  }
  return null;
};

const resolveExplicitToggle = (): boolean | null => {
  const candidates: unknown[] = [];
  if (typeof process !== "undefined" && process.env) {
    candidates.push(process.env.CONSOLE_INLINE_ENABLED);
    candidates.push(process.env.CONSOLE_INLINE_DISABLED);
  }
  if (typeof import.meta !== "undefined" && (import.meta as any).env) {
    const env = (import.meta as any).env;
    candidates.push(env.CONSOLE_INLINE_ENABLED);
    candidates.push(env.CONSOLE_INLINE_DISABLED);
  }
  if (typeof globalThis !== "undefined") {
    const g = globalThis as Record<string, unknown>;
    candidates.push(g.CONSOLE_INLINE_ENABLED);
    candidates.push(g.CONSOLE_INLINE_DISABLED);
  }
  for (const value of candidates) {
    const bool = toBool(value);
    if (bool !== null) {
      return bool;
    }
  }
  return null;
};

const determineDevEnvironment = (): boolean => {
  const explicit = resolveExplicitToggle();
  if (explicit !== null) {
    return explicit;
  }
  if (isNode) {
    const env =
      typeof process !== "undefined" && process.env
        ? process.env.NODE_ENV
        : undefined;
    if (env) {
      return env !== "production";
    }
  }
  if (isBrowser) {
    const metaEnv =
      typeof import.meta !== "undefined" ? (import.meta as any).env : undefined;
    if (metaEnv) {
      if (typeof metaEnv.DEV !== "undefined") {
        return !!metaEnv.DEV;
      }
      if (typeof metaEnv.PROD !== "undefined") {
        return !metaEnv.PROD;
      }
    }
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

const devEnvironment = determineDevEnvironment();

const timers = new Map<string, number>();

const timerNow = (() => {
  if (
    typeof performance !== "undefined" &&
    typeof performance.now === "function"
  ) {
    return () => performance.now();
  }
  if (typeof process !== "undefined") {
    const hr = (process as any).hrtime;
    if (typeof hr === "function") {
      if (typeof hr.bigint === "function") {
        const origin = hr.bigint();
        return () => Number(hr.bigint() - origin) / 1e6;
      }
      return () => {
        const [sec, nano] = hr();
        return sec * 1e3 + nano / 1e6;
      };
    }
  }
  return () => Date.now();
})();

const getTimerLabel = (args: any[]): string => {
  if (args && typeof args[0] === "string" && args[0].trim() !== "") {
    return args[0];
  }
  return "default";
};

const emitRuntimeMessage = (details: {
  method: string;
  args: any[];
  file?: string | null;
  line?: number | null;
  column?: number | null;
  stack?: string | null;
}) => {
  const file = details.file ? normalizePath(details.file) : "unknown";
  const line =
    details.line && Number.isFinite(details.line)
      ? (details.line as number)
      : 1;
  const column =
    details.column && Number.isFinite(details.column)
      ? (details.column as number)
      : 1;
  const payload: any = {
    method: details.method,
    kind: "error",
    args: sanitizeArgs(details.args || []),
    file,
    line,
    column,
    stack: details.stack || undefined,
  };
  sendToRelay(JSON.stringify(payload));
};

const parseFromStack = (stack?: string | null) => {
  if (!stack) {
    return {
      file: undefined,
      line: undefined,
      column: undefined,
      stack: undefined,
    };
  }
  const frames = stack.split("\n");
  for (let i = 1; i < frames.length; i++) {
    const parsed = parseStackFrame(frames[i]);
    if (parsed) {
      return {
        file: parsed.file,
        line: parsed.line,
        column: parsed.column,
        stack,
      };
    }
  }
  return { file: undefined, line: undefined, column: undefined, stack };
};

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
const browserQueue: string[] = [];

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

const flushBrowserQueue = (ws: any) => {
  while (browserQueue.length > 0) {
    const payload = browserQueue.shift();
    if (payload !== undefined) {
      try {
        ws.send(payload);
      } catch (err) {
        debug("Browser relay send failed", err);
        break;
      }
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
        flushBrowserQueue(ws);
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
      flushBrowserQueue(ws);
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
    if (MAX_QUEUE > 0 && browserQueue.length >= MAX_QUEUE) {
      browserQueue.shift();
    }
    browserQueue.push(msg);
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

const attachBrowserRuntimeHandlers = () => {
  if (!isBrowser || typeof window === "undefined") {
    return;
  }
  const win = window as any;
  if (win.__console_inline_runtime_attached) {
    return;
  }
  win.__console_inline_runtime_attached = true;

  const previousOnError = win.onerror;
  win.onerror = function (
    message: any,
    source?: string,
    lineno?: number,
    colno?: number,
    error?: Error,
  ) {
    try {
      const stack =
        error && typeof error.stack === "string" ? error.stack : undefined;
      const parsed = parseFromStack(stack);
      emitRuntimeMessage({
        method: "window.onerror",
        args: error ? [message, error] : [message],
        file: source || parsed.file || undefined,
        line: lineno ?? parsed.line ?? undefined,
        column: colno ?? parsed.column ?? undefined,
        stack: stack || parsed.stack || undefined,
      });
    } catch (err) {
      debug("window.onerror capture failed", err);
    }
    if (typeof previousOnError === "function") {
      return previousOnError.apply(this, arguments as any);
    }
    return false;
  };

  win.addEventListener("unhandledrejection", (event: PromiseRejectionEvent) => {
    try {
      const reason = event.reason;
      const stack =
        reason && typeof (reason as any).stack === "string"
          ? (reason as any).stack
          : undefined;
      const parsed = parseFromStack(stack);
      emitRuntimeMessage({
        method: "window.unhandledrejection",
        args: [reason],
        file: parsed.file,
        line: parsed.line,
        column: parsed.column,
        stack: parsed.stack,
      });
    } catch (err) {
      debug("unhandledrejection capture failed", err);
    }
  });
};

const attachNodeRuntimeHandlers = () => {
  if (!isNode || typeof process === "undefined") {
    return;
  }
  const proc = process as any;
  if (proc.__console_inline_runtime_attached) {
    return;
  }
  proc.__console_inline_runtime_attached = true;

  if (typeof proc.on === "function") {
    proc.on("uncaughtExceptionMonitor", (error: Error) => {
      const parsed = parseFromStack(error && error.stack);
      emitRuntimeMessage({
        method: "process.uncaughtException",
        args: [error],
        file: parsed.file,
        line: parsed.line,
        column: parsed.column,
        stack: parsed.stack,
      });
    });

    proc.on("unhandledRejection", (reason: unknown, promise: unknown) => {
      const stack =
        reason && typeof (reason as any).stack === "string"
          ? (reason as any).stack
          : undefined;
      const parsed = parseFromStack(stack);
      emitRuntimeMessage({
        method: "process.unhandledRejection",
        args: [reason, promise],
        file: parsed.file,
        line: parsed.line,
        column: parsed.column,
        stack: parsed.stack,
      });
      originalError("[console-inline] Unhandled promise rejection", reason);
    });
  }
};

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

function formatStackTrace(stack?: string | null) {
  if (!stack) {
    return [] as string[];
  }
  const frames: string[] = [];
  const lines = stack.split("\n").slice(1); // omit the "Error" line
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      continue;
    }
    const parsed = parseStackFrame(trimmed);
    if (parsed) {
      if (isServiceFrame(parsed.file)) {
        continue;
      }
      frames.push(`${parsed.file}:${parsed.line}:${parsed.column}`);
    } else if (!trimmed.includes("@console-inline/service")) {
      frames.push(trimmed);
    }
  }
  return frames;
}

function patchConsole() {
  [
    "log",
    "warn",
    "error",
    "info",
    "debug",
    "trace",
    "time",
    "timeEnd",
    "timeLog",
  ].forEach((method) => {
    const orig = console[method as keyof typeof console];
    (console[method as keyof typeof console] as (...args: any[]) => void) = (
      ...args: any[]
    ) => {
      if (method === "time") {
        const label = getTimerLabel(args);
        timers.set(label, timerNow());
        (orig as Function).apply(console, args);
        return;
      }

      let payloadArgs = args;
      let timeMeta: {
        label: string;
        duration_ms?: number;
        missing?: boolean;
        kind: "timeEnd" | "timeLog";
      } | null = null;

      if (method === "timeEnd" || method === "timeLog") {
        const label = getTimerLabel(args);
        const start = timers.get(label);
        if (typeof start === "number") {
          const duration = timerNow() - start;
          if (method === "timeEnd") {
            timers.delete(label);
          }
          timeMeta = {
            label,
            duration_ms: duration,
            kind: method,
          };
          const formatted = `${label}: ${duration.toFixed(3)} ms`;
          payloadArgs = [formatted, ...args.slice(1)];
        } else {
          timeMeta = {
            label,
            missing: true,
            kind: method,
          };
          payloadArgs = [`Timer '${label}' does not exist`];
        }
      }

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
      const isTrace = method === "trace";
      const traceFrames = isTrace ? formatStackTrace(stackString) : undefined;
      const payload: any = {
        method,
        kind,
        args: sanitizeArgs(payloadArgs),
        file,
        line,
        column,
        stack: stackString,
      };
      if (traceFrames && traceFrames.length > 0) {
        payload.trace = traceFrames;
      }
      if (timeMeta) {
        payload.time = timeMeta;
      }
      // Prevent recursive logging from relay-server.js
      if (!file.endsWith("relay-server.js")) {
        sendToRelay(JSON.stringify(payload));
      }
      (orig as Function).apply(console, payloadArgs);
    };
  });
}

if (devEnvironment) {
  if (isBrowser) {
    attachBrowserRuntimeHandlers();
    connectRelay();
  } else if (isNode) {
    attachNodeRuntimeHandlers();
    connectTcp();
  }
  patchConsole();
}

// Optionally export API
export {};

export const __testing__ = {
  isTruthy,
  toBool,
  resolveExplicitToggle,
  determineDevEnvironment,
  normalizePath,
  sanitizeArgs,
  parseStackFrame,
  getNumber,
  formatStackTrace,
  timers,
  timerNow,
  browserQueue,
};
