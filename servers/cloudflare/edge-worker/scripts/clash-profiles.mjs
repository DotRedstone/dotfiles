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

function requireProviders(providers) {
  if (
    providers === null ||
    typeof providers !== "object" ||
    Array.isArray(providers)
  ) {
    throw new Error("providers must be a JSON object");
  }
}

export function buildRouterProfile({ baseline, providers }) {
  requireProviders(providers);
  const configuration = injectProviderUrls({
    baseline,
    providers,
  });

  const serialized = `${JSON.stringify(configuration, null, 2)}\n`;
  return serialized;
}

export const DEVICE_OVERRIDES = Object.freeze({
  tun: Object.freeze({ enable: false }),
  "allow-lan": false,
  remove: Object.freeze(["port", "socks-port", "redir-port", "tproxy-port"]),
  "mixed-port": 7890,
  "external-controller": "127.0.0.1:9090",
  "dns.listen": "127.0.0.1:1053",
});

export function buildDeviceProfile(routerObject) {
  const configuration = clone(routerObject);

  for (const key of DEVICE_OVERRIDES.remove) {
    delete configuration[key];
  }
  configuration.tun = clone(DEVICE_OVERRIDES.tun);
  configuration["allow-lan"] = DEVICE_OVERRIDES["allow-lan"];
  configuration["mixed-port"] = DEVICE_OVERRIDES["mixed-port"];
  configuration["external-controller"] =
    DEVICE_OVERRIDES["external-controller"];
  configuration.dns = {
    ...(configuration.dns ?? {}),
    listen: DEVICE_OVERRIDES["dns.listen"],
  };

  return `${JSON.stringify(configuration, null, 2)}\n`;
}

export function buildProfiles({ baseline, providers }) {
  const router = buildRouterProfile({ baseline, providers });
  const device = buildDeviceProfile(JSON.parse(router));

  return {
    router,
    root: router,
    desktop: device,
    mobile: device,
  };
}
