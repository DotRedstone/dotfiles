import { describe, expect, it } from "vitest";

import { configurationProfile } from "../src/clash-config";

const tokens = JSON.stringify({
  router: "r".repeat(32),
  desktop: "d".repeat(32),
  mobile: "m".repeat(32),
  root: "x".repeat(32),
});

describe("configurationProfile", () => {
  it("only accepts the token for its matching profile", () => {
    expect(
      configurationProfile(`/clash/${"r".repeat(32)}/router`, tokens),
    ).toBe("router");
    expect(
      configurationProfile(`/clash/${"r".repeat(32)}/mobile`, tokens),
    ).toBeNull();
    expect(
      configurationProfile(`/clash/${"m".repeat(32)}/mobile/`, tokens),
    ).toBeNull();
    expect(configurationProfile(`/clash/${"x".repeat(32)}/root`, tokens)).toBe(
      "root",
    );
  });

  it("does not accept malformed token catalogs", () => {
    expect(configurationProfile("/clash/test/router", "not-json")).toBeNull();
  });
});
