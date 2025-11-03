declare module "@jridgewell/trace-mapping" {
  export class TraceMap {
    constructor(map: any);
  }
  export function originalPositionFor(
    map: TraceMap,
    pos: { line: number; column: number },
  ): { source?: string; line?: number; column?: number; name?: string } | null;
}
