import { describe, expect, it } from "vitest";

import { buildProfiles } from "../scripts/clash-config.mjs";

const providers = Object.fromEntries(
  [
    "VPS-Node-LA-Reality",
    "VPS-Node-LA-WS",
    "VPS-Node-LA-Preferred",
    "VPS-Node-SG-Reality",
    "VPS-Node-SG-WS",
    "VPS-Node-SG-Preferred",
  ].map((name) => [name, { url: `https://example.com/${name}` }]),
);

describe("buildProfiles", () => {
  it("builds unified profiles across all devices matching router baseline", () => {
    const profiles = buildProfiles({
      providers,
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
    expect(Object.keys(router["proxy-providers"])).toEqual([
      "VPS-Node-LA-Reality",
      "VPS-Node-LA-WS",
      "VPS-Node-LA-Preferred",
      "VPS-Node-SG-Reality",
      "VPS-Node-SG-WS",
      "VPS-Node-SG-Preferred",
    ]);
    expect(router["proxy-providers"]["VPS-Node-SG-Preferred"].url).toBe(
      "https://example.com/VPS-Node-SG-Preferred",
    );
    expect(
      router["proxy-providers"]["VPS-Node-LA-Reality"].path,
    ).toBeUndefined();

    // Groups
    const groupNames = router["proxy-groups"].map(
      (group: { name: string }) => group.name,
    );
    expect(groupNames).toContain("♻️ 洛杉矶-直连-自动");
    expect(groupNames).toContain("🇺🇸 洛杉矶-直连-手动");
    expect(groupNames).toContain("♻️ 洛杉矶-优选-自动");
    expect(groupNames).toContain("🇺🇸 洛杉矶-优选-手动");
    expect(groupNames).toContain("♻️ 新加坡-直连-自动");
    expect(groupNames).toContain("🇸🇬 新加坡-直连-手动");
    expect(groupNames).toContain("♻️ 新加坡-优选-自动");
    expect(groupNames).toContain("🇸🇬 新加坡-优选-手动");
    expect(groupNames).toContain("🌐 Default");
    expect(groupNames).toContain("🎬 YouTube");
    expect(groupNames).toContain("🤖 ChatGPT");
    expect(groupNames).toContain("🐟 漏网之鱼");
    expect(groupNames).not.toContain("🧪 协议手工测试");
    expect(groupNames).not.toContain("🧪 CF-Next-灰度");

    const defaultGroup = router["proxy-groups"].find(
      (group: { name: string }) => group.name === "🌐 Default",
    );
    expect(defaultGroup.proxies[0]).toBe("🇺🇸 洛杉矶");
    expect(router["proxy-groups"].length).toBe(34);
    expect(router.rules.length).toBe(41);
  });

  it("removes retired providers safely without crash", () => {
    const profiles = buildProfiles({
      providers: {},
    });
    const router = JSON.parse(profiles.router);
    expect(router["proxy-providers"]).toEqual({});
  });
});
