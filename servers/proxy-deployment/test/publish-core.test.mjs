import test from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { manifestKey, publish, releaseHash } from "../scripts/publish-core.mjs";

const source = process.env.PROXY_STACK_SOURCE;
if (!source) throw new Error("PROXY_STACK_SOURCE must point to the fixed compiler source");
const compiler = await import(pathToFileURL(join(source, "src/compiler.mjs")));
const revision = "a".repeat(40);
const current = new Date("2026-10-11T02:00:00Z");

function fixture(ids = ["sample"]) {
  const accounts = Object.fromEntries(ids.map((id) => [id, {
    enabled: true,
    primaryOrigin: "la",
    sourceIdByOrigin: { la: "sample-net", sg: "sample-net" },
    allowedExits: ["la-direct", "la-cf", "sg-direct", "sg-cf"],
    quotaGiB: 1,
    expiresAt: null,
  }]));
  const catalog = {
    accounts: { version: 1, accounts },
    nodes: { version: 1, origins: Object.fromEntries(
      ["la", "sg"].map((origin) => [origin, {
        direct: { server: "192.0.2.1", port: 20002, serverName: "example.com" },
        cf: { host: `${origin}.example.test`, port: 443 },
      }]),
    ) },
    sources: { version: 1, sources: ["la", "sg"].map((origin) => ({
      sourceId: "sample-net", type: "signed-upload", origin,
      accessNetwork: "sample-access",
    })) },
    ownedDomains: { version: 1, suffixes: [], hosts: [], addresses: [] },
    profiles: Object.fromEntries(["router", "desktop", "mobile"].map((kind) => [kind, {
      version: 1, kind,
      settings: { "allow-lan": kind === "router", tun: { enable: false }, dns: { enable: false } },
    }])),
  };
  const runtimeByAccount = Object.fromEntries(ids.map((id, index) => [id, {
    accountId: id,
    deliveryBaseUrl: "https://config.example",
    deliveryToken: String.fromCharCode(65 + index).repeat(40),
    credentials: {
      uuidByOrigin: {
        la: "11111111-1111-4111-8111-111111111111",
        sg: "22222222-2222-4222-8222-222222222222",
      },
      realityByOrigin: Object.fromEntries(["la", "sg"].map((origin) => [origin, {
        publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        shortId: "12345678",
      }])),
      wsPathByOrigin: { la: "/sample-la", sg: "/sample-sg" },
    },
  }]));
  const pools = Object.fromEntries(["la", "sg"].map((origin, index) => [
    `sample-net/${origin}`,
    { version: 2, sourceId: "sample-net", origin,
      accessNetwork: "sample-access", egressNetwork: "sample-egress",
      collectedAt: "2026-10-11T00:00:00Z", validatedAt: "2026-10-11T01:00:00Z",
      candidates: [{ address: index ? "203.0.113.1" : "198.51.100.1",
        port: 443, latencyMs: 42, lossRate: 0 }],
    },
  ]));
  return { catalog, runtimeByAccount, pools };
}

class MemoryStore {
  constructor(entries = []) { this.values = new Map(entries); this.puts = []; }
  async get(key) { return this.values.get(key) ?? null; }
  async put(key, body) { this.puts.push(key); this.values.set(key, body); }
  copy() { return new MemoryStore(this.values); }
}

function run(input, store, extra = {}) {
  return publish({
    ...input, store, compiler, compilerRevision: revision,
    maxPoolAgeSeconds: 86400, now: current,
    validateDocument: async () => {}, ...extra,
  });
}

function hashFor(input) {
  const accountId = "sample";
  const account = input.catalog.accounts.accounts[accountId];
  const pools = account.enabled ? Object.fromEntries(
    ["la", "sg"].map((origin) => [
      origin, input.pools[`${account.sourceIdByOrigin[origin]}/${origin}`],
    ]),
  ) : null;
  return releaseHash({
    compilerRevision: revision, accountId, account,
    catalog: input.catalog, runtime: input.runtimeByAccount[accountId], pools,
  });
}

