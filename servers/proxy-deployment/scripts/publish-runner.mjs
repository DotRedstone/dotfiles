#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { publish } from "./publish-core.mjs";

const scriptPath = fileURLToPath(import.meta.url);
const catalogFiles = [
  "accounts.json", "nodes.json", "preferred-sources.json", "owned-domains.json",
];

function jsonFile(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

export function loadCatalog(directory) {
  const [accounts, nodes, sources, ownedDomains] = catalogFiles.map(
    (name) => jsonFile(path.join(directory, name)),
  );
  const profiles = Object.fromEntries(
    ["router", "desktop", "mobile"].map((kind) => [
      kind, jsonFile(path.join(directory, "profiles", `${kind}.json`)),
    ]),
  );
  return { accounts, nodes, sources, ownedDomains, profiles };
}

export function requireEnabledAccount(catalog) {
  if (!Object.values(catalog.accounts.accounts).some((account) => account.enabled)) {
    throw new Error("live publication requires an enabled account");
  }
}

async function boundedText(response, limit = 131072) {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > limit) {
        await reader.cancel();
        throw new Error("remote response exceeds limit");
      }
      chunks.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock();
  }
  return Buffer.concat(chunks).toString("utf8");
}

export async function readValidatedPools({ catalog, baseUrl, token, fetchImpl = fetch }) {
  const base = new URL(baseUrl);
  if (base.protocol !== "https:" || base.pathname !== "/" || base.search || base.hash ||
      base.username || base.password || !/^[A-Za-z0-9_-]{32,128}$/.test(token)) {
    throw new Error("invalid preferred read binding");
  }
  const requested = new Set();
  for (const account of Object.values(catalog.accounts.accounts)) {
    if (!account.enabled) continue;
    for (const origin of ["la", "sg"]) {
      requested.add(`${account.sourceIdByOrigin[origin]}/${origin}`);
    }
  }
  const pools = {};
  for (const identity of [...requested].sort()) {
    const [sourceId, origin] = identity.split("/");
    const response = await fetchImpl(
      `${base.origin}/v2/preferred/${sourceId}/${origin}`,
      { method: "GET", redirect: "error", signal: AbortSignal.timeout(10000),
        headers: { Authorization: `Bearer ${token}` } },
    );
    if (!response.ok) throw new Error("validated pool read failed");
    pools[identity] = JSON.parse(await boundedText(response, 65536));
  }
  return pools;
}

