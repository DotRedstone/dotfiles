import test from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { manifestKey, publish } from "../scripts/publish-core.mjs";

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

function newer(input) {
  const changed = structuredClone(input);
  changed.pools["sample-net/la"].validatedAt = "2026-10-11T01:30:00Z";
  return changed;
}

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
    await assert.rejects(run(newer(fixture()), store), /injected write failure/);
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
  await assert.rejects(run(newer(fixture()), mismatch), /document readback mismatch/);
  assert.equal(await mismatch.get(manifestKey), oldManifest);

  const switchFailure = initial.copy();
  switchFailure.put = async (key, body) => {
    if (key === manifestKey) throw new Error("injected manifest failure");
    switchFailure.values.set(key, body);
  };
  await assert.rejects(run(newer(fixture()), switchFailure), /injected manifest failure/);
  assert.equal(await switchFailure.get(manifestKey), oldManifest);
});

test("mixed pool versions abort before writes", async () => {
  const initial = new MemoryStore();
  await run(fixture(), initial);
  const oldManifest = await initial.get(manifestKey);
  const input = newer(fixture());
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
