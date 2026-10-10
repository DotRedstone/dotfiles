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
    const states = new Map([
      [
        "preferred-endpoints-v2:la",
        {
          version: 1,
          updatedAt: "2026-10-08T00:00:00.000Z",
          endpoints: [
            { address: "203.0.113.1", port: 443, label: "LA-CF-01" },
            { address: "2001:db8::1", port: 8443, label: "LA-CF-02" },
          ],
        },
      ],
      [
        "preferred-endpoints-v2:sg",
        {
          version: 1,
          updatedAt: "2026-10-08T00:00:00.000Z",
          endpoints: [{ address: "203.0.113.2", port: 443, label: "SG-CF-01" }],
        },
      ],
    ]);
    const env = {
      EDGE_STATE: {
        get: async (key: string) => states.get(key),
      },
    } as unknown as Env;

    const [la, sg] = await Promise.all([
      preferredEndpointsResponse(env, "la"),
      preferredEndpointsResponse(env, "sg"),
    ]);
    expect(await la.text()).toBe(
      "203.0.113.1:443#LA-CF-01\n[2001:db8::1]:8443#LA-CF-02\n",
    );
    expect(await sg.text()).toBe("203.0.113.2:443#SG-CF-01\n");
  });
});
