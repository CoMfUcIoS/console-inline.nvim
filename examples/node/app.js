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

setInterval(() => console.warn("tick", Date.now()), 1000);
setInterval(() => console.log("hi", Math.random()), 2000);
setInterval(() => console.error("error", new Error("oops")), 3000);
setInterval(() => console.info("pid", process.pid), 4000);

function nested(level = 0) {
  if (level >= 2) {
    console.trace("server trace demo");
    return;
  }
  nested(level + 1);
}

setInterval(() => nested(), 6000);

setInterval(() => {
  console.time("node-demo");
  setTimeout(() => {
    console.timeEnd("node-demo");
  }, 750);
}, 7000);

setTimeout(() => {
  Promise.reject(new Error("demo unhandled rejection"));
}, 9000);

setTimeout(() => {
  throw new Error("demo uncaught exception");
}, 12000);
