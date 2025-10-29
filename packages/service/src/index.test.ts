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
  };
}

afterAll(() => {
  process.env.NODE_ENV = originalNodeEnv;
  if (originalEnabled === undefined) delete process.env.CONSOLE_INLINE_ENABLED;
  else process.env.CONSOLE_INLINE_ENABLED = originalEnabled;
  if (originalDisabled === undefined)
    delete process.env.CONSOLE_INLINE_DISABLED;
  else process.env.CONSOLE_INLINE_DISABLED = originalDisabled;
});

describe("service helpers", () => {
  afterEach(() => {
    delete process.env.CONSOLE_INLINE_ENABLED;
    delete process.env.CONSOLE_INLINE_DISABLED;
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

  it("extracts numeric values", async () => {
    const { getNumber } = await loadTesting();
    expect(getNumber(10)).toBe(10);
    expect(getNumber("20")).toBe(20);
    expect(getNumber("abc")).toBeUndefined();
  });
});
