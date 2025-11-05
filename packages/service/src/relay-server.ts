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

// Relay server: WebSocket → Neovim TCP

import http from "http";
import net from "net";
import { WebSocketServer } from "ws";
import fs from "fs";

const WS_PORT = Number(process.env.CONSOLE_INLINE_WS_PORT || 36124);
const TCP_HOST = process.env.CONSOLE_INLINE_HOST || "127.0.0.1";
const TCP_PORT = Number(process.env.CONSOLE_INLINE_PORT || 36123);
const LOG_PATH = process.env.CONSOLE_INLINE_LOG_PATH || "console-inline.log";
const LOG_FLUSH_MS = (() => {
  const raw = Number(process.env.CONSOLE_INLINE_LOG_FLUSH_MS || 100);
  if (Number.isNaN(raw) || raw < 0) return 100;
  return raw;
})();
const LOG_MAX_BYTES = (() => {
  const raw = Number(process.env.CONSOLE_INLINE_LOG_MAX_BYTES || 1_000_000); // ~1MB default
  if (Number.isNaN(raw) || raw < 1024) return 1_000_000;
  return raw;
})();
const LOG_MAX_FILES = (() => {
  const raw = Number(process.env.CONSOLE_INLINE_LOG_MAX_FILES || 3); // current + 2 rotated
  if (Number.isNaN(raw) || raw < 1) return 3;
  return raw;
})();
const RECONNECT_DELAY = Number(process.env.CONSOLE_INLINE_RECONNECT_MS || 1000);
const MAX_QUEUE_SIZE = (() => {
  const raw = Number(process.env.CONSOLE_INLINE_MAX_QUEUE || 200);
  if (Number.isNaN(raw)) {
    return 200;
  }
  return Math.max(0, raw);
})();

const isTruthy = (value: unknown): boolean => {
  if (value === undefined || value === null) {
    return false;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return !Number.isNaN(value) && value !== 0;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed === "") {
      return false;
    }
    return !/^(0|false|off)$/i.test(trimmed);
  }
  return true;
};

const debugEnabled = isTruthy(process.env.CONSOLE_INLINE_DEBUG);
const debug = (...args: unknown[]) => {
  if (!debugEnabled) {
    return;
  }
  console.log("[relay-server]", ...args);
};

const server = http.createServer();
const wss = new WebSocketServer({ server });

type Forwarder = {
  send: (payload: string) => void;
  dispose: () => void;
  ensure: () => void;
};

const createTcpForwarder = (): Forwarder => {
  let client: net.Socket | null = null;
  let connecting = false;
  let retryTimer: NodeJS.Timeout | null = null;
  const queue: string[] = [];
  let drops = 0;

  const clearRetry = () => {
    if (retryTimer) {
      clearTimeout(retryTimer);
      retryTimer = null;
    }
  };

  const scheduleReconnect = () => {
    if (retryTimer) {
      return;
    }
    retryTimer = setTimeout(() => {
      retryTimer = null;
      connect();
    }, RECONNECT_DELAY);
  };

  const flushQueue = (socket: net.Socket) => {
    while (queue.length > 0) {
      const msg = queue.shift();
      if (msg !== undefined) {
        socket.write(msg + "\n");
      }
    }
  };

  const handleFailure = (socket: net.Socket, err?: Error) => {
    if (err) {
      console.error("[relay-server] TCP client error:", err);
    } else {
      debug("TCP connection closed");
    }
    if (client === socket) {
      client.destroy();
      client.unref?.();
      client = null;
    } else {
      socket.destroy();
    }
    connecting = false;
    scheduleReconnect();
  };

  const connect = () => {
    if (connecting || (client && !client.destroyed)) {
      return;
    }
    connecting = true;
    debug(`Connecting to TCP ${TCP_HOST}:${TCP_PORT}`);
    const socket = net.createConnection({ host: TCP_HOST, port: TCP_PORT });
    socket.setKeepAlive(true);
    socket.on("connect", () => {
      debug("TCP connected");
      clearRetry();
      connecting = false;
      client = socket;
      flushQueue(socket);
    });
    socket.on("error", (err) => {
      handleFailure(socket, err);
    });
    socket.on("close", () => {
      handleFailure(socket);
    });
  };

  const enqueue = (payload: string) => {
    if (MAX_QUEUE_SIZE > 0 && queue.length >= MAX_QUEUE_SIZE) {
      queue.shift();
      drops++;
      if (drops === 1) {
        console.warn(
          `[relay-server] queue overflow – dropping messages (capacity ${MAX_QUEUE_SIZE}). Further drops will be aggregated.`,
        );
      } else if (drops % 100 === 0) {
        console.warn(
          `[relay-server] queue overflow ongoing – total dropped so far: ${drops}`,
        );
      }
    }
    queue.push(payload);
  };

  const send = (payload: string) => {
    if (client && !client.destroyed) {
      client.write(payload + "\n");
    } else {
      enqueue(payload);
      connect();
    }
  };

  const dispose = () => {
    clearRetry();
    if (client) {
      client.destroy();
      client.unref?.();
      client = null;
    }
    queue.length = 0;
  };

  const ensure = () => {
    connect();
  };

  return { send, dispose, ensure };
};

