// Script to patch node_modules/vite/bin/vite.js to inject our vite-hook.js
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function findViteBin(startDir) {
  let dir = startDir;
  while (dir !== path.parse(dir).root) {
    const candidate = path.join(dir, "node_modules", "vite", "bin", "vite.js");
    if (fs.existsSync(candidate)) return candidate;
    dir = path.dirname(dir);
  }
  return null;
}

const startDir = process.env.INIT_CWD || process.cwd();
const viteBin = findViteBin(startDir);
console.log('DEBUG: Searching for viteBin from', startDir, '->', viteBin);

if (!viteBin) {
  console.error("Vite CLI not found in any parent node_modules.");
  process.exit(1);
}

const hookPath = path.join(__dirname, "vite-hook.js");
const requireLine = `import('${hookPath.replace(/\\/g, "/")}'); // console-inline injected\n`;

if (!fs.existsSync(viteBin)) {
  console.error("Vite CLI not found at", viteBin);
  process.exit(1);
}

const viteBinContent = fs.readFileSync(viteBin, "utf8");
if (viteBinContent.includes("console-inline injected")) {
  console.log("console-inline vite hook already injected.");
  process.exit(0);
}

const lines = viteBinContent.split("\n");
if (lines[0].startsWith("#!")) {
  lines.splice(1, 0, requireLine);
} else {
  lines.unshift(requireLine);
}

fs.writeFileSync(viteBin, lines.join("\n"), "utf8");
console.log("console-inline vite hook injected successfully.");
