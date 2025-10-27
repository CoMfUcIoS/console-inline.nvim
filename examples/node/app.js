import "@console-inline/service";

setInterval(() => console.warn("tick", Date.now()), 1000);
setInterval(() => console.log("hi", Math.random()), 2000);
setInterval(() => console.error("error", new Error("oops")), 3000);
