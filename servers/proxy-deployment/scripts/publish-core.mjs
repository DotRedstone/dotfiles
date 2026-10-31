import { createHash } from "node:crypto";

export const manifestKey = "delivery/manifest/v1";

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, canonical(value[key])]),
    );
  }
  return value;
}

function digest(value) {
  return createHash("sha256").update(JSON.stringify(canonical(value))).digest("hex");
}

// 候选顺序会影响 provider；v2 编译器也用测速指标构造节点名称。
function releasePoolInput(pools) {
  if (pools === null) return null;
  return Object.fromEntries(Object.entries(pools).map(([origin, pool]) => [origin, {
    version: pool.version,
    sourceId: pool.sourceId,
    origin: pool.origin,
    candidates: pool.candidates.map((candidate) => ({
      address: candidate.address,
      port: candidate.port,
      latencyMs: candidate.latencyMs,
      lossRate: candidate.lossRate,
      ...(candidate.downloadMBps === undefined ? {} : { downloadMBps: candidate.downloadMBps }),
    })),
  }]));
}

export function releaseHash({ compilerRevision, accountId, account, catalog, runtime, pools }) {
  return digest({
    compilerRevision,
    accountId,
    account,
    nodes: catalog.nodes,
    sources: catalog.sources,
    ownedDomains: catalog.ownedDomains,
    profiles: catalog.profiles,
    runtime: account.enabled ? runtime : null,
    pools: releasePoolInput(pools),
  });
}

function previousManifest(raw, compiler) {
  if (raw === null) return null;
  const manifest = JSON.parse(raw);
  const accounts = Object.fromEntries(
    Object.entries(manifest.accounts ?? {}).map(([id, entry]) => [id, {
      enabled: entry.enabled,
      expiresAt: entry.expiresAt,
      allowedExits: entry.allowedExits,
    }]),
  );
  compiler.validateDeliveryManifest(manifest, { version: 1, accounts });
  return manifest;
}

function poolFor(catalog, account, origin, pools, compiler, now, maxPoolAgeSeconds) {
  const sourceId = account.sourceIdByOrigin[origin];
  const source = catalog.sources.sources.find(
    (item) => item.sourceId === sourceId && item.origin === origin,
  );
  const pool = pools[`${sourceId}/${origin}`];
  if (!source || pool?.version !== 2) throw new Error("validated v2 pool unavailable");
  compiler.validatePool(pool, sourceId, origin, source);
  const age = now.getTime() - Date.parse(pool.validatedAt);
  if (age < 0 || age > maxPoolAgeSeconds * 1000) {
    throw new Error("validated pool outside freshness window");
  }
  return pool;
}

function validateSharedEdgePools(account, pools, sharedEdgeSourceIds) {
  const sourceId = account.sourceIdByOrigin.la;
  if (!sharedEdgeSourceIds.includes(sourceId) &&
      !sharedEdgeSourceIds.includes(account.sourceIdByOrigin.sg)) return;
  if (sourceId !== account.sourceIdByOrigin.sg ||
      pools.la.sourceId !== sourceId || pools.sg.sourceId !== sourceId ||
      pools.la.accessNetwork !== pools.sg.accessNetwork ||
      pools.la.egressNetwork !== pools.sg.egressNetwork ||
      pools.la.collectedAt !== pools.sg.collectedAt) {
    throw new Error("shared edge pools have different scan provenance");
  }
  const la = new Map(pools.la.candidates.map((item) => [item.address, item]));
  const sg = new Map(pools.sg.candidates.map((item) => [item.address, item]));
  const laOverlap = pools.la.candidates.filter((item) => sg.has(item.address));
  const sgOverlap = pools.sg.candidates.filter((item) => la.has(item.address));
  // 同次扫描的两个兼容子序列可无交集；collectedAt 是操作性同源约束，
  // 不能替代扫描 ID 或密码学证明。
  if (laOverlap.some((item, index) =>
        item.address !== sgOverlap[index].address ||
        item.downloadMBps === undefined ||
        item.downloadMBps !== sg.get(item.address).downloadMBps)) {
    throw new Error("shared edge pools disagree on common candidates");
  }
  if ([...la.values(), ...sg.values()].some((item) => item.downloadMBps === undefined)) {
    throw new Error("shared edge pool candidate lacks measured speed");
  }
}

function documentsFor({ accountId, account, catalog, runtime, pools, compiler, release }) {
  const prefix = `accounts/${accountId}/${release}`;
  const profiles = Object.fromEntries(
    ["router", "desktop", "mobile"].map((kind) => [kind, `${prefix}/${kind}`]),
  );
  const providers = {
    "la-cf": `${prefix}/providers/la-cf`,
    "sg-cf": `${prefix}/providers/sg-cf`,
  };
  const documents = new Map();
  if (!account.enabled) {
    for (const key of [...Object.values(profiles), ...Object.values(providers)]) {
      documents.set(key, '{"proxies":[]}\n');
    }
    return { profiles, providers, documents };
  }
  const base = {
    account,
    nodes: catalog.nodes,
    sources: catalog.sources,
    credentials: runtime.credentials,
    pools,
  };
  const compiledProviders = compiler.buildProviders(base);
  for (const name of ["la-cf", "sg-cf"]) {
    documents.set(providers[name], compiler.serializeYaml(compiledProviders[name]));
  }
  for (const kind of ["router", "desktop", "mobile"]) {
    const document = compiler.buildProfile({
      ...base,
      ownedDomains: catalog.ownedDomains,
      profile: catalog.profiles[kind],
      providerBaseUrl: `${runtime.deliveryBaseUrl}/u/${runtime.deliveryToken}/${kind}`,
    });
    documents.set(profiles[kind], compiler.serializeYaml(document));
  }
  return { profiles, providers, documents };
}

