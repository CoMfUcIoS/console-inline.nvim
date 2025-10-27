import { expect, it } from "vitest";

function parse(frame) {
  const m = frame.match(/(?:at\s+.*\()?([^\s()]+):(\d+):(\d+)\)?/);
  return m ? { file: m[1], line: +m[2], col: +m[3] } : null;
}

it("parses v8 stack lines", () => {
  const s = "    at Object.<anonymous> (/a/b/c.js:10:2)";
  expect(parse(s)).toEqual({ file: "/a/b/c.js", line: 10, col: 2 });
});
