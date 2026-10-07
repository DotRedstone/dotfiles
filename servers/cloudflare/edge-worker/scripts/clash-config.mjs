import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const routerPolicy = require("../../../clash/router-policy.json");
const mobileHotspotPolicy = require("../../../clash/mobile-hotspot-policy.json");

const SELF_PROVIDER = "Abuse-CF-Next";

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
      // OpenClash owns provider cache paths itself.  Supplying a relative path
      // here makes Mihomo resolve it from its process working directory, not
      // OpenClash's cache directory, so a refresh can erase the last working
      // provider catalog during a cold start.
      delete provider.path;
      activeProviders.add(name);
      continue;
    }

    const source = providers?.[name];
    if (typeof source?.url !== "string" || source.url.length < 16) {
      delete catalog[name];
      continue;
    }
    provider.url = source.url;
    delete provider.path;
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
