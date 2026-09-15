import { describe, expect, it } from "vitest";

import { buildProfiles } from "../scripts/clash-config.mjs";

const providers = Object.fromEntries(
  [
    "VPS-Node-LA-Reality",
    "VPS-Node-LA-WS",
    "VPS-Node-SG-Reality",
    "VPS-Node-SG-WS",
    "Abuse-CF1",
    "Abuse-CF2",
    "Airport-Mitce2",
  ].map((name) => [name, { url: `https://example.com/${name}` }]),
);

describe("buildProfiles", () => {
  it("builds router profiles and the verified Android hotspot profile", () => {
    const profiles = buildProfiles({
      providers,
      publicHost: "edge.example.com",
      subscriptionToken: "a".repeat(32),
    });
    const desktop = JSON.parse(profiles.desktop);
    const router = JSON.parse(profiles.router);
    const mobile = JSON.parse(profiles.mobile);
    const root = JSON.parse(profiles.root);

    expect(desktop.mode).toBe("rule");
    expect(desktop["proxy-providers"]["Abuse-CF-Next"].url).toContain("/sub/");
    expect(
      desktop["proxy-groups"].map((group: { name: string }) => group.name),
    ).toContain("🧪 CF-Next-灰度");
    expect(
      desktop["proxy-groups"].find(
        (group: { name: string }) => group.name === "🌐 Default",
      ).proxies[0],
    ).toBe("🛟 稳定故障转移");
    expect(router["mixed-port"]).toBe(7893);
    expect(router.tun.device).toBe("utun");
    expect(mobile).toEqual(router);
    expect(root).not.toEqual(router);
    expect(root["tproxy-port"]).toBe(9898);
    expect(root["redir-port"]).toBe(9797);
    expect(root.dns.listen).toBe("0.0.0.0:1053");
    expect(root.tun.enable).toBe(true);
    expect(root.tun.device).toBe("meta");
    expect(root["external-controller"]).toBe("0.0.0.0:9090");
    expect(root["external-ui"]).toBe("./dashboard");
    expect(root["proxy-providers"]["Airport-Mitce1"]).toBeUndefined();

    for (const configuration of [router, root]) {
      const groups = new Map<
        string,
        { name: string; proxies: string[]; use?: string[] }
      >(
        configuration["proxy-groups"].map(
          (group: { name: string; proxies: string[] }) => [group.name, group],
        ),
      );
      const defaultGroup = groups.get("🌐 Default")!;
      const cloudflareGroup = groups.get("☁️ cloudflare")!;
      expect(defaultGroup.proxies[0]).toBe("🛟 稳定故障转移");
      expect(defaultGroup.proxies).toContain("🧪 CF-Next-灰度");
      expect(cloudflareGroup.proxies).toContain("🧪 CF-Next-灰度");
      expect(groups.get("🛟 稳定故障转移")).toMatchObject({
        type: "fallback",
        proxies: ["♻️ 全节点自动", "♻️ 自建-自动", "♻️ 滥用-自动"],
        "max-failed-times": 1,
      });
      expect(groups.get("🧪 CF-Next-灰度")).toMatchObject({
        type: "fallback",
        proxies: [
          "🧪 CF-Next · XHTTP",
          "🧪 CF-Next · WS",
          "🧪 CF-Next · Trojan",
        ],
      });
      expect(groups.get("🧪 CF-Next-灰度")!.use).toBeUndefined();
      expect(groups.get("🧪 CF-Next · XHTTP")).toMatchObject({
        type: "url-test",
        filter: "VLESS-XHTTP$",
        use: ["Abuse-CF-Next"],
      });
      expect(configuration.profile["store-selected"]).toBe(true);
      expect(configuration["tcp-concurrent"]).toBe(true);
    }
  });

  it("removes retired providers without changing the router policy", () => {
    const profiles = buildProfiles({
      providers: {},
      publicHost: "edge.example.com",
      subscriptionToken: "a".repeat(32),
    });
    const root = JSON.parse(profiles.root);
    expect(root["proxy-providers"]["Airport-Mitce1"]).toBeUndefined();
    expect(root["proxy-groups"].length).toBe(40);
    expect(root["tproxy-port"]).toBe(9898);
  });
});