function changedAddress(input) {
  const changed = structuredClone(input);
  changed.pools["sample-net/la"].candidates[0].address = "198.51.100.9";
  return changed;
}

function sharedEdgeFixture() {
  const input = fixture();
  const candidate = (address, downloadMBps) => ({
    address, port: 443, latencyMs: 42, lossRate: 0, downloadMBps,
  });
  const [a, b, c] = [
    candidate("198.51.100.1", 5),
    candidate("203.0.113.1", 4),
    candidate("203.0.113.2", 3),
  ];
  input.pools["sample-net/la"].candidates = [a, b];
  input.pools["sample-net/sg"].candidates = [structuredClone(b), c];
  return input;
}

test("shared edge source accepts compatible ordered sublists", async () => {
  const store = new MemoryStore();
  const result = await run(sharedEdgeFixture(), store, { sharedEdgeSourceIds: ["sample-net"] });
  assert.equal(result.published, true);
  assert.equal(store.puts.at(-1), manifestKey);
});

test("shared edge gate rejects mixed scans, speed drift, and reversed ranking before KV writes", async () => {
  const changes = [
    (input) => { input.pools["sample-net/sg"].collectedAt = "2026-10-11T00:01:00Z"; },
    (input) => { input.pools["sample-net/sg"].candidates[0].downloadMBps = 3.9; },
    (input) => {
      const a = input.pools["sample-net/la"].candidates;
      input.pools["sample-net/sg"].candidates = [...a].reverse();
    },
  ];
  for (const change of changes) {
    const input = sharedEdgeFixture();
    change(input);
    const store = new MemoryStore();
    await assert.rejects(run(input, store, { sharedEdgeSourceIds: ["sample-net"] }),
      /shared edge pools/);
    assert.equal(store.puts.length, 0);
  }
});

test("shared edge source accepts disjoint compatible sublists from one scan", async () => {
  const input = sharedEdgeFixture();
  input.pools["sample-net/sg"].candidates.shift();
  const store = new MemoryStore();
  assert.equal((await run(input, store, { sharedEdgeSourceIds: ["sample-net"] })).published, true);
});

test("shared edge gate does not constrain an unregistered source", async () => {
  const input = sharedEdgeFixture();
  const independent = fixture(["independent"]);
  input.catalog.accounts.accounts.independent = independent.catalog.accounts.accounts.independent;
  input.catalog.accounts.accounts.independent.sourceIdByOrigin = { la: "other-net", sg: "other-net" };
  input.runtimeByAccount.independent = independent.runtimeByAccount.independent;
  input.runtimeByAccount.independent.deliveryToken = "B".repeat(40);
  for (const origin of ["la", "sg"]) {
    input.catalog.sources.sources.push({
      sourceId: "other-net", type: "signed-upload", origin, accessNetwork: "sample-access",
    });
    input.pools[`other-net/${origin}`] = {
      ...independent.pools[`sample-net/${origin}`], sourceId: "other-net",
    };
  }
  const store = new MemoryStore();
  assert.equal((await run(input, store, { sharedEdgeSourceIds: ["sample-net"] })).published, true);
});

test("shared edge source registration rejects an unknown source before KV writes", async () => {
  const store = new MemoryStore();
  await assert.rejects(run(fixture(), store, { sharedEdgeSourceIds: ["other-net"] }),
    /absent from approved origins/);
  assert.equal(store.puts.length, 0);
});

test("writes five immutable documents before the manifest and skips unchanged inputs", async () => {
  const store = new MemoryStore();
  const result = await run(fixture(), store);
  assert.deepEqual(result, { published: true, accountsChanged: 1, documentsWritten: 5 });
  assert.equal(store.puts.at(-1), manifestKey);
  assert.equal(store.puts.length, 6);
  const before = new Map(store.values);
  store.puts.length = 0;
  assert.equal((await run(fixture(), store)).published, false);
  assert.equal(store.puts.length, 0);
  assert.deepEqual(store.values, before);
});

