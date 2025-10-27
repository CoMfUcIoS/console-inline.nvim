import "@console-inline/service";

const status = document.querySelector("#status");

console.log("browser demo ready");

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
