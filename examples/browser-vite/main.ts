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

import "@console-inline/service";

const status = document.querySelector("#status");
const traceButton = document.querySelector<HTMLButtonElement>("#trace-btn");
const errorButton = document.querySelector<HTMLButtonElement>("#error-btn");
const fetchButton = document.querySelector<HTMLButtonElement>("#fetch-btn");

console.info("browser demo ready");
console.debug("debug message to exercise lower severity logs");

let tick = 0;
setInterval(() => {
  tick += 1;
  console.log("console-inline tick", tick);
  if (!status) return;
  status.textContent = `Sent ${tick} messages`;
}, 1500);

setInterval(() => {
  console.warn("browser warning", new Date().toISOString());
}, 5000);

setInterval(() => {
  try {
    throw new Error("demo error");
  } catch (err) {
    console.error("captured error", err);
  }
}, 8000);

setTimeout(() => {
  void Promise.reject(new Error("demo unhandled rejection"));
}, 9000);

setTimeout(() => {
  throw new Error("uncaught browser error");
}, 11000);

function nestedTrace(depth = 0) {
  if (depth === 2) {
    console.trace("manual browser trace");
    return;
  }
  nestedTrace(depth + 1);
}

if (traceButton) {
  traceButton.addEventListener("click", () => {
    nestedTrace();
  });
}

if (errorButton) {
  errorButton.addEventListener("click", () => {
    console.error("manual error", new Error("Button-triggered error"));
  });
}

if (fetchButton) {
  fetchButton.addEventListener("click", async () => {
    const label = "fetch-button";
    console.time(label);
    const url = `/__console-inline-demo__?t=${Date.now()}`;
    try {
      const response = await fetch(url);
      if (response.ok) {
        console.info("fetch response", { url, status: response.status });
      } else {
        console.error("fetch non-ok", { url, status: response.status });
      }
    } catch (err) {
      console.error("fetch failed", err);
    } finally {
      console.timeEnd(label);
    }
  });
}
