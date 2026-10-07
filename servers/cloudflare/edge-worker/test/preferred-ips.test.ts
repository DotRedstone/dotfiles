import { describe, expect, it } from "vitest";
import {
  parsePreferredEndpoints,
  preferredEndpointsResponse,
} from "../src/preferred-ips";
import type { Env } from "../src/types";

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

  it("exports only the stored router-selected endpoint pool", async () => {
    const env = {
      EDGE_STATE: {
        get: async () => ({
          version: 1,
          updatedAt: "2026-10-08T00:00:00.000Z",
          endpoints: [
            { address: "203.0.113.1", port: 443, label: "HKG" },
            { address: "2001:db8::1", port: 8443, label: "NRT" },
          ],
        }),
      },
    } as unknown as Env;

    const response = await preferredEndpointsResponse(env);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe(
      "203.0.113.1:443#HKG\n[2001:db8::1]:8443#NRT\n",
    );
  });
});
