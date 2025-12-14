// Copyright (c) 2025 Ioannis Karasavvaidis
// This file is part of console-inline.nvim

// Bun shim for console-inline
// This shim is preloaded before the user script runs to inject console interception

// Get relay server configuration from environment
const relayHost = process.env.CONSOLE_INLINE_HOST || "127.0.0.1";
const relayPort = parseInt(process.env.CONSOLE_INLINE_PORT || "36123");

// Store original console methods
const originalLog = console.log;
const originalWarn = console.warn;
const originalError = console.error;
const originalInfo = console.info;
const originalDebug = console.debug;
const originalTrace = console.trace;

// Create a minimal relay client to send messages to the Neovim relay server
class RelayClient {
  private socket: any = null;
  private connected = false;

  constructor() {
    this.connect();
  }

  private async connect(): Promise<void> {
    try {
      const net = await import("net");
      this.socket = net.createConnection({
        host: relayHost,
        port: relayPort,
      });
      this.socket.on("connect", () => {
        this.connected = true;
      });
      this.socket.on("error", () => {
        this.connected = false;
      });
    } catch (_e) {
      // Connection failed, will fall back to local console only
      originalLog("[console-inline] Warning: Could not connect to relay server");
    }
  }

  sendMessage(msg: object): void {
    if (!this.connected || !this.socket) return;

    try {
      const json = JSON.stringify(msg);
      this.socket.write(json + "\n");
    } catch (_e) {
      // Silently fail if send fails
    }
  }

  close(): void {
    if (this.socket) {
      this.socket.destroy();
    }
  }
}

const client = new RelayClient();

// Get the file that's being executed (first non-shim script in the call stack)
function getCallerFile(): string {
  const stack = new Error().stack || "";
  // Extract file from stack trace
  const lines = stack.split("\n");
  for (const line of lines) {
    // Skip shim file itself
    if (line.includes("console-inline-shim")) continue;
    const match = line.match(/at\s+(?:\w+\s+)?(\S+):(\d+):(\d+)/);
    if (match) {
      return match[1];
    }
  }
  return "unknown";
}

// Get the line number of the caller
function getCallerLine(): number {
  const stack = new Error().stack || "";
  const lines = stack.split("\n");
  for (const line of lines) {
    if (line.includes("console-inline-shim")) continue;
    const match = line.match(/:(\d+):/);
    if (match) {
      return parseInt(match[1]);
    }
  }
  return 0;
}

// Helper to convert arguments to JSON-serializable format
function serializeArgs(args: any[]): any[] {
  return args.map((arg) => {
    if (
      typeof arg === "string" ||
      typeof arg === "number" ||
      typeof arg === "boolean"
    ) {
      return arg;
    }
    if (arg === null) return null;
    if (arg === undefined) return "undefined";
    try {
      // Try to stringify objects
      JSON.stringify(arg);
      return arg;
    } catch {
      // Fallback for circular references
      return String(arg);
    }
  });
}

// Wrap each console method
function wrapConsoleMethod(
  methodName: string,
  originalMethod: Function,
  kind: string
): void {
  (console as any)[methodName] = function (...args: any[]): void {
    // Call original to maintain expected behavior
    originalMethod.apply(console, args);

    // Send to relay
    const msg = {
      file: getCallerFile(),
      line: getCallerLine(),
      kind,
      method: methodName,
      args: serializeArgs(args),
      timestamp: Date.now(),
    };
    client.sendMessage(msg);
  };
}

// Wrap all console methods
wrapConsoleMethod("log", originalLog, "log");
wrapConsoleMethod("warn", originalWarn, "warn");
wrapConsoleMethod("error", originalError, "error");
wrapConsoleMethod("info", originalInfo, "info");
wrapConsoleMethod("debug", originalDebug, "debug");
wrapConsoleMethod("trace", originalTrace, "trace");

// Intercept unhandled promise rejections
process.on("unhandledRejection", (reason) => {
  const msg = {
    file: getCallerFile(),
    line: getCallerLine(),
    kind: "error",
    method: "unhandledRejection",
    args: [String(reason)],
    timestamp: Date.now(),
  };
  client.sendMessage(msg);
});

// Intercept uncaught exceptions
process.on("uncaughtException", (error) => {
  const msg = {
    file: getCallerFile(),
    line: getCallerLine(),
    kind: "error",
    method: "uncaughtException",
    args: [String(error)],
    timestamp: Date.now(),
  };
  client.sendMessage(msg);
});

export {};

