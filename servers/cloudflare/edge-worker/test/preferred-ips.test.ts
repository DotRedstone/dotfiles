import { describe, expect, it } from "vitest";
import { parsePreferredEndpoints } from "../src/preferred-ips";

describe("preferred endpoint parser", () => {
  it("accepts the router text formats and removes duplicates", () => {
    expect(
      parsePreferredEndpoints(`
        # CloudflareST output selected by the router
        203.0.113.1#FRA
        203.0.113.2,8443,SIN
        [2001:db8::1]:443#NRT
        203.0.113.1#duplicate
      `),
    ).toEqual([
      { address: "203.0.113.1", port: 443, label: "FRA" },
      { address: "203.0.113.2", port: 8443, label: "SIN" },
      { address: "2001:db8::1", port: 443, label: "NRT" },
    ]);
  });

  it("rejects an empty list", () => {
    expect(() => parsePreferredEndpoints("# empty\n")).toThrow();
  });
});
