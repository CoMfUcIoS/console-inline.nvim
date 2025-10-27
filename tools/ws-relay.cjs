/* eslint-disable */
// Dev-time bridge: WebSocket server that forwards to the Neovim TCP listener.
const http = require("http");
const net = require("net");
const { WebSocketServer } = require("ws");

const TCP_HOST = process.env.CONSOLE_INLINE_HOST || "127.0.0.1";
const TCP_PORT = Number(process.env.CONSOLE_INLINE_PORT || 36123);
const WS_PORT = Number(process.env.CONSOLE_INLINE_WS_PORT || 36124);

const server = http.createServer();
const wss = new WebSocketServer({ server });

wss.on("connection", (socket) => {
  const client = net.createConnection({ host: TCP_HOST, port: TCP_PORT });
  socket.on("message", (data) => {
    try {
      client.write(String(data) + "\n");
      // Persist log to file
      try {
        const fs = require("fs");
        fs.appendFileSync("console-inline.log", String(data) + "\n");
      } catch (e) {
        // Ignore file write errors
      }
    } catch {}
  });
  socket.on("close", () => client.destroy());
  socket.on("error", () => client.destroy());
  client.on("error", () => socket.close());
});

server.listen(WS_PORT, () => {
  console.log(
    `[ws-relay] WebSocket: ws://127.0.0.1:${WS_PORT} → TCP ${TCP_HOST}:${TCP_PORT}`,
  );
});
