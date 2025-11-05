/*
 * Copyright (c) 2025 Ioannis Karasavvaidis
 * This file is part of console-inline.nvim
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// @console-inline/service: Patch console methods and send output to relay
// Auto-start relay server for Neovim integration (Node only)

// Import trace-mapping for browser source map support (will be bundled by Vite)
// @ts-ignore - Conditional import for browser environments
import * as traceMapping from "@jridgewell/trace-mapping";

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

// Returns explicit enable/disable override:
// - CONSOLE_INLINE_ENABLED=true => true
// - CONSOLE_INLINE_ENABLED=false => false
// - CONSOLE_INLINE_DISABLED=true => false
// - CONSOLE_INLINE_DISABLED=false => true (only if ENABLED not set)
// If neither is set (or both unset/unparseable) returns null.
const resolveExplicitToggle = (): boolean | null => {
  let enabledRaw: unknown = null;
  let disabledRaw: unknown = null;
  // Collect from process env / import.meta.env / globalThis
  if (typeof process !== "undefined" && process.env) {
    enabledRaw = process.env.CONSOLE_INLINE_ENABLED ?? enabledRaw;
    disabledRaw = process.env.CONSOLE_INLINE_DISABLED ?? disabledRaw;
  }
  if (typeof import.meta !== "undefined" && (import.meta as any).env) {
    const env = (import.meta as any).env;
    enabledRaw = env.CONSOLE_INLINE_ENABLED ?? enabledRaw;
    disabledRaw = env.CONSOLE_INLINE_DISABLED ?? disabledRaw;
  }
  if (typeof globalThis !== "undefined") {
    const g = globalThis as Record<string, unknown>;
    enabledRaw = g.CONSOLE_INLINE_ENABLED ?? enabledRaw;
    disabledRaw = g.CONSOLE_INLINE_DISABLED ?? disabledRaw;
  }
  const enabled = toBool(enabledRaw);
  if (enabled !== null) {
    return enabled; // direct interpretation
  }
  const disabled = toBool(disabledRaw);
  if (disabled !== null) {
    return disabled ? false : true; // disabled=true => false, disabled=false => true
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
if (!devEnvironment) {
  // One-time advisory when service loads but chooses inactivity.
  try {
    originalDebug(
      "[console-inline] inactive (devEnvironment=false) - set CONSOLE_INLINE_ENABLED=true to force enable",
    );
  } catch (_err) {
    /* ignore */
  }
}

const timers = new Map<string, number>();

type CallSite = {
  file: string;
  line: number;
  column: number;
  stack?: string;
  original_file?: string;
  original_line?: number;
  original_column?: number;
  mapping_status?: "hit" | "miss" | "pending";
};

type NetworkStage = "success" | "error";
type NetworkType = "fetch" | "xhr";

interface NetworkEventBase {
  type: NetworkType;
  method: string;
  url: string;
  status?: number;
  statusText?: string;
  ok?: boolean;
  duration_ms?: number;
  error?: string;
  stage: NetworkStage;
}

interface NetworkLogEvent extends NetworkEventBase {
  callsite: CallSite;
}

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

// ============================================================================
// Browser Source Map Resolution
// ============================================================================

// Cache for source maps and fetch promises
const browserSourceMapCache = new Map<string, any>(); // file URL -> parsed source map JSON
const browserMapFetchPromises = new Map<string, Promise<void>>(); // file URL -> ongoing fetch promise
let sourceMapInitialized = false;
let sourceMapsEnabledCache: boolean | null = null; // Memoize to avoid spam logging

// Check if source map resolution should be enabled
function shouldResolveBrowserSourceMaps(): boolean {
  if (sourceMapsEnabledCache !== null) return sourceMapsEnabledCache;

  if (!isBrowser) {
    sourceMapsEnabledCache = false;
    return false;
  }

  // Check for force-enable flag in globalThis
  if (
    typeof globalThis !== "undefined" &&
    (globalThis as any).__CONSOLE_INLINE_FORCE_SOURCEMAPS__
  ) {
    if (debugEnabled)
      originalDebug(
        "[console-inline] Source maps FORCE ENABLED via globalThis.__CONSOLE_INLINE_FORCE_SOURCEMAPS__",
      );
    sourceMapsEnabledCache = true;
    return true;
  }

  const env = typeof process !== "undefined" ? process.env : undefined;
  const toggle = env?.CONSOLE_INLINE_SOURCE_MAPS;
  if (toggle) {
    const val = toggle.trim().toLowerCase();
    if (["0", "false", "off", "no", "disabled"].includes(val)) {
      sourceMapsEnabledCache = false;
      return false;
    }
    if (["1", "true", "on", "yes", "enabled"].includes(val)) {
      sourceMapsEnabledCache = true;
      return true;
    }
  }
  // Enable by default in development environments (browser and Node)
  sourceMapsEnabledCache = devEnvironment;
  return devEnvironment;
}

