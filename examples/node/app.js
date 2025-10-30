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
