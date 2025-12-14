// Copyright (c) 2025 Ioannis Karasavvaidis
// This file is part of console-inline.nvim

// Deno shim for console-inline
// This shim is preloaded before the user script runs to inject console interception

import type { Conn } from "https://deno.land/std@0.208.0/net/mod.ts";

// Get relay server configuration from environment
const relayHost = Deno.env.get("CONSOLE_INLINE_HOST") || "127.0.0.1";
const relayPort = parseInt(Deno.env.get("CONSOLE_INLINE_PORT") || "36123");

// Store original console methods
const originalLog = console.log;
const originalWarn = console.warn;
const originalError = console.error;
const originalInfo = console.info;
const originalDebug = console.debug;
const originalTrace = console.trace;

// Create a minimal relay client to send messages to the Neovim relay server
class RelayClient {
  private socket: Conn | null = null;

  async connect(): Promise<void> {
    try {
      this.socket = await Deno.connect({
        hostname: relayHost,
        port: relayPort,
      });
    } catch (_e) {
      // Connection failed, will fall back to local console only
      console.log(
        "[console-inline] Warning: Could not connect to relay server"
      );
    }
  }

  async sendMessage(msg: unknown): Promise<void> {
    if (!this.socket) return;

    try {
      const json = JSON.stringify(msg);
      const encoder = new TextEncoder();
      const bytes = encoder.encode(json + "\n");
      await this.socket.write(bytes);
    } catch (_e) {
      // Silently fail if send fails
    }
  }

  close(): void {
    if (this.socket) {
      this.socket.close();
    }
  }
}

const client = new RelayClient();
let clientReady = false;

// Initialize connection
(async () => {
  await client.connect();
  clientReady = true;
})();

// Get the file that's being executed (first non-shim script in the call stack)
function getCallerFile(): string {
  const stack = new Error().stack || "";
  // Extract file from stack trace - typically the first .ts or .js file
  const match = stack.match(/at\s+([^:]+):(\d+):(\d+)/);
  if (match) {
    return match[1];
  }
  return "unknown";
}

// Get the line number of the caller
function getCallerLine(): number {
  const stack = new Error().stack || "";
  const match = stack.match(/at\s+[^:]+:(\d+):/);
  if (match) {
    return parseInt(match[1]);
  }
  return 0;
}

// Helper to convert arguments to JSON-serializable format
function serializeArgs(args: unknown[]): unknown[] {
  return args.map((arg) => {
    if (typeof arg === "string") return arg;
    if (typeof arg === "number") return arg;
    if (typeof arg === "boolean") return arg;
    if (arg === null) return null;
    if (arg === undefined) return "undefined";
    try {
      // Try to stringify objects
      JSON.stringify(arg);
      return arg;
    } catch {
      // Fallback for circular references and non-serializable objects
      return String(arg);
    }
  });
}

// Wrap console method
function wrapConsoleMethod(
  methodName: keyof Console,
  originalMethod: Function,
  kind: string
): void {
  (console as any)[methodName] = function (...args: unknown[]): void {
    // Call original to maintain expected behavior
    originalMethod.apply(console, args);

    // Send to relay if connected
    if (clientReady) {
      const msg = {
        file: getCallerFile(),
        line: getCallerLine(),
        kind,
        method: methodName,
        args: serializeArgs(args),
        timestamp: Date.now(),
      };
      client.sendMessage(msg).catch(() => {
        // Silently fail
      });
    }
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
Deno.addEventListener("unhandledrejection", (event: PromiseRejectionEvent) => {
  const msg = {
    file: getCallerFile(),
    line: getCallerLine(),
    kind: "error",
    method: "unhandledRejection",
    args: [String(event.reason)],
    timestamp: Date.now(),
  };
  client.sendMessage(msg).catch(() => {
    // Silently fail
  });
});

// Export nothing - this is just a side-effects module
export {};