wss.on("connection", (socket) => {
  debug("New WebSocket connection");
  const forwarder = createTcpForwarder();
  forwarder.ensure();
  // Buffered async file logging
  let logBuffer: string[] = [];
  let flushTimer: NodeJS.Timeout | null = null;
  let pendingWrite = false;
  const rotateIfNeeded = (incomingBytes: number) => {
    try {
      let currentSize = 0;
      try {
        const stat = fs.statSync(LOG_PATH);
        currentSize = stat.size;
      } catch (_e) {
        return; // no file yet
      }
      if (currentSize + incomingBytes < LOG_MAX_BYTES) return;
      // Perform rotation: shift older files up
      for (let i = LOG_MAX_FILES - 1; i >= 1; i--) {
        const prev = i === 1 ? LOG_PATH : `${LOG_PATH}.${i - 1}`;
        const next = `${LOG_PATH}.${i}`;
        if (fs.existsSync(prev)) {
          try { fs.renameSync(prev, next); } catch (_err) {/* ignore */}
        }
      }
      // After rotation, new writes start fresh
    } catch (_err) {
      // ignore rotation errors
    }
  };
  const flushLogs = () => {
    if (pendingWrite) return; // avoid overlapping writes
    if (logBuffer.length === 0) return;
    const batch = logBuffer.join("");
    logBuffer = [];
    pendingWrite = true;
    rotateIfNeeded(Buffer.byteLength(batch));
    fs.appendFile(LOG_PATH, batch, (err) => {
      pendingWrite = false;
      if (err) {
        console.error("[relay-server] Failed async log append:", err);
      }
    });
  };
  const scheduleFlush = () => {
    if (flushTimer) return;
    flushTimer = setTimeout(() => {
      flushTimer = null;
      flushLogs();
    }, LOG_FLUSH_MS);
  };
  const immediateFlush = () => {
    if (flushTimer) {
      clearTimeout(flushTimer);
      flushTimer = null;
    }
    flushLogs();
  };
  socket.on("message", (data) => {
    let str = String(data);
    debug("Received message:", str);
    try {
      // Validate JSON
      JSON.parse(str);
      // Forward to TCP
      forwarder.send(str);
      debug("Forwarded to TCP:", str);
      // Buffer log for async flush
      logBuffer.push(str + "\n");
      if (logBuffer.length >= 100) {
        immediateFlush();
      } else {
        scheduleFlush();
      }
    } catch (e) {
      debug("Ignored non-JSON message:", str);
    }
  });
  socket.on("close", () => {
    debug("WebSocket closed");
    forwarder.dispose();
    immediateFlush();
  });
  socket.on("error", (err) => {
    console.error("[relay-server] WebSocket error:", err);
    forwarder.dispose();
    immediateFlush();
  });
});

server.listen(WS_PORT, () => {
  debug(`WebSocket: ws://127.0.0.1:${WS_PORT} → log file ${LOG_PATH}`);
});