test("timestamp and noncompiled pool metadata changes keep release and skip KV writes", async () => {
  const input = fixture();
  const store = new MemoryStore();
  await run(input, store);
  const original = new Map(store.values);
  const changed = structuredClone(input);
  changed.pools["sample-net/la"].collectedAt = "2026-10-11T00:15:00Z";
  changed.pools["sample-net/la"].validatedAt = "2026-10-11T01:45:00Z";
  changed.pools["sample-net/la"].egressNetwork = "other-egress";
  assert.equal(hashFor(changed), hashFor(input));
  store.puts.length = 0;
  assert.deepEqual(await run(changed, store),
    { published: false, accountsChanged: 0, documentsWritten: 0 });
  assert.deepEqual(store.puts, []);
  assert.deepEqual(store.values, original);
});

test("candidate content and original order both change the release", async () => {
  const input = fixture();
  const candidates = input.pools["sample-net/la"].candidates;
  candidates.push({ ...candidates[0], address: "198.51.100.2" });
  const initial = new MemoryStore();
  await run(input, initial);
  const originalRelease = JSON.parse(await initial.get(manifestKey)).accounts.sample.profiles.router;
  for (const modify of [
    (pool) => { pool.candidates[1].address = "198.51.100.3"; },
    (pool) => { pool.candidates.reverse(); },
  ]) {
    const changed = structuredClone(input);
    modify(changed.pools["sample-net/la"]);
    assert.notEqual(hashFor(changed), hashFor(input));
    const store = initial.copy();
    assert.deepEqual(await run(changed, store),
      { published: true, accountsChanged: 1, documentsWritten: 5 });
    assert.notEqual(JSON.parse(await store.get(manifestKey)).accounts.sample.profiles.router,
      originalRelease);
    assert.equal(store.puts.length, 6);
  }
});

test("pool version and candidate port remain included in release hash", () => {
  const input = fixture();
  for (const modify of [
    (pool) => { pool.version = 1; },
    (pool) => { pool.candidates[0].port = 8443; },
  ]) {
    const changed = structuredClone(input);
    modify(changed.pools["sample-net/la"]);
    assert.notEqual(hashFor(changed), hashFor(input));
  }
  // 单独改变版本或端口时现有 v2/端口检查会拒绝发布；直接检查哈希输入。
});

test("v2 measurement metrics change compiled provider release", async () => {
  const input = fixture();
  const initial = new MemoryStore();
  await run(input, initial);
  for (const modify of [
    (candidate) => { candidate.latencyMs = 43; },
    (candidate) => { candidate.lossRate = 0.05; },
    (candidate) => { candidate.downloadMBps = 5; },
  ]) {
    const changed = structuredClone(input);
    modify(changed.pools["sample-net/la"].candidates[0]);
    assert.notEqual(hashFor(changed), hashFor(input));
    const store = initial.copy();
    assert.equal((await run(changed, store)).published, true);
    assert.equal(store.puts.length, 6);
  }
});

test("freshness rejects an expired pool even if normalized hash is unchanged", async () => {
  const input = fixture();
  const store = new MemoryStore();
  await run(input, store);
  const originalManifest = await store.get(manifestKey);
  const stale = structuredClone(input);
  stale.pools["sample-net/la"].collectedAt = "2026-10-09T00:00:00Z";
  stale.pools["sample-net/la"].validatedAt = "2026-10-09T01:00:00Z";
  assert.equal(hashFor(stale), hashFor(input));
  store.puts.length = 0;
  await assert.rejects(run(stale, store), /validated pool outside freshness window/);
  assert.equal(store.puts.length, 0);
  assert.equal(await store.get(manifestKey), originalManifest);
});

