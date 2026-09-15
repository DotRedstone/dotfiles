import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const routerPolicy = require("../../../clash/router-policy.json");
const mobileHotspotPolicy = require("../../../clash/mobile-hotspot-policy.json");

const SELF_PROVIDER = "Abuse-CF-Next";

function safeProviderPath(name) {
  return `./providers/${name.toLowerCase().replaceAll(/[^a-z0-9]+/g, "-")}.yaml`;
}

function clone(value) {
  return structuredClone(value);
}

function injectProviderUrls({ baseline, providers, subscriptionUrl }) {
  const configuration = clone(baseline);
  const catalog = configuration["proxy-providers"];
  const activeProviders = new Set();

  for (const [name, provider] of Object.entries(catalog)) {
    if (name === SELF_PROVIDER) {
      provider.url = subscriptionUrl;
      provider.path = safeProviderPath(name);
      activeProviders.add(name);
      continue;
    }

    const source = providers?.[name];
    if (typeof source?.url !== "string" || source.url.length < 16) {
      // A retired provider must not make every device fail to load its profile.
      delete catalog[name];
      continue;
    }
    provider.url = source.url;
    provider.path = safeProviderPath(name);
    provider.interval ??= source.interval ?? 86400;
    activeProviders.add(name);
  }

  for (const group of configuration["proxy-groups"]) {
    if (Array.isArray(group.use)) {
      group.use = group.use.filter((name) => activeProviders.has(name));
    }
  }
  return configuration;
}

function groupByName(configuration, name) {
  return configuration["proxy-groups"].find((group) => group.name === name);
}

function appendProxyChoice(configuration, groupName, choice) {
  const group = groupByName(configuration, groupName);
  if (
    !group ||
    !Array.isArray(group.proxies) ||
    group.proxies.includes(choice)
  ) {
    return;
  }
  group.proxies.push(choice);
}

function ensureStableFallback(configuration) {
  const groups = configuration["proxy-groups"];
  const name = "🛟 稳定故障转移";
  const fallback = {
    name,
    type: "fallback",
    proxies: ["♻️ 全节点自动", "♻️ 自建-自动", "♻️ 滥用-自动"],
    url: "https://www.gstatic.com/generate_204",
    interval: 300,
    timeout: 5000,
    "max-failed-times": 1,
    lazy: false,
  };
  const existing = groupByName(configuration, name);
  if (existing) {
    Object.assign(existing, fallback);
    return;
  }

  const firstSelector = groups.findIndex(
    (group) => group.name === "🛡️ 自建VPS",
  );
  groups.splice(firstSelector < 0 ? groups.length : firstSelector, 0, fallback);
}

function ensureCfNextGrayPool(configuration) {
  const groups = configuration["proxy-groups"];
  const provider = [SELF_PROVIDER];
  const healthCheck = {
    url: "https://www.gstatic.com/generate_204",
    interval: 300,
    timeout: 5000,
    "max-failed-times": 1,
    lazy: false,
  };
  const transports = [
    {
      name: "🧪 CF-Next · XHTTP",
      type: "url-test",
      filter: "VLESS-XHTTP$",
    },
    {
      name: "🧪 CF-Next · WS",
      type: "url-test",
      filter: "VLESS-WS$",
    },
    {
      name: "🧪 CF-Next · Trojan",
      type: "url-test",
      filter: "Trojan-WS$",
    },
  ];

  for (const transport of transports) {
    const group = {
      ...transport,
      ...healthCheck,
      use: provider,
    };
    const existing = groupByName(configuration, transport.name);
    if (existing) Object.assign(existing, group);
    else groups.push(group);
  }

  const gray = {
    name: "🧪 CF-Next-灰度",
    type: "fallback",
    proxies: transports.map((transport) => transport.name),
    ...healthCheck,
  };
  const existingGray = groupByName(configuration, gray.name);
  if (existingGray) {
    // The old policy defined this group directly from the provider.  A fallback
    // must only contain the three transport groups, otherwise raw provider
    // nodes bypass the intended XHTTP -> WS -> Trojan preference order.
    delete existingGray.use;
    delete existingGray.filter;
    delete existingGray.tolerance;
    Object.assign(existingGray, gray);
  } else groups.push(gray);
}

function optimizeNodeGroups(configuration) {
  // First try the established automatic pool, then fail over to self-hosted
  // and legacy CDN pools. CF-Next remains opt-in until client testing passes.
  ensureStableFallback(configuration);
  ensureCfNextGrayPool(configuration);
  for (const group of configuration["proxy-groups"]) {
    if (group.type === "url-test") {
      group.timeout = 5000;
      group["max-failed-times"] = 1;
    }
  }

  appendProxyChoice(configuration, "🌐 Default", "🛟 稳定故障转移");
  const defaultGroup = groupByName(configuration, "🌐 Default");
  if (defaultGroup && Array.isArray(defaultGroup.proxies)) {
    const preferred = [
      "🛟 稳定故障转移",
      "♻️ 全节点自动",
      "🛡️ 自建VPS",
      "♻️ 自建-自动",
    ];
    defaultGroup.proxies = [
      ...preferred.filter((name) => defaultGroup.proxies.includes(name)),
      ...defaultGroup.proxies.filter((name) => !preferred.includes(name)),
    ];
  }

  appendProxyChoice(configuration, "🌐 Default", "🧪 CF-Next-灰度");
  appendProxyChoice(configuration, "☁️ 滥用节点", "🧪 CF-Next-灰度");
  appendProxyChoice(configuration, "☁️ cloudflare", "🧪 CF-Next-灰度");

  configuration.profile = {
    ...(configuration.profile ?? {}),
    "store-selected": true,
    "store-fake-ip": true,
  };
  configuration["tcp-concurrent"] = true;
  configuration["unified-delay"] = true;
}

export function buildProfiles({ providers, publicHost, subscriptionToken }) {
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(subscriptionToken)) {
    throw new Error("invalid subscription token");
  }
  const routerConfiguration = injectProviderUrls({
    baseline: routerPolicy,
    providers,
    subscriptionUrl: `https://${publicHost}/sub/${subscriptionToken}`,
  });
  const rootConfiguration = injectProviderUrls({
    baseline: mobileHotspotPolicy,
    providers,
    subscriptionUrl: `https://${publicHost}/sub/${subscriptionToken}`,
  });
  optimizeNodeGroups(routerConfiguration);
  optimizeNodeGroups(rootConfiguration);
  const routerSerialized = `${JSON.stringify(routerConfiguration, null, 2)}\n`;
  const rootSerialized = `${JSON.stringify(rootConfiguration, null, 2)}\n`;

  // Root is the verified Android hotspot baseline. The other consumers retain
  // the router baseline, so Android-only TProxy and UID interception do not
  // leak into ordinary desktop clients.
  return {
    router: routerSerialized,
    desktop: routerSerialized,
    mobile: routerSerialized,
    root: rootSerialized,
  };
}