export function cloudflareStore({ accountId, namespaceId, apiToken, fetchImpl = fetch }) {
  if (!/^[a-f0-9]{32}$/i.test(accountId) || !/^[a-f0-9]{32}$/i.test(namespaceId) ||
      typeof apiToken !== "string" || apiToken.length < 20) {
    throw new Error("invalid private KV binding");
  }
  const root = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}/values/`;
  const url = (key) => `${root}${encodeURIComponent(key)}`;
  const headers = { Authorization: `Bearer ${apiToken}` };
  return {
    async get(key) {
      const response = await fetchImpl(url(key), {
        method: "GET", redirect: "error", signal: AbortSignal.timeout(10000), headers,
      });
      if (response.status === 404) return null;
      if (!response.ok) throw new Error("private KV read failed");
      return boundedText(response, 2 * 1024 * 1024);
    },
    async put(key, body) {
      const response = await fetchImpl(url(key), {
        method: "PUT", redirect: "error", signal: AbortSignal.timeout(10000),
        headers: { ...headers, "Content-Type": "text/plain; charset=utf-8" }, body,
      });
      if (!response.ok) throw new Error("private KV write failed");
    },
  };
}

function checkMihomo(binary, directory, kind) {
  const result = spawnSync(binary, ["-t", "-d", directory, "-f", path.join(directory, `${kind}.yaml`)], {
    encoding: "utf8", timeout: 20000, maxBuffer: 1024 * 1024,
  });
  if (result.status !== 0) throw new Error("Mihomo static validation failed");
}

export function mihomoValidator({ binary, geoSitePath, geoIpPath }) {
  for (const file of [binary, geoSitePath, geoIpPath]) {
    if (!file || !fs.existsSync(file)) throw new Error("local Mihomo validation input missing");
  }
  return async ({ key, body, documents }) => {
    if (!/\/(router|desktop|mobile)$/.test(key)) return;
    const kind = key.split("/").at(-1);
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "proxy-publish-check-"));
    try {
      fs.chmodSync(directory, 0o700);
      fs.copyFileSync(geoSitePath, path.join(directory, "GeoSite.dat"));
      fs.copyFileSync(geoIpPath, path.join(directory, "geoip.metadb"));
      fs.mkdirSync(path.join(directory, "providers"), { mode: 0o700 });
      const config = JSON.parse(body);
      for (const name of ["la-cf", "sg-cf"]) {
        const providerKey = [...documents.keys()].find((item) => item.endsWith(`/providers/${name}`));
        if (!providerKey) throw new Error("compiled provider missing");
        fs.writeFileSync(path.join(directory, "providers", `${name}.yaml`), documents.get(providerKey), { mode: 0o600 });
        config["proxy-providers"][name] = {
          type: "file", path: `./providers/${name}.yaml`,
          "health-check": { enable: true, url: "https://www.gstatic.com/generate_204", interval: 300 },
        };
      }
      fs.writeFileSync(path.join(directory, `${kind}.yaml`), `${JSON.stringify(config)}\n`, { mode: 0o600 });
      checkMihomo(binary, directory, kind);
    } finally {
      fs.rmSync(directory, { recursive: true, force: true });
    }
  };
}

export async function runPublication({ config, secrets, compiler, store, fetchImpl = fetch, now = new Date() }) {
  const catalog = loadCatalog(config.catalogDir);
  compiler.validateCatalog(catalog);
  const pools = await readValidatedPools({
    catalog, baseUrl: config.preferredBaseUrl,
    token: secrets.preferredReadToken, fetchImpl,
  });
  return publish({
    catalog, pools, compiler, compilerRevision: config.compilerRevision,
    runtimeByAccount: secrets.runtimeByAccount,
    store, maxPoolAgeSeconds: config.maxPoolAgeSeconds, now,
    validateDocument: mihomoValidator({
      binary: config.mihomoBin,
      geoSitePath: config.geoSitePath,
      geoIpPath: config.geoIpPath,
    }),
  });
}

function decrypt(file) {
  const result = spawnSync("sops", ["decrypt", "--output-type", "json", file], {
    encoding: "utf8", maxBuffer: 8 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error("private deployment data unavailable");
  return JSON.parse(result.stdout);
}

async function main() {
  const args = process.argv.slice(2);
  const value = (flag) => args[args.indexOf(flag) + 1];
  if (!args.includes("--config") || !args.includes("--secrets") ||
      args.includes("--apply") === args.includes("--check")) {
    throw new Error("usage: publish-runner --config FILE --secrets SOPS_FILE --check|--apply");
  }
  const config = jsonFile(value("--config"));
  if (config.version !== 1 || !config.lockFile || !config.compilerSource ||
      !config.flakeLockPath || !config.catalogDir) throw new Error("invalid publication configuration");
  if (!args.includes("--locked")) {
    const result = spawnSync("flock", ["-n", "-F", config.lockFile, process.execPath,
      scriptPath, ...args, "--locked"], { stdio: "inherit" });
    if (result.status !== 0) throw new Error("publication already running or failed");
    return;
  }
  const locked = jsonFile(config.flakeLockPath).nodes?.proxyStack?.locked;
  const lockedRevision = locked?.rev;
  if (!/^[0-9a-f]{40}$/.test(lockedRevision) || lockedRevision !== config.compilerRevision) {
    throw new Error("compiler source revision is not the deployment lock");
  }
  const sourceHash = spawnSync("nix", ["hash", "path", "--sri", config.compilerSource], {
    encoding: "utf8", timeout: 30000,
  });
  if (sourceHash.status !== 0 || sourceHash.stdout.trim() !== locked.narHash) {
    throw new Error("compiler source does not match the deployment lock hash");
  }
  const compiler = await import(pathToFileURL(path.join(config.compilerSource, "src/compiler.mjs")).href);
  if (args.includes("--apply")) requireEnabledAccount(loadCatalog(config.catalogDir));
  const secrets = decrypt(value("--secrets"));
  if (secrets.version !== 1) throw new Error("private deployment schema unsupported");
  const live = cloudflareStore({
    accountId: secrets.cloudflare.accountId,
    namespaceId: secrets.cloudflare.deliveryNamespaceId,
    apiToken: secrets.cloudflare.apiToken,
  });
  let store = live;
  if (args.includes("--check")) {
    const staged = new Map();
    store = {
      get: (key) => staged.has(key) ? staged.get(key) : live.get(key),
      put: async (key, body) => { staged.set(key, body); },
    };
  }
  const result = await runPublication({ config, secrets, compiler, store });
  process.stdout.write(`${args.includes("--check") ? "checked" : result.published ? "published" : "unchanged"}: ${result.accountsChanged} accounts, ${result.documentsWritten} documents\n`);
}

if (process.argv[1] === scriptPath) {
  main().catch(() => {
    process.stderr.write("proxy publication failed; inspect the manifest before retrying\n");
    process.exitCode = 1;
  });
}