test("disabled accounts retain null pool hashes and unchanged documents", async () => {
  const input = fixture();
  input.catalog.accounts.accounts.sample.enabled = false;
  const store = new MemoryStore();
  assert.equal((await run(input, store)).published, true);
  const previous = JSON.parse(await store.get(manifestKey)).accounts.sample;
  const changed = structuredClone(input);
  changed.pools = {};
  assert.equal(hashFor(changed), hashFor(input));
  store.puts.length = 0;
  assert.deepEqual(await run(changed, store),
    { published: false, accountsChanged: 0, documentsWritten: 0 });
  assert.equal(store.puts.length, 0);
  assert.deepEqual(JSON.parse(await store.get(manifestKey)).accounts.sample, previous);
});

test("each document write failure retains the previous manifest", async () => {
  const initial = new MemoryStore();
  await run(fixture(), initial);
  const oldManifest = await initial.get(manifestKey);
  for (let failure = 1; failure <= 5; failure++) {
    const store = initial.copy();
    let writes = 0;
    store.put = async (key, body) => {
      if (key !== manifestKey && ++writes === failure) throw new Error("injected write failure");
      store.values.set(key, body);
    };
    await assert.rejects(run(changedAddress(fixture()), store), /injected write failure/);
    assert.equal(await store.get(manifestKey), oldManifest);
  }
});

test("readback mismatch and manifest switch failure retain the previous manifest", async () => {
  const initial = new MemoryStore();
  await run(fixture(), initial);
  const oldManifest = await initial.get(manifestKey);
  const mismatch = initial.copy();
  const get = mismatch.get.bind(mismatch);
  let documentWritten = false;
  mismatch.put = async (key, body) => {
    mismatch.values.set(key, body);
    if (key !== manifestKey) documentWritten = true;
  };
  mismatch.get = async (key) => documentWritten && key !== manifestKey &&
    !initial.values.has(key) ? "corrupt" : get(key);
  await assert.rejects(run(changedAddress(fixture()), mismatch), /document readback mismatch/);
  assert.equal(await mismatch.get(manifestKey), oldManifest);

  const switchFailure = initial.copy();
  switchFailure.put = async (key, body) => {
    if (key === manifestKey) throw new Error("injected manifest failure");
    switchFailure.values.set(key, body);
  };
  await assert.rejects(run(changedAddress(fixture()), switchFailure), /injected manifest failure/);
  assert.equal(await switchFailure.get(manifestKey), oldManifest);
});

test("mixed pool versions abort before writes", async () => {
  const initial = new MemoryStore();
  await run(fixture(), initial);
  const oldManifest = await initial.get(manifestKey);
  const input = changedAddress(fixture());
  input.pools["sample-net/sg"].version = 1;
  const store = initial.copy();
  await assert.rejects(run(input, store), /validated v2 pool unavailable/);
  assert.equal(store.puts.length, 0);
  assert.equal(await store.get(manifestKey), oldManifest);
});

test("document keys stay within each account and never repeat", async () => {
  const store = new MemoryStore();
  await run(fixture(["sample-a", "sample-b"]), store);
  const manifest = JSON.parse(await store.get(manifestKey));
  const keys = [];
  for (const [id, account] of Object.entries(manifest.accounts)) {
    for (const key of [...Object.values(account.profiles), ...Object.values(account.providers)]) {
      assert.ok(key.startsWith(`accounts/${id}/`));
      keys.push(key);
    }
  }
  assert.equal(new Set(keys).size, keys.length);
});

test("reused account token and failed local validation abort before writes", async () => {
  const two = fixture(["sample-a", "sample-b"]);
  two.runtimeByAccount["sample-b"].deliveryToken =
    two.runtimeByAccount["sample-a"].deliveryToken;
  const store = new MemoryStore();
  await assert.rejects(run(two, store), /reused delivery identity/);
  assert.equal(store.puts.length, 0);

  await assert.rejects(
    run(fixture(), store, { validateDocument: null }),
    /static document validator required/,
  );
  assert.equal(store.puts.length, 0);

  await assert.rejects(
    run(fixture(), store, { validateDocument: async () => {
      throw new Error("injected static validation failure");
    } }),
    /injected static validation failure/,
  );
  assert.equal(store.puts.length, 0);
});