// Fetch and cache source map for a given file URL
async function fetchBrowserSourceMap(fileUrl: string): Promise<void> {
  if (!shouldResolveBrowserSourceMaps()) return;

  const cacheKey = fileUrl;

  // Return existing map if cached
  if (browserSourceMapCache.has(cacheKey)) return;

  // Return existing fetch promise if in progress
  const existingFetch = browserMapFetchPromises.get(fileUrl);
  if (existingFetch) return existingFetch;

  // Create new fetch promise
  const fetchPromise = (async () => {
    try {
      debug(`[sourcemap] Fetching source map for: ${fileUrl}`);

      // Fetch the source file
      const response = await fetch(fileUrl);
      if (!response.ok) {
        debug(`[sourcemap] Failed to fetch file: ${response.status}`);
        browserSourceMapCache.set(cacheKey, null);
        return;
      }

      const sourceText = await response.text();

      // Look for sourceMappingURL comment
      const sourceMapUrlMatch = sourceText.match(
        /[#@]\s*sourceMappingURL\s*=\s*(\S+)/,
      );
      if (!sourceMapUrlMatch) {
        debug(`[sourcemap] No sourceMappingURL found in ${fileUrl}`);
        browserSourceMapCache.set(cacheKey, null);
        return;
      }

      const sourceMapRef = sourceMapUrlMatch[1];
      let sourceMapJson: any = null;

      if (sourceMapRef.startsWith("data:")) {
        // Inline source map (base64)
        debug(`[sourcemap] Found inline source map in ${fileUrl}`);
        const dataUrlMatch = sourceMapRef.match(
          /^data:application\/json;base64,(.+)$/,
        );
        if (dataUrlMatch) {
          try {
            const decoded = atob(dataUrlMatch[1]);
            sourceMapJson = JSON.parse(decoded);
            debug(`[sourcemap] Parsed inline source map for ${fileUrl}`);
          } catch (err) {
            debug(`[sourcemap] Failed to parse inline source map:`, err);
          }
        }
      } else {
        // External source map file
        const sourceMapUrl = new URL(sourceMapRef, fileUrl).href;
        debug(`[sourcemap] Fetching external source map: ${sourceMapUrl}`);
        try {
          const mapResponse = await fetch(sourceMapUrl);
          if (mapResponse.ok) {
            const mapText = await mapResponse.text();
            sourceMapJson = JSON.parse(mapText);
            debug(
              `[sourcemap] Parsed external source map from ${sourceMapUrl}`,
            );
          }
        } catch (err) {
          debug(`[sourcemap] Failed to fetch/parse external source map:`, err);
        }
      }

      browserSourceMapCache.set(cacheKey, sourceMapJson);
    } catch (err) {
      debug(`[sourcemap] Error fetching source map for ${fileUrl}:`, err);
      browserSourceMapCache.set(cacheKey, null);
    } finally {
      // Clean up fetch promise
      browserMapFetchPromises.delete(fileUrl);
    }
  })();

  // Store promise for coordination
  browserMapFetchPromises.set(fileUrl, fetchPromise);
  return fetchPromise;
}

// Preload source maps for common entry points on page load
async function preloadBrowserSourceMaps(): Promise<void> {
  if (!isBrowser || !shouldResolveBrowserSourceMaps() || sourceMapInitialized)
    return;

  sourceMapInitialized = true;
  if (debugEnabled)
    originalDebug(
      "[console-inline][sourcemap] ===== PRELOAD STARTED ===== devEnvironment:",
      devEnvironment,
      "isBrowser:",
      isBrowser,
    );
  debug(
    "[sourcemap] ===== PRELOAD STARTED ===== devEnvironment:",
    devEnvironment,
    "isBrowser:",
    isBrowser,
  );

  const urlsToPreload: string[] = [];

  // Collect script tags
  if (typeof document !== "undefined") {
    const scripts = document.querySelectorAll(
      'script[src], script[type="module"]',
    );
    for (const script of Array.from(scripts)) {
      const src = script.getAttribute("src");
      if (!src) continue;

      // Skip framework internals
      if (
        src.includes("node_modules") ||
        src.includes("@vite") ||
        src.includes("vite/dist")
      ) {
        continue;
      }

      try {
        const fullUrl = new URL(src, globalThis.location?.href).href;
        urlsToPreload.push(fullUrl);
      } catch (e) {
        // Ignore URL resolution errors
      }
    }
  }

  // Add common Vite entry points
  if (globalThis.location?.origin) {
    const commonPaths = [
      "/src/main.ts",
      "/src/main.tsx",
      "/src/index.ts",
      "/src/index.tsx",
      "/main.ts",
      "/main.tsx",
      "/index.ts",
      "/index.tsx",
      "/src/App.tsx",
      "/src/App.ts",
    ];

    for (const path of commonPaths) {
      urlsToPreload.push(globalThis.location.origin + path);
    }
  }

  if (debugEnabled)
    originalDebug(
      `[console-inline][sourcemap] Found ${urlsToPreload.length} URLs to preload:`,
      urlsToPreload,
    );
  debug(
    `[sourcemap] Found ${urlsToPreload.length} URLs to preload:`,
    urlsToPreload,
  );

  try {
    // Fetch all maps concurrently (ignore errors for speculative fetches)
    const results = await Promise.allSettled(
      urlsToPreload.map((url) => fetchBrowserSourceMap(url)),
    );

    const succeeded = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;
    if (debugEnabled)
      originalDebug(
        `[console-inline][sourcemap] ===== PRELOAD COMPLETE ===== ${succeeded} succeeded, ${failed} failed, cache size: ${browserSourceMapCache.size}`,
      );
    debug(
      `[sourcemap] ===== PRELOAD COMPLETE ===== ${succeeded} succeeded, ${failed} failed, cache size: ${browserSourceMapCache.size}`,
    );
  } catch (err) {
    originalDebug("[console-inline][sourcemap] ERROR in preload:", err);
    debug("[sourcemap] ERROR in preload:", err);
  }
}

// Normalize file URL for cache lookup (handle both full URLs and paths)
function normalizeFileUrl(fileUrl: string): string[] {
  const variants: string[] = [fileUrl]; // Always include original

  try {
    // If it's a path like "/main.ts", create full URL variant
    if (fileUrl.startsWith("/") && !fileUrl.startsWith("//")) {
      if (globalThis.location?.origin) {
        variants.push(globalThis.location.origin + fileUrl);
      }
    }

    // If it's a full URL, extract path variant
    if (fileUrl.startsWith("http://") || fileUrl.startsWith("https://")) {
      const url = new URL(fileUrl);
      variants.push(url.pathname);
    }
  } catch (e) {
    // Ignore URL parsing errors
  }

  return variants;
}

// Apply source map to transform generated coordinates to original
function applyBrowserSourceMap(
  fileUrl: string,
  generatedLine: number,
  generatedColumn: number,
): { source: string; line: number; column: number } | null {
  if (!shouldResolveBrowserSourceMaps()) return null;

  if (debugEnabled)
    originalDebug(
      `[console-inline][sourcemap] applyBrowserSourceMap called with: ${fileUrl}:${generatedLine}:${generatedColumn}`,
    );

  // Try to find source map with URL normalization
  const urlVariants = normalizeFileUrl(fileUrl);
  if (debugEnabled)
    originalDebug(
      `[console-inline][sourcemap] URL variants for lookup:`,
      urlVariants,
    );
  if (debugEnabled)
    originalDebug(
      `[console-inline][sourcemap] Cache has ${browserSourceMapCache.size} entries:`,
      Array.from(browserSourceMapCache.keys()),
    );

  let sourceMap: any = null;
  let matchedUrl: string | null = null;

  for (const variant of urlVariants) {
    if (browserSourceMapCache.has(variant)) {
      sourceMap = browserSourceMapCache.get(variant);
      matchedUrl = variant;
      break;
    }
  }

  if (!sourceMap) {
    if (debugEnabled)
      originalDebug(
        `[console-inline][sourcemap] NO MAP FOUND for any variant of ${fileUrl}`,
      );
    return null;
  }

  if (debugEnabled)
    originalDebug(
      `[console-inline][sourcemap] Found map for ${matchedUrl}, attempting to use trace-mapping...`,
    );

  try {
    // Use the imported trace-mapping library
    if (
      !traceMapping ||
      !traceMapping.TraceMap ||
      !traceMapping.originalPositionFor
    ) {
      if (debugEnabled)
        originalDebug(
          `[console-inline][sourcemap] trace-mapping not available`,
        );
      return null;
    }

    const { TraceMap, originalPositionFor } = traceMapping;
    const tracer = new TraceMap(sourceMap);

    // Note: trace-mapping uses 1-based line numbers
    const originalPos = originalPositionFor(tracer, {
      line: generatedLine,
      column: generatedColumn,
    });

    if (originalPos && originalPos.source && originalPos.line != null) {
      if (debugEnabled)
        originalDebug(
          `[console-inline][sourcemap] MAPPED ${fileUrl}:${generatedLine}:${generatedColumn} → ${originalPos.source}:${originalPos.line}:${originalPos.column}`,
        );
      return {
        source: originalPos.source,
        line: originalPos.line,
        column: originalPos.column ?? generatedColumn,
      };
    } else {
      if (debugEnabled)
        originalDebug(
          `[console-inline][sourcemap] originalPositionFor returned no valid position`,
        );
    }
  } catch (err) {
    if (debugEnabled)
      originalDebug(
        `[console-inline][sourcemap] Error applying source map:`,
        err,
      );
  }

  return null;
}

function captureCallSite(options?: { skip?: number }): CallSite {
  const skip = Math.max(0, options?.skip ?? 2);
  let file = "unknown";
  let line = 1;
  let column = 1;
  let stackString: string | undefined;
  try {
    const err = new Error();
    stackString =
      typeof err.stack === "string" && err.stack.length > 0
        ? err.stack
        : undefined;
    const stack = stackString?.split("\n");
    let best: { file: string; line: number; column: number } | null = null;
    if (stack && stack.length > skip) {
      for (let i = skip; i < stack.length; i++) {
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
  } catch (err) {
    debug("Error parsing stack trace", err);
  }

  // Apply browser source map transformation if available
  if (isBrowser && file !== "unknown" && shouldResolveBrowserSourceMaps()) {
    if (debugEnabled)
      originalDebug(
        `[console-inline][sourcemap] captureCallSite: attempting to map ${file}:${line}:${column}`,
      );
    debug(
      `[sourcemap] captureCallSite: attempting to map ${file}:${line}:${column}`,
    );
    const mapped = applyBrowserSourceMap(file, line, column);
    if (mapped) {
      if (debugEnabled)
        originalDebug(
          `[console-inline][sourcemap] MAPPED ${file}:${line}:${column} -> ${mapped.source}:${mapped.line}:${mapped.column}`,
        );
      debug(
        `[sourcemap] Mapped ${file}:${line}:${column} -> ${mapped.source}:${mapped.line}:${mapped.column}`,
      );
      return {
        file,
        line,
        column,
        stack: stackString,
        original_file: mapped.source,
        original_line: mapped.line,
        original_column: mapped.column,
        mapping_status: "hit",
      };
    } else {
      debug(`[sourcemap] No mapping found for ${file}:${line}:${column}`);
      return {
        file,
        line,
        column,
        stack: stackString,
        mapping_status: "miss",
      };
    }
  }

  // When source maps are explicitly disabled or not applicable, return with 'miss' status
  // This ensures mapping_status is always present when resolution was considered
  const needsStatus =
    isBrowser ||
    (isNode && process.env.CONSOLE_INLINE_SOURCE_MAPS !== undefined);
  if (needsStatus) {
    return {
      file,
      line,
      column,
      stack: stackString,
      mapping_status: "miss",
      original_file: file,
      original_line: line,
      original_column: column,
    };
  }

  return { file, line, column, stack: stackString };
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

const instrumentBrowserNetwork = (win: any) => {
  try {
    if (win.__console_inline_network_attached) {
      return;
    }
    win.__console_inline_network_attached = true;
  } catch (err) {
    debug("Failed to mark network instrumentation", err);
    return;
  }

  const fetchFn = win.fetch;
  if (typeof fetchFn === "function") {
    const originalFetch = fetchFn.bind(win);
    win.fetch = function (...fetchArgs: any[]) {
      const callsite = captureCallSite({ skip: 3 });
      const startedAt = timerNow();
      const info = resolveFetchRequest(fetchArgs);
      let result: any;
      try {
        result = originalFetch(...fetchArgs);
      } catch (error) {
        emitNetworkLog({
          type: "fetch",
          method: info.method,
          url: info.url,
          error: errorToMessage(error),
          duration_ms: timerNow() - startedAt,
          stage: "error",
          callsite,
        });
        throw error;
      }
      return Promise.resolve(result).then(
        (response: any) => {
          const duration = timerNow() - startedAt;
          const status =
            typeof response?.status === "number" ? response.status : undefined;
          const statusText =
            typeof response?.statusText === "string"
              ? response.statusText
              : undefined;
          const ok =
            typeof response?.ok === "boolean" ? response.ok : undefined;
          const finalUrl =
            response &&
            typeof response.url === "string" &&
            response.url.length > 0
              ? response.url
              : info.url;
          emitNetworkLog({
            type: "fetch",
            method: info.method,
            url: finalUrl,
            status,
            statusText,
            ok,
            duration_ms: duration,
            stage: "success",
            callsite,
          });
          return response;
        },
        (error: unknown) => {
          emitNetworkLog({
            type: "fetch",
            method: info.method,
            url: info.url,
            error: errorToMessage(error),
            duration_ms: timerNow() - startedAt,
            stage: "error",
            callsite,
          });
          throw error;
        },
      );
    } as any;
  }

  const XHR = win.XMLHttpRequest;
  if (typeof XHR === "function" && XHR.prototype) {
    const proto = XHR.prototype;
    const originalOpen = proto.open;
    const originalSend = proto.send;
    if (
      typeof originalOpen === "function" &&
      typeof originalSend === "function"
    ) {
      proto.open = function (
        this: XMLHttpRequest,
        method: string,
        url: string,
        ...rest: any[]
      ) {
        const meta =
          (this as any).__console_inline_network_meta__ ||
          ((this as any).__console_inline_network_meta__ = {});
        meta.method =
          typeof method === "string" && method ? method.toUpperCase() : "GET";
        if (typeof url === "string") {
          meta.url = url;
        } else if (url && typeof (url as any).toString === "function") {
          meta.url = (url as any).toString();
        }
        return originalOpen.apply(this, [method, url, ...rest]);
      };

      proto.send = function (this: XMLHttpRequest, ...sendArgs: any[]) {
        const xhr = this;
        const meta =
          (xhr as any).__console_inline_network_meta__ ||
          ((xhr as any).__console_inline_network_meta__ = {});
        meta.start = timerNow();
        meta.callsite = captureCallSite({ skip: 3 });
        meta.error = undefined;
        meta.emitted = false;

        const listeners: Array<[string, EventListener]> = [];
        const add = (event: string, handler: EventListener) => {
          xhr.addEventListener(event, handler);
          listeners.push([event, handler]);
        };
        const cleanup = () => {
          for (const [event, handler] of listeners) {
            xhr.removeEventListener(event, handler);
          }
          listeners.length = 0;
        };
        const finalize = (stage: NetworkStage, errorMessage?: string) => {
          if (meta.emitted) {
            return;
          }
          meta.emitted = true;
          cleanup();
          const status =
            typeof xhr.status === "number" && xhr.status !== 0
              ? xhr.status
              : undefined;
          const statusText =
            typeof xhr.statusText === "string" && xhr.statusText
              ? xhr.statusText
              : undefined;
          const finalUrl =
            typeof xhr.responseURL === "string" && xhr.responseURL
              ? xhr.responseURL
              : meta.url || "";
          const duration =
            typeof meta.start === "number" && Number.isFinite(meta.start)
              ? timerNow() - meta.start
              : undefined;
          const ok =
            typeof status === "number" && stage === "success"
              ? status >= 200 && status < 400
              : undefined;
          emitNetworkLog({
            type: "xhr",
            method: meta.method || "GET",
            url: finalUrl,
            status,
            statusText,
            ok,
            duration_ms: duration,
            error: errorMessage,
            stage,
            callsite: meta.callsite || captureCallSite({ skip: 3 }),
          });
        };

        const onLoad: EventListener = () => {
          finalize(meta.error ? "error" : "success", meta.error);
        };
        const onError: EventListener = () => {
          meta.error = "Network error";
          finalize("error", meta.error);
        };
        const onAbort: EventListener = () => {
          meta.error = "Request aborted";
          finalize("error", meta.error);
        };
        const onTimeout: EventListener = () => {
          meta.error = "Request timed out";
          finalize("error", meta.error);
        };
        const onLoadEnd: EventListener = () => {
          finalize(meta.error ? "error" : "success", meta.error);
        };

        add("load", onLoad);
        add("error", onError);
        add("abort", onAbort);
        add("timeout", onTimeout);
        add("loadend", onLoadEnd);

        try {
          return originalSend.apply(this, sendArgs);
        } catch (error) {
          meta.error = errorToMessage(error);
          finalize("error", meta.error);
          throw error;
        }
      };
    }
  }
};

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

  instrumentBrowserNetwork(win);
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
    lower.includes("/packages/service/") ||
    lower.includes("\\packages\\service\\") ||
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

function formatDuration(duration?: number): string {
  if (typeof duration !== "number" || !Number.isFinite(duration)) {
    return "";
  }
  const clamped = Math.max(0, duration);
  if (clamped >= 100) {
    return `${Math.round(clamped)} ms`;
  }
  return `${clamped.toFixed(1)} ms`;
}

function normalizeNetworkUrl(url: string): string {
  if (!url) {
    return "(unknown)";
  }
  try {
    if (typeof location !== "undefined" && location.origin) {
      const parsed = new URL(url, location.origin);
      if (parsed.origin === location.origin) {
        return parsed.pathname + parsed.search;
      }
      return parsed.href;
    }
    const parsed = new URL(url);
    return parsed.href;
  } catch {
    return url;
  }
}

function determineNetworkKind(
  event: NetworkEventBase,
): "info" | "warn" | "error" {
  if (event.error || event.stage === "error") {
    return "error";
  }
  if (typeof event.status === "number") {
    if (event.status >= 500) {
      return "error";
    }
    if (event.status >= 400) {
      return "warn";
    }
  }
  return "info";
}

function formatNetworkSummary(event: NetworkEventBase): string {
  const prefix = event.type === "fetch" ? "[fetch]" : "[xhr]";
  const method = (event.method || "GET").toUpperCase();
  const displayUrl = normalizeNetworkUrl(event.url);
  const base = `${prefix} ${method} ${displayUrl}`;
  let outcome: string | undefined;
  if (event.error) {
    outcome = `✖ ${event.error}`;
  } else if (typeof event.status === "number") {
    outcome = event.statusText
      ? `${event.status} ${event.statusText}`.trim()
      : `${event.status}`;
  }
  const duration = formatDuration(event.duration_ms);
  const parts = [base];
  if (outcome) {
    parts.push(`→ ${outcome}`);
  }
  if (duration) {
    parts.push(`(${duration})`);
  }
  return parts.join(" ");
}

function buildNetworkPayload(event: NetworkLogEvent) {
  const summary = formatNetworkSummary(event);
  const kind = determineNetworkKind(event);
  const details: Record<string, unknown> = {
    type: event.type,
    method: event.method,
    url: event.url,
    stage: event.stage,
  };
  if (typeof event.status === "number") {
    details.status = event.status;
  }
  if (event.statusText) {
    details.statusText = event.statusText;
  }
  if (typeof event.ok === "boolean") {
    details.ok = event.ok;
  }
  if (
    typeof event.duration_ms === "number" &&
    Number.isFinite(event.duration_ms)
  ) {
    details.duration_ms = event.duration_ms;
  }
  if (event.error) {
    details.error = event.error;
  }

  // Use mapped coordinates if available
  const file = event.callsite.original_file || event.callsite.file;
  const line = event.callsite.original_line || event.callsite.line;
  const column = event.callsite.original_column || event.callsite.column;

  if (event.callsite.original_file) {
    debug(
      `[sourcemap] NETWORK USING MAPPED: ${event.callsite.file}:${event.callsite.line} → ${file}:${line} [${event.callsite.mapping_status}]`,
    );
  }

  const payload: any = {
    method: event.type,
    kind,
    args: sanitizeArgs([summary, details]),
    file,
    line,
    column,
    stack: event.callsite.stack,
    network: {
      ...details,
      summary,
    },
  };

  return payload;
}

function emitNetworkLog(event: NetworkLogEvent) {
  try {
    const payload = buildNetworkPayload(event);
    sendToRelay(JSON.stringify(payload));
  } catch (err) {
    debug("Failed to emit network log", err);
  }
}

function resolveFetchRequest(args: any[]): { method: string; url: string } {
  const [input, init] = args;
  let method: string | undefined;
  let url = "";

  if (typeof input === "string") {
    url = input;
  } else if (typeof URL !== "undefined" && input instanceof URL) {
    url = input.toString();
  } else if (input && typeof input === "object") {
    const request = input as { url?: string; method?: string };
    if (request.url && typeof request.url === "string") {
      url = request.url;
    }
    if (request.method && typeof request.method === "string") {
      method = request.method;
    }
  }

  if (!method && init && typeof init === "object") {
    const initMethod = (init as { method?: string }).method;
    if (initMethod && typeof initMethod === "string") {
      method = initMethod;
    }
  }

  if (!method) {
    method = "GET";
  }

  return {
    method: method.toUpperCase(),
    url,
  };
}

function errorToMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message || error.name;
  }
  if (typeof error === "string") {
    return error;
  }
  if (error === undefined || error === null) {
    return "Unknown network error";
  }
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
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

      const callsite = captureCallSite({ skip: 2 });
      // Use mapped coordinates if available, otherwise fall back to generated coordinates
      const file = callsite.original_file || callsite.file;
      const line = callsite.original_line || callsite.line;
      const column = callsite.original_column || callsite.column;
      const stackString = callsite.stack;

      if (callsite.original_file) {
        if (debugEnabled)
          originalDebug(
            `[console-inline][sourcemap] USING MAPPED: ${callsite.file}:${callsite.line}:${callsite.column} → ${file}:${line}:${column} [${callsite.mapping_status}]`,
          );
        debug(
          `[sourcemap] USING MAPPED: ${callsite.file}:${callsite.line}:${callsite.column} → ${file}:${line}:${column} [${callsite.mapping_status}]`,
        );
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

      // Include source map metadata if available
      if (callsite.mapping_status) {
        payload.mapping_status = callsite.mapping_status;
      }
      if (callsite.original_file) {
        payload.original_file = callsite.original_file;
        payload.original_line = callsite.original_line;
        payload.original_column = callsite.original_column;
      }

      if (traceFrames && traceFrames.length > 0) {
        payload.trace = traceFrames;
      }
      if (timeMeta) {
        payload.time = timeMeta;
      }
      // Prevent recursive logging from service internals (relay-server, service itself, etc.)
      if (!isServiceFrame(file)) {
        sendToRelay(JSON.stringify(payload));
      }
      (orig as Function).apply(console, payloadArgs);
    };
  });
}

if (devEnvironment) {
  if (isBrowser) {
    originalDebug(
      "[console-inline] SERVICE LOADED - isBrowser:",
      isBrowser,
      "devEnvironment:",
      devEnvironment,
    );
    attachBrowserRuntimeHandlers();
    connectRelay();

    // Preload browser source maps for better coordinate mapping
    const sourceMapsEnabled = shouldResolveBrowserSourceMaps();
    if (debugEnabled)
      originalDebug(
        `[console-inline][sourcemap] Initialization: sourceMapsEnabled=${sourceMapsEnabled}, devEnvironment=${devEnvironment}`,
      );
    debug(
      `[sourcemap] Initialization: sourceMapsEnabled=${sourceMapsEnabled}, devEnvironment=${devEnvironment}`,
    );
    if (sourceMapsEnabled) {
      if (
        document.readyState === "complete" ||
        document.readyState === "interactive"
      ) {
        preloadBrowserSourceMaps();
      } else {
        window.addEventListener("DOMContentLoaded", () => {
          preloadBrowserSourceMaps();
        });
      }
    }
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
  formatNetworkSummary,
  determineNetworkKind,
  buildNetworkPayload,
  captureCallSite,
};