// Store is a restricted KV adapter with async get(key) and put(key, value).
// The manifest is the only mutable delivery key; document keys are immutable.
export async function publish({
  catalog,
  runtimeByAccount,
  pools,
  compiler,
  compilerRevision,
  store,
  validateDocument,
  maxPoolAgeSeconds,
  sharedEdgeSourceIds = [],
  now = new Date(),
}) {
  if (!/^[0-9a-f]{40}$/.test(compilerRevision)) throw new Error("invalid compiler revision");
  if (!Number.isInteger(maxPoolAgeSeconds) || maxPoolAgeSeconds < 60) {
    throw new Error("invalid pool freshness policy");
  }
  if (!Array.isArray(sharedEdgeSourceIds) ||
      sharedEdgeSourceIds.some((id) => typeof id !== "string" ||
        !/^[a-z0-9][a-z0-9-]{1,63}$/.test(id)) ||
      new Set(sharedEdgeSourceIds).size !== sharedEdgeSourceIds.length) {
    throw new Error("invalid shared edge source list");
  }
  compiler.validateCatalog(catalog);
  for (const sourceId of sharedEdgeSourceIds) {
    if (!["la", "sg"].every((origin) => catalog.sources.sources.some(
      (source) => source.sourceId === sourceId && source.origin === origin,
    ))) {
      throw new Error("shared edge source is absent from approved origins");
    }
  }
  if (Object.values(catalog.accounts.accounts).some((account) => account.enabled) &&
      typeof validateDocument !== "function") {
    throw new Error("static document validator required");
  }
  const old = previousManifest(await store.get(manifestKey), compiler);
  const accounts = catalog.accounts.accounts;
  if (old && Object.keys(old.accounts).some((id) => !(id in accounts))) {
    throw new Error("account removal needs separate revocation review");
  }
  const next = {};
  const pending = new Map();
  const deliveryTokens = new Set();
  let changed = 0;
  for (const [accountId, account] of Object.entries(accounts)) {
    let runtime = runtimeByAccount[accountId];
    let accountPools = null;
    if (account.enabled) {
      if (runtime?.accountId !== accountId) throw new Error("runtime account mismatch");
      let deliveryUrl;
      try { deliveryUrl = new URL(runtime.deliveryBaseUrl); } catch {
        throw new Error("invalid delivery base URL");
      }
      if (deliveryUrl.protocol !== "https:" || deliveryUrl.pathname !== "/" ||
          deliveryUrl.search || deliveryUrl.hash || deliveryUrl.username || deliveryUrl.password ||
          !/^[A-Za-z0-9_-]{32,128}$/.test(runtime.deliveryToken) ||
          deliveryTokens.has(runtime.deliveryToken)) {
        throw new Error("invalid or reused delivery identity");
      }
      deliveryTokens.add(runtime.deliveryToken);
      runtime = { ...runtime, deliveryBaseUrl: deliveryUrl.origin };
      accountPools = Object.fromEntries(
        ["la", "sg"].map((origin) => [origin, poolFor(
          catalog, account, origin, pools, compiler, now, maxPoolAgeSeconds,
        )]),
      );
      validateSharedEdgePools(account, accountPools, sharedEdgeSourceIds);
    }
    const release = releaseHash({
      compilerRevision, accountId, account, catalog, runtime, pools: accountPools,
    });
    const entry = {
      enabled: account.enabled,
      expiresAt: account.expiresAt,
      allowedExits: account.allowedExits,
      profiles: Object.fromEntries(
        ["router", "desktop", "mobile"].map((kind) => [kind, `accounts/${accountId}/${release}/${kind}`]),
      ),
      providers: {
        "la-cf": `accounts/${accountId}/${release}/providers/la-cf`,
        "sg-cf": `accounts/${accountId}/${release}/providers/sg-cf`,
      },
    };
    next[accountId] = entry;
    if (JSON.stringify(old?.accounts[accountId]) === JSON.stringify(entry) &&
        old?.compilerRevision === compilerRevision) continue;
    const built = documentsFor({
      accountId, account, catalog, runtime, pools: accountPools, compiler, release,
    });
    for (const [key, body] of built.documents) {
      const parsed = JSON.parse(body);
      if (!Array.isArray(parsed.proxies)) throw new Error("compiled document has no proxies");
      if (account.enabled) {
        await validateDocument({ accountId, key, body, documents: built.documents });
      }
      pending.set(key, body);
    }
    changed++;
  }
  if (!changed && old) return { published: false, accountsChanged: 0, documentsWritten: 0 };
  const manifest = {
    version: 1,
    compilerRevision,
    generatedAt: now.toISOString(),
    accounts: next,
  };
  compiler.validateDeliveryManifest(manifest, catalog.accounts);
  for (const [key, body] of pending) {
    const existing = await store.get(key);
    if (existing !== null && existing !== body) throw new Error("immutable document collision");
    if (existing === null) await store.put(key, body);
    if (await store.get(key) !== body) throw new Error("document readback mismatch");
  }
  await store.put(manifestKey, JSON.stringify(manifest));
  if (await store.get(manifestKey) !== JSON.stringify(manifest)) {
    throw new Error("manifest readback mismatch");
  }
  return { published: true, accountsChanged: changed, documentsWritten: pending.size };
}
