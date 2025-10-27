import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import { pathToFileURL } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const actual = resolve(
  __dirname,
  "..",
  "..",
  "shim",
  "node",
  "console-inline-shim.js",
);
await import(pathToFileURL(actual).href);
