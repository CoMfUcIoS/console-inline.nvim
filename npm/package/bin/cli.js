#!/usr/bin/env node
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import { spawn } from "child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const shim = resolve(__dirname, "..", "console-inline-shim.cjs");

const idx = process.argv.findIndex((a) => a === "node");
const cmd = idx >= 0 ? process.argv[idx] : "node";
const rest = idx >= 0 ? process.argv.slice(idx + 1) : process.argv.slice(2);

const env = {
  ...process.env,
  NODE_OPTIONS: `${process.env.NODE_OPTIONS || ""} --require ${shim}`.trim(),
};
const child = spawn(cmd, rest, { stdio: "inherit", env });
child.on("exit", (code) => process.exit(code));
