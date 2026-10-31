import assert from "node:assert/strict";
import test from "node:test";

import {
  buildDeviceProfile,
  buildProfiles,
  buildRouterProfile,
} from "./clash-profiles.mjs";

const baseline = {
  port: 7890,
  "socks-port": 7891,
  "redir-port": 7892,
  "tproxy-port": 7893,
  tun: {
    enable: true,
    stack: "system",
    device: "synthetic-tun",
  },
  "allow-lan": true,
  "mixed-port": 1080,
  "external-controller": "0.0.0.0:9090",
  dns: {
    enable: true,
    listen: "0.0.0.0:53",
    nameserver: ["https://dns.example/dns-query"],
    "proxy-server-nameserver": ["https://bootstrap.example/dns-query"],
  },
  "proxy-providers": {
    "Example-Primary": {
      type: "http",
      path: "./old-primary.yaml",
    },
    "Example-Fallback": {
      type: "http",
      interval: 3600,
    },
  },
  "proxy-groups": [
    {
      name: "Example Group",
      type: "select",
      use: ["Example-Primary", "Example-Fallback"],
    },
  ],
  rules: ["MATCH,Example Group"],
};

const providers = {
  "Example-Primary": {
    url: "https://provider.example/primary.yaml",
    interval: 7200,
  },
  "Example-Fallback": {
    url: "https://provider.example/fallback.yaml",
  },
};

function differencePaths(left, right, prefix = "") {
  if (assert.deepStrictEqual(left, right) === undefined) return [];
  if (
    left !== null &&
    right !== null &&
    typeof left === "object" &&
    typeof right === "object" &&
    !Array.isArray(left) &&
    !Array.isArray(right)
  ) {
    const keys = new Set([...Object.keys(left), ...Object.keys(right)]);
    return [...keys].flatMap((key) =>
      differencePaths(
        left[key],
        right[key],
        prefix ? `${prefix}.${key}` : key,
      ),
    );
  }
  return [prefix];
}

function isAllowedDeviceDifference(path) {
  return (
    path === "tun" ||
    path.startsWith("tun.") ||
    path === "allow-lan" ||
    path === "port" ||
    path === "socks-port" ||
    path === "redir-port" ||
    path === "tproxy-port" ||
    path === "mixed-port" ||
    path === "external-controller" ||
    path === "dns.listen"
  );
}

test("buildProfiles keeps four compatibility names for two profile contents", () => {
  const profiles = buildProfiles({ baseline, providers });

  assert.deepEqual(Object.keys(profiles), [
    "router",
    "root",
    "desktop",
    "mobile",
  ]);
  assert.equal(profiles.root, profiles.router);
  assert.equal(profiles.desktop, profiles.mobile);
  assert.equal(profiles.router, buildRouterProfile({ baseline, providers }));
});

test("device changes only the approved keys and preserves routing policy", () => {
  const profiles = buildProfiles({ baseline, providers });
  const router = JSON.parse(profiles.router);
  const device = JSON.parse(profiles.desktop);
  const changedPaths = differencePaths(router, device);

  assert.ok(changedPaths.length > 0);
  assert.ok(
    changedPaths.every(isAllowedDeviceDifference),
    `unexpected device differences: ${changedPaths.join(", ")}`,
  );
  assert.deepEqual(device["proxy-groups"], router["proxy-groups"]);
  assert.deepEqual(device.rules, router.rules);
  assert.deepEqual(device["proxy-providers"], router["proxy-providers"]);
  assert.deepEqual(device.dns.nameserver, router.dns.nameserver);
  assert.deepEqual(
    device.dns["proxy-server-nameserver"],
    router.dns["proxy-server-nameserver"],
  );
  assert.deepEqual(device.tun, { enable: false });
  assert.equal(device["allow-lan"], false);
  for (const key of ["port", "socks-port", "redir-port", "tproxy-port"]) {
    assert.equal(Object.hasOwn(device, key), false);
  }
  assert.equal(device["mixed-port"], 7890);
  assert.equal(device["external-controller"], "127.0.0.1:9090");
  assert.equal(device.dns.listen, "127.0.0.1:1053");
});

test("buildDeviceProfile does not mutate the router object", () => {
  const router = JSON.parse(buildRouterProfile({ baseline, providers }));
  const original = structuredClone(router);

  buildDeviceProfile(router);

  assert.deepEqual(router, original);
});

test("buildProfiles rejects a missing providers object", () => {
  assert.throws(
    () => buildProfiles({ baseline }),
    /providers must be a JSON object/,
  );
});
