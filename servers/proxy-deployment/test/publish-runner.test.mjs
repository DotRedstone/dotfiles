import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";
import { cloudflareStore, readPrivateRuntime, readValidatedPools, requireEnabledAccount, runPublication } from "../scripts/publish-runner.mjs";

const token = "T".repeat(40);
const catalog = { accounts: { accounts: { sample: {
  enabled: true, sourceIdByOrigin: { la: "sample-net", sg: "sample-net" },
} } } };

test("reads sops-nix runtime JSON only from an owner-private file", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "proxy-private-runtime-"));
  try {
    const file = path.join(directory, "runtime.json");
    const runtime = { version: 1, preferredReadToken: token };
    fs.writeFileSync(file, JSON.stringify(runtime), { mode: 0o400 });
    assert.deepEqual(readPrivateRuntime(file), runtime);
    fs.chmodSync(file, 0o440);
    assert.throws(() => readPrivateRuntime(file), /owner-only regular file/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("live apply gate rejects an empty or disabled account catalog", () => {
  assert.throws(() => requireEnabledAccount({ accounts: { accounts: {} } }),
    /requires an enabled account/);
  assert.throws(() => requireEnabledAccount({ accounts: { accounts: { sample: { enabled: false } } } }),
    /requires an enabled account/);
  assert.doesNotThrow(() => requireEnabledAccount(catalog));
});

test("reads only approved source and origin pools with the private bearer token", async () => {
  const requests = [];
  const pools = await readValidatedPools({
    catalog, baseUrl: "https://preferred.example.test", token,
    fetchImpl: async (url, init) => {
      requests.push({ url, init });
      return new Response(JSON.stringify({ version: 2, origin: url.endsWith("/la") ? "la" : "sg" }));
    },
  });
  assert.equal(requests.length, 2);
  assert.deepEqual(Object.keys(pools), ["sample-net/la", "sample-net/sg"]);
  assert.ok(requests.every(({ init }) => init.headers.Authorization === `Bearer ${token}`));
  assert.ok(requests.every(({ url }) => url.startsWith("https://preferred.example.test/v2/preferred/sample-net/")));
});

test("isolated Cloudflare KV adapter uses scoped paths and preserves missing keys", async () => {
  const values = new Map();
  const calls = [];
  const adapter = cloudflareStore({
    accountId: "a".repeat(32), namespaceId: "b".repeat(32), apiToken: "c".repeat(40),
    fetchImpl: async (url, init) => {
      calls.push({ url, init });
      const key = decodeURIComponent(url.split("/values/")[1]);
      if (init.method === "PUT") {
        values.set(key, init.body);
        return new Response(null, { status: 200 });
      }
      return values.has(key)
        ? new Response(values.get(key))
        : new Response("Not Found", { status: 404 });
    },
  });
  assert.equal(await adapter.get("delivery/manifest/v1"), null);
  await adapter.put("accounts/sample/release/router", "sample-body");
  assert.equal(await adapter.get("accounts/sample/release/router"), "sample-body");
  assert.ok(calls.every(({ url }) => url.startsWith(
    `https://api.cloudflare.com/client/v4/accounts/${"a".repeat(32)}/storage/kv/namespaces/${"b".repeat(32)}/values/`,
  )));
  assert.equal(calls[1].init.headers.Authorization, `Bearer ${"c".repeat(40)}`);
});

test("pool response is limited while reading the stream", async () => {
  let reads = 0;
  const body = new ReadableStream({
    pull(controller) {
      reads++;
      controller.enqueue(new Uint8Array(40000));
      if (reads > 2) controller.close();
    },
  });
  await assert.rejects(readValidatedPools({
    catalog, baseUrl: "https://preferred.example.test", token,
    fetchImpl: async () => new Response(body),
  }), /response exceeds limit/);
  assert.ok(reads <= 3);
});

const realValidationReady = [
  "PROXY_STACK_SOURCE", "MIHOMO_BIN", "GEOSITE_PATH", "GEOIP_PATH",
].every((name) => process.env[name]);

test("enabled synthetic account runs Mihomo validation before isolated KV publish", {
  skip: !realValidationReady,
}, async () => {
  const source = process.env.PROXY_STACK_SOURCE;
  const compiler = await import(pathToFileURL(path.join(source, "src/compiler.mjs")));
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "proxy-publish-fixture-"));
  try {
    fs.chmodSync(directory, 0o700);
    fs.mkdirSync(path.join(directory, "profiles"));
    const account = {
      enabled: true, primaryOrigin: "la",
      sourceIdByOrigin: { la: "sample-net", sg: "sample-net" },
      allowedExits: ["la-direct", "la-cf", "sg-direct", "sg-cf"],
      quotaGiB: 1, expiresAt: null,
    };
    const data = {
      "accounts.json": { version: 1, accounts: { sample: account } },
      "nodes.json": { version: 1, origins: Object.fromEntries(
        ["la", "sg"].map((origin) => [origin, {
          direct: { server: "192.0.2.1", port: 20002, serverName: "example.com" },
          cf: { host: `${origin}.example.test`, port: 443 },
        }]),
      ) },
      "preferred-sources.json": { version: 1, sources: ["la", "sg"].map((origin) => ({
        sourceId: "sample-net", type: "signed-upload", origin, accessNetwork: "sample-access",
      })) },
      "owned-domains.json": { version: 1, suffixes: [], hosts: [], addresses: [] },
    };
    for (const [name, body] of Object.entries(data)) {
      fs.writeFileSync(path.join(directory, name), JSON.stringify(body), { mode: 0o600 });
    }
    for (const kind of ["router", "desktop", "mobile"]) {
      fs.writeFileSync(path.join(directory, "profiles", `${kind}.json`), JSON.stringify({
        version: 1, kind,
        settings: { "mixed-port": 7890, "allow-lan": kind === "router",
          tun: { enable: false }, dns: { enable: false } },
      }), { mode: 0o600 });
    }
    const now = new Date("2026-10-11T02:00:00Z");
    const stamp = "2026-10-11T01:00:00Z";
    const values = new Map();
    const store = {
      get: async (key) => values.get(key) ?? null,
      put: async (key, body) => { values.set(key, body); },
    };
    const result = await runPublication({
      config: {
        catalogDir: directory, compilerRevision: "a".repeat(40),
        preferredBaseUrl: "https://preferred.example.test",
        maxPoolAgeSeconds: 86400, mihomoBin: process.env.MIHOMO_BIN,
        geoSitePath: process.env.GEOSITE_PATH, geoIpPath: process.env.GEOIP_PATH,
      },
      secrets: { preferredReadToken: token, runtimeByAccount: { sample: {
        accountId: "sample", deliveryBaseUrl: "https://config.example",
        deliveryToken: "A".repeat(40),
        credentials: {
          uuidByOrigin: { la: "11111111-1111-4111-8111-111111111111",
            sg: "22222222-2222-4222-8222-222222222222" },
          realityByOrigin: Object.fromEntries(["la", "sg"].map((origin) => [origin, {
            publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            shortId: "12345678",
          }])),
          wsPathByOrigin: { la: "/sample-la", sg: "/sample-sg" },
        },
      } } },
      compiler, store, now,
      fetchImpl: async (url) => {
        const origin = url.endsWith("/la") ? "la" : "sg";
        return new Response(JSON.stringify({
          version: 2, sourceId: "sample-net", origin,
          accessNetwork: "sample-access", egressNetwork: "sample-egress",
          collectedAt: stamp, validatedAt: stamp,
          candidates: [{ address: origin === "la" ? "198.51.100.1" : "203.0.113.1",
            port: 443, latencyMs: 42, lossRate: 0 }],
        }));
      },
    });
    assert.deepEqual(result, { published: true, accountsChanged: 1, documentsWritten: 5 });
    const manifest = JSON.parse(values.get("delivery/manifest/v1"));
    assert.equal(manifest.accounts.sample.enabled, true);
    if (process.env.EDGE_WORKER_SOURCE) {
      const { serveDelivery } = await import(pathToFileURL(path.join(
        process.env.EDGE_WORKER_SOURCE, "src/delivery.ts",
      )));
      const deliveryToken = "A".repeat(40);
      const digest = createHash("sha256").update(deliveryToken).digest("hex");
      let reads = 0;
      const env = {
        DELIVERY_STATE: { get: async (key) => { reads++; return values.get(key) ?? null; } },
        DELIVERY_TOKEN_HASHES_JSON: JSON.stringify({ version: 1, accounts: { [digest]: "sample" } }),
        EXPECTED_COMPILER_REVISION: "a".repeat(40),
      };
      for (const kind of ["router", "desktop", "mobile"]) {
        const response = await serveDelivery(new Request(
          `https://config.example/u/${deliveryToken}/${kind}/mihomo.yaml`,
        ), env);
        assert.equal(response.status, 200);
        assert.equal(await response.text(), values.get(manifest.accounts.sample.profiles[kind]));
      }
      for (const region of ["la", "sg"]) {
        const name = `${region}-cf`;
        const response = await serveDelivery(new Request(
          `https://config.example/u/${deliveryToken}/desktop/providers/${name}.yaml`,
        ), env);
        assert.equal(response.status, 200);
        assert.equal(await response.text(), values.get(manifest.accounts.sample.providers[name]));
      }
      const before = reads;
      const rejected = await serveDelivery(new Request(
        `https://config.example/u/${"X".repeat(40)}/desktop/mihomo.yaml`,
      ), env);
      assert.equal(rejected.status, 404);
      assert.equal(reads, before);
    }
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
