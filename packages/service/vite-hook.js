// This file is injected into Vite CLI by the injector script
// It adds a middleware to inject the @console-inline/service client into all HTML responses

import fs from 'fs';
import path from 'path';

// Find the project root (where node_modules is)
function findProjectRoot() {
  let dir = process.cwd();
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, 'node_modules'))) return dir;
    dir = path.dirname(dir);
  }
  return process.cwd();
}

const projectRoot = findProjectRoot();
const clientScript = path.join(projectRoot, 'node_modules', '@console-inline', 'service', 'dist', 'index.js');

// Patch Vite's createServer to inject our middleware
try {
  const vite = await import('vite');
  const origCreateServer = vite.createServer;
  vite.createServer = async function(...args) {
    const server = await origCreateServer.apply(this, args);
    server.middlewares.use((req, res, next) => {
      if (req.url && req.url.endsWith('.html')) {
        let _end = res.end;
        let chunks = [];
        res.write = function(chunk) {
          chunks.push(Buffer.from(chunk));
        };
        res.end = function(chunk) {
          if (chunk) chunks.push(Buffer.from(chunk));
          let body = Buffer.concat(chunks).toString('utf8');
          // Inject the client script before </body>
          if (fs.existsSync(clientScript)) {
            const injectTag = `<script type=\"module\" src=\"/node_modules/@console-inline/service/dist/index.js\"></script>`;
            body = body.replace('</body>', `${injectTag}</body>`);
          }
          res.setHeader('content-length', Buffer.byteLength(body));
          _end.call(res, body);
        };
      }
      next();
    });
    return server;
  };
} catch (e) {
  // If vite is not installed, do nothing
}
