import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const routerPolicy = require("../../../clash/router-policy.json");

function clone(value) {
  return structuredClone(value);
}

function injectProviderUrls({ baseline, providers }) {
  const configuration = clone(baseline);
  const catalog = configuration["proxy-providers"] ?? {};
  const activeProviders = new Set();

  for (const [name, provider] of Object.entries(catalog)) {
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

export function buildProfiles({ providers }) {
  const configuration = injectProviderUrls({
    baseline: routerPolicy,
    providers,
  });

  const serialized = `${JSON.stringify(configuration, null, 2)}\n`;

  return {
    router: serialized,
    desktop: serialized,
    mobile: serialized,
    root: serialized,
  };
}
