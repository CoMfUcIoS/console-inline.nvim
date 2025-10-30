import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";

const originalNodeEnv = process.env.NODE_ENV;
const originalEnabled = process.env.CONSOLE_INLINE_ENABLED;
const originalDisabled = process.env.CONSOLE_INLINE_DISABLED;

async function loadTesting() {
  vi.resetModules();
  process.env.NODE_ENV = "production";
  delete process.env.CONSOLE_INLINE_ENABLED;
  delete process.env.CONSOLE_INLINE_DISABLED;
  const mod = await import("./index");
  const testing = (mod as any).__testing__;
  expect(testing).toBeTruthy();
  (globalThis as any).__console_inline_testing__ = testing;
  return testing as {
    isTruthy: (value: unknown) => boolean | undefined;
    toBool: (value: unknown) => boolean | null;
    resolveExplicitToggle: () => boolean | null;
    determineDevEnvironment: () => boolean;
    normalizePath: (input: string) => string;
    sanitizeArgs: (values: any[]) => any[];
    parseStackFrame: (
      frame: string,
    ) => { file: string; line: number; column: number } | null;
    getNumber: (value: unknown) => number | undefined;
    formatStackTrace: (stack?: string | null) => string[];
    timers: Map<string, number>;
    timerNow: () => number;
    browserQueue: string[];
    formatNetworkSummary: (event: any) => string;
    determineNetworkKind: (event: any) => string;
    buildNetworkPayload: (event: any) => any;
  };
}

afterAll(() => {
  process.env.NODE_ENV = originalNodeEnv;
  if (originalEnabled === undefined) delete process.env.CONSOLE_INLINE_ENABLED;
  else process.env.CONSOLE_INLINE_ENABLED = originalEnabled;
  if (originalDisabled === undefined)
    delete process.env.CONSOLE_INLINE_DISABLED;
  else process.env.CONSOLE_INLINE_DISABLED = originalDisabled;
  delete (globalThis as any).__console_inline_testing__;
});

