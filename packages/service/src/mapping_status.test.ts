import { describe, it, expect, beforeEach } from "vitest";
// Declare Node globals to avoid needing @types/node in this lightweight test
declare var process: any;
declare var require: any;

// We rely on console patching; force enable service and capture

describe("mapping_status emission", () => {
  beforeEach(async () => {
    process.env.CONSOLE_INLINE_ENABLED = "true";
    process.env.CONSOLE_INLINE_TEST_CAPTURE = "true";
    // Source maps disabled to make deterministic 'miss'
    process.env.CONSOLE_INLINE_SOURCE_MAPS = "false";
    // Reload module fresh each test
    const modPath = require.resolve("./index");
    delete require.cache[modPath];
    await import("./index");
  });

  it("emits mapping_status field for console.log", () => {
    console.log("mapping status test");
    const captured = (globalThis as any).__console_inline_captured__;
    expect(Array.isArray(captured)).toBe(true);
    const last = captured[captured.length - 1];
    expect(last).toBeTruthy();
    expect(last.method).toBe("log");
    expect(["hit", "miss", "pending"]).toContain(last.mapping_status);
    // With maps disabled we expect miss
    expect(last.mapping_status).toBe("miss");
    expect(last.original_file).toBe(last.file); // no mapping change
  });
});
