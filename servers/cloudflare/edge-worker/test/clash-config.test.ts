import { describe, expect, it } from "vitest";

import { buildProfiles } from "../scripts/clash-config.mjs";

const providers = Object.fromEntries(
  [
    "VPS-Node-LA-Reality",
    "VPS-Node-LA-WS",
    "VPS-Node-LA-CDN",
    "VPS-Node-SG-Reality",
    "VPS-Node-SG-WS",
    "VPS-Node-SG-CDN",
    "VPS-Node-SG-HY2",
    "Abuse-CF1",
    "Abuse-CF2",
    "Airport-Mitce2",
  ].map((name) => [name, { url: `https://example.com/${name}` }]),
);

describe("buildProfiles", () => {
  it("builds unified profiles across all devices matching router baseline", () => {
    const profiles = buildProfiles({
      providers,
      publicHost: "edge.example.com",
      subscriptionToken: "a".repeat(32),
    });
    const desktop = JSON.parse(profiles.desktop);
    const router = JSON.parse(profiles.router);
    const mobile = JSON.parse(profiles.mobile);
    const root = JSON.parse(profiles.root);

    // All profiles are unified
    expect(desktop).toEqual(router);
    expect(mobile).toEqual(router);
    expect(root).toEqual(router);

    // Baseline fields
    expect(router.port).toBe(7890);
    expect(router["socks-port"]).toBe(7891);
    expect(router.mode).toBe("rule");
    expect(router.dns.listen).toBe("0.0.0.0:1053");
    expect(router.dns["enhanced-mode"]).toBe("fake-ip");
    expect(router["external-controller"]).toBe("0.0.0.0:9090");
    expect(router["tproxy-port"]).toBe(9898);
    expect(router["redir-port"]).toBe(9797);
    expect(router.tun.device).toBe("meta");

    // Providers
    expect(router["proxy-providers"]["Abuse-CF-Next"].url).toBe(
      `https://edge.example.com/sub/${"a".repeat(32)}`,
    );
    expect(router["proxy-providers"]["Airport-Mitce1"]).toBeUndefined();
    expect(router["proxy-providers"]["Airport-Mitce2"].url).toBe(
      "https://example.com/Airport-Mitce2",
    );
    expect(router["proxy-providers"]["VPS-Node-SG-HY2"].url).toBe(
      "https://example.com/VPS-Node-SG-HY2",
    );
    expect(
      router["proxy-providers"]["VPS-Node-LA-Reality"].path,
    ).toBeUndefined();
    expect(router["proxy-providers"]["Abuse-CF-Next"].path).toBeUndefined();

    // Groups
    const groupNames = router["proxy-groups"].map(
      (group: { name: string }) => group.name,
    );
    expect(groupNames).toContain("♻️ 全节点自动");
    expect(groupNames).toContain("🧪 CF-Next-灰度");
    expect(groupNames).toContain("🧪 CF-Next-WS");
    expect(groupNames).toContain("🧪 CF-Next-XHTTP");
    expect(groupNames).toContain("🧪 CF-Next-Trojan-WS");
    expect(groupNames).toContain("⚡ 稳定-洛杉矶直连");
    expect(groupNames).toContain("🧪 协议手工测试");
    expect(groupNames).toContain("🧷 洛杉矶-直连-WS");
    expect(groupNames).toContain("♻️ 直连-WS-自动");
    expect(groupNames).toContain("♻️ 直连-Reality-自动");
    expect(groupNames).toContain("♻️ CDN-WS-自动");
    expect(groupNames).toContain("🧪 LA-CDN-WS");
    expect(groupNames).toContain("🧪 SG-CDN-WS");
    expect(groupNames).toContain("🌐 Default");

    const defaultGroup = router["proxy-groups"].find(
      (group: { name: string }) => group.name === "🌐 Default",
    );
    expect(defaultGroup.proxies[0]).toBe("⚡ 稳定-洛杉矶直连");
    expect(router["proxy-groups"].length).toBe(53);
    expect(router.rules.length).toBe(41);
  });

  it("removes retired providers safely without crash", () => {
    const profiles = buildProfiles({
      providers: {},
      publicHost: "edge.example.com",
      subscriptionToken: "a".repeat(32),
    });
    const router = JSON.parse(profiles.router);
    expect(router["proxy-providers"]["Airport-Mitce1"]).toBeUndefined();
    expect(router["proxy-providers"]["Abuse-CF-Next"]).toBeDefined();
  });
});
