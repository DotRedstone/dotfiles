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
  const catalog = configuration["proxy-providers"] ?? {};
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
      delete catalog[name];
      continue;
    }
    provider.url = source.url;
    provider.path = safeProviderPath(name);
    provider.interval ??= source.interval ?? 86400;
    activeProviders.add(name);
  }

  for (const group of configuration["proxy-groups"] ?? []) {
    if (Array.isArray(group.use)) {
      group.use = group.use.filter((name) => activeProviders.has(name));
    }
  }
  return configuration;
}

export function buildProfiles({ providers, publicHost, subscriptionToken }) {
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(subscriptionToken)) {
    throw new Error("invalid subscription token");
  }
  const subscriptionUrl = `https://${publicHost}/sub/${subscriptionToken}`;

  const configuration = injectProviderUrls({
    baseline: routerPolicy,
    providers,
    subscriptionUrl,
  });

  const serialized = `${JSON.stringify(configuration, null, 2)}\n`;

  return {
    router: serialized,
    desktop: serialized,
    mobile: serialized,
    root: serialized,
  };
}
