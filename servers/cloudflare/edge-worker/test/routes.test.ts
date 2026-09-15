import { describe, expect, it } from "vitest";
import { matchesTransportPath } from "../src/routes";

describe("transport path matching", () => {
  const path = "/edge/private-route";

  it("accepts the exact path and Mihomo's normalized trailing slash", () => {
    expect(matchesTransportPath(path, path)).toBe(true);
    expect(matchesTransportPath(`${path}/`, path)).toBe(true);
  });

  it("does not accept prefixes or additional segments", () => {
    expect(matchesTransportPath("/edge", path)).toBe(false);
    expect(matchesTransportPath(`${path}/extra`, path)).toBe(false);
  });
});