describe("service helpers", () => {
  afterEach(() => {
    delete process.env.CONSOLE_INLINE_ENABLED;
    delete process.env.CONSOLE_INLINE_DISABLED;
    const testing = (globalThis as any).__console_inline_testing__;
    if (testing && Array.isArray(testing.browserQueue)) {
      testing.browserQueue.length = 0;
    }
    if (testing && testing.timers) {
      testing.timers.clear();
    }
  });

  it("evaluates truthiness correctly", async () => {
    const { isTruthy } = await loadTesting();
    expect(isTruthy(undefined)).toBeUndefined();
    expect(isTruthy("  ")).toBeUndefined();
    expect(isTruthy("0")).toBe(false);
    expect(isTruthy("off")).toBe(false);
    expect(isTruthy("true")).toBe(true);
    expect(isTruthy(0)).toBe(false);
    expect(isTruthy(1)).toBe(true);
  });

  it("parses boolean-ish values", async () => {
    const { toBool } = await loadTesting();
    expect(toBool(undefined)).toBeNull();
    expect(toBool("yes")).toBe(true);
    expect(toBool("no")).toBe(false);
    expect(toBool(1)).toBe(true);
    expect(toBool(0)).toBe(false);
    expect(toBool("foo")).toBeNull();
  });

  it("resolves explicit toggles", async () => {
    const { resolveExplicitToggle } = await loadTesting();
    process.env.CONSOLE_INLINE_ENABLED = "true";
    expect(resolveExplicitToggle()).toBe(true);
    process.env.CONSOLE_INLINE_ENABLED = "0";
    expect(resolveExplicitToggle()).toBe(false);
  });

  it("determines dev environment using NODE_ENV", async () => {
    const { determineDevEnvironment } = await loadTesting();
    process.env.NODE_ENV = "production";
    expect(determineDevEnvironment()).toBe(false);
    process.env.NODE_ENV = "development";
    expect(determineDevEnvironment()).toBe(true);
  });

  it("normalizes file URLs", async () => {
    const { normalizePath } = await loadTesting();
    expect(normalizePath("   file:///tmp/test.js  ")).toBe("/tmp/test.js");
    expect(normalizePath("https://example.com/src/app.ts")).toBe("/src/app.ts");
  });

  it("sanitizes complex arguments", async () => {
    const { sanitizeArgs } = await loadTesting();
    const error = new Error("boom");
    const obj: any = { foo: "bar" };
    obj.self = obj;
    const output = sanitizeArgs([undefined, error, obj]);
    expect(output[0]).toBe("undefined");
    expect(output[1]).toMatchObject({ name: "Error", message: "boom" });
    expect(output[1].stack).toBeTypeOf("string");
    expect(output[2].self).toBe("[Circular]");
  });

  it("parses stack frames", async () => {
    const { parseStackFrame } = await loadTesting();
    const parsed = parseStackFrame("at Object.fn (/tmp/file.js:12:34)");
    expect(parsed).toEqual({ file: "/tmp/file.js", line: 12, column: 34 });
    expect(parseStackFrame("invalid frame")).toBeNull();
  });

  it("formats stack traces", async () => {
    const { formatStackTrace } = await loadTesting();
    const sample = [
      "Error",
      "    at foo (/tmp/app.js:10:5)",
      "    at bar (/tmp/lib.js:2:3)",
      "    at Object.<anonymous> (/tmp/@console-inline/service/index.ts:1:1)",
    ].join("\n");
    expect(formatStackTrace(sample)).toEqual([
      "/tmp/app.js:10:5",
      "/tmp/lib.js:2:3",
    ]);
    expect(formatStackTrace(undefined)).toEqual([]);
  });

  it("extracts numeric values", async () => {
    const { getNumber } = await loadTesting();
    expect(getNumber(10)).toBe(10);
    expect(getNumber("20")).toBe(20);
    expect(getNumber("abc")).toBeUndefined();
  });

  it("exposes timer utilities", async () => {
    const { timers, timerNow, browserQueue } = await loadTesting();
    timers.clear();
    const value = timerNow();
    expect(value).toBeTypeOf("number");
    timers.set("demo", value);
    expect(timers.has("demo")).toBe(true);
    browserQueue.push("msg");
    expect(browserQueue.length).toBe(1);
  });
});

describe("network helpers", () => {
  it("formats network summaries", async () => {
    const { formatNetworkSummary } = await loadTesting();
    const summary = formatNetworkSummary({
      type: "fetch",
      method: "get",
      url: "https://example.com/api",
      status: 200,
      statusText: "OK",
      duration_ms: 150,
      stage: "success",
    });
    expect(summary).toBe(
      "[fetch] GET https://example.com/api → 200 OK (150 ms)",
    );
  });

  it("derives severity from status and errors", async () => {
    const { determineNetworkKind } = await loadTesting();
    expect(
      determineNetworkKind({
        type: "fetch",
        method: "GET",
        url: "https://example.com",
        status: 204,
        stage: "success",
      }),
    ).toBe("info");
    expect(
      determineNetworkKind({
        type: "xhr",
        method: "POST",
        url: "https://example.com",
        status: 404,
        stage: "success",
      }),
    ).toBe("warn");
    expect(
      determineNetworkKind({
        type: "fetch",
        method: "GET",
        url: "https://example.com",
        stage: "error",
        error: "boom",
      }),
    ).toBe("error");
  });

  it("builds network payloads", async () => {
    const { buildNetworkPayload } = await loadTesting();
    const payload = buildNetworkPayload({
      type: "xhr",
      method: "POST",
      url: "https://example.com/users",
      status: 404,
      statusText: "Not Found",
      duration_ms: 42.5,
      stage: "success",
      callsite: {
        file: "/src/users.ts",
        line: 32,
        column: 7,
      },
    });
    expect(payload.file).toBe("/src/users.ts");
    expect(payload.line).toBe(32);
    expect(payload.kind).toBe("warn");
    expect(payload.network.summary).toContain("POST");
    expect(payload.args[0]).toBeTypeOf("string");
    expect(payload.args[1]).toMatchObject({ status: 404, method: "POST" });
  });
});
