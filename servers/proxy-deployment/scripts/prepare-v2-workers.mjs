#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const directory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const servers = path.resolve(directory, "..");
const lock = JSON.parse(fs.readFileSync(path.join(servers, "flake.lock"), "utf8"));
const worker = lock.nodes.edgeProxyWorker.locked;
const compiler = lock.nodes.proxyStack.locked.rev;
const expectedWorker = "ad806d4f7f0737c8c079e91403620671b504f868";
const expectedHash = "sha256-quUz8e0jdxYZjdHjB/gE8hFhOmFedhp/INyg8GBovWk=";

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.error) throw new Error(`${command} failed: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${command} failed: ${result.stderr || result.stdout}`);
  return result.stdout?.trim() ?? "";
}

function read(name) {
  return JSON.parse(fs.readFileSync(path.join(directory, name), "utf8"));
}

function readResources(dryRun) {
  if (dryRun) return read("cloudflare-resources.example.json");
  const raw = run("sops", ["-d", "--extract", '["canary"]["resources_json"]',
    path.join(servers, "secrets", "cloudflare.yaml")]);
  return JSON.parse(raw);
}

function readSources(dryRun) {
  if (dryRun) return read("preferred-sources.example.json");
  const raw = run("sops", ["-d", "--extract", '["canary"]["sources_json"]',
    path.join(servers, "secrets", "cloudflare.yaml")]);
  return JSON.parse(raw);
}

function readOriginIds(dryRun, nodes) {
  if (dryRun) {
    return Object.fromEntries(Object.keys(nodes.origins).map((id) => [id, `${id}-origin`]));
  }
  const raw = run("sops", ["-d", "--extract", '["canary"]["origin_ids_json"]',
    path.join(servers, "secrets", "cloudflare.yaml")]);
  return JSON.parse(raw);
}

function write(destination, value) {
  fs.writeFileSync(destination, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600, flag: "wx" });
}

function prepare(output, accountId, source, dryRun, alternateCompiler) {
  const resources = readResources(dryRun);
  const sources = readSources(dryRun);
  const nodes = read(dryRun ? "nodes.example.json" : "nodes.json");
  if (dryRun) sources.sources = sources.sources
    .filter((item) => nodes.origins[item.origin])
    .map((item) => ({ ...item, type: "signed-upload" }));
  if (resources.version !== 1 || sources.version !== 1 || nodes.version !== 1) {
    throw new Error("unsupported deployment catalog");
  }
  if (resources.preferredControl.workerName === resources.delivery.workerName ||
      resources.preferredControl.entrypoint !== "src/preferred-v2.ts" ||
      resources.delivery.entrypoint !== "src/delivery.ts" ||
      resources.preferredControl.kv.id === resources.delivery.kv.id ||
      resources.preferredControl.kv.binding !== "PREFERRED_V2_STATE" ||
      resources.delivery.kv.binding !== "DELIVERY_STATE") {
    throw new Error("v2 Workers require separate KV namespaces");
  }
  if (!/^[a-z0-9-]+(?:\.[a-z0-9-]+)+$/.test(resources.delivery.customDomain)) {
    throw new Error("delivery Worker requires a fixed custom domain");
  }
  const origins = Object.keys(nodes.origins);
  const originIds = readOriginIds(dryRun, nodes);
  if (origins.length === 0 || origins.some((id) => !originIds[id]) ||
      Object.keys(originIds).some((id) => !nodes.origins[id]) ||
      sources.sources.some((item) => !nodes.origins[item.origin])) {
    throw new Error("inconsistent deployment origin catalog");
  }
  const main = (entrypoint) => {
    const file = path.join(source, entrypoint);
    if (!fs.existsSync(file)) throw new Error(`missing locked Worker entrypoint: ${entrypoint}`);
    return file;
  };
  const base = (resource) => ({
    account_id: accountId,
    name: resource.workerName,
    main: main(resource.entrypoint),
    compatibility_date: "2026-09-01",
    workers_dev: false,
    kv_namespaces: [{ binding: resource.kv.binding, id: resource.kv.id }],
  });
  const approved = {
    version: 1,
    sources: sources.sources.filter((item) =>
      item.type === "signed-upload" || item.type === "github-public"),
  };
  const publicNodes = {
    version: 1,
    origins: Object.fromEntries(origins.map((origin) => [
      origin, { cf: nodes.origins[origin].cf },
    ])),
  };
  const preferred = {
    ...base(resources.preferredControl),
    vars: {
      APPROVED_SOURCES_JSON: JSON.stringify(approved),
      PUBLIC_NODES_JSON: JSON.stringify(publicNodes),
      EXPECTED_ORIGIN_IDS_JSON: JSON.stringify(originIds),
      MAX_MEASUREMENT_AGE_SECONDS: "3600",
    },
  };
  const delivery = {
    ...base(resources.delivery),
    routes: [{ pattern: resources.delivery.customDomain, custom_domain: true }],
    vars: {
      EXPECTED_COMPILER_REVISION: compiler,
      ...(alternateCompiler ? { ALTERNATE_COMPILER_REVISION: alternateCompiler } : {}),
    },
  };
  const references = {
    preferredControl: {
      SIGNING_KEYS_JSON: "sops://servers/secrets/cloudflare.yaml#canary.upload_keys.la,canary.upload_keys.sg (assemble v1 signing map)",
      PREFERRED_READ_TOKEN: "sops://servers/secrets/cloudflare.yaml#canary.preferred_read_token",
      PROBE_ENDPOINTS_JSON: "sops://servers/secrets/cloudflare.yaml#canary.probe_endpoints_json (pending two-region secret)",
    },
    delivery: {
      DELIVERY_TOKEN_HASHES_JSON: "sops://servers/secrets/{conduit,hopper}.yaml#proxy/delivery_runtime (derive SHA-256 token map on publisher host)",
    },
  };
  write(path.join(output, "preferred-v2.json"), preferred);
  write(path.join(output, "delivery-v2.json"), delivery);
  write(path.join(output, "secret-references.json"), references);
  write(path.join(output, "source.json"), { workerRevision: worker.rev, workerNarHash: worker.narHash, compilerRevision: compiler });
}

function main() {
  const args = process.argv.slice(2);
  const values = new Map();
  for (let index = 0; index < args.length; index++) {
    const name = args[index];
    if (!["--dry-run", "--out", "--account-id", "--alternate-compiler-revision"].includes(name) ||
        values.has(name)) throw new Error("duplicate or unknown v2 Worker option");
    if (name === "--dry-run") {
      values.set(name, true);
    } else {
      const value = args[++index];
      if (!value || value.startsWith("--")) throw new Error("missing v2 Worker option value");
      values.set(name, value);
    }
  }
  const dryRun = values.has("--dry-run");
  const alternateCompiler = values.get("--alternate-compiler-revision") ?? null;
  if ((dryRun ? values.has("--out") || values.has("--account-id") :
      !values.has("--out") || !values.has("--account-id")) ||
    (alternateCompiler !== null && (!/^[0-9a-f]{40}$/.test(alternateCompiler) ||
      alternateCompiler === compiler))) {
    throw new Error("usage: prepare-v2-workers.mjs [--dry-run | --out DIR --account-id ID] [--alternate-compiler-revision SHA]");
  }
  if (worker.rev !== expectedWorker || worker.narHash !== expectedHash || !/^[0-9a-f]{40}$/.test(compiler)) {
    throw new Error("unexpected locked Worker or compiler revision");
  }
  const source = run("nix", ["eval", "--raw", "--impure", "--expr",
    `(builtins.getFlake "path:${servers}").inputs.edgeProxyWorker.outPath`]);
  if (run("nix", ["hash", "path", source]) !== expectedHash) {
    throw new Error("locked Worker source hash mismatch");
  }
  const accountId = dryRun ? "00000000000000000000000000000000" : values.get("--account-id");
  if (!/^[0-9a-f]{32}$/i.test(accountId)) throw new Error("invalid Cloudflare account ID");
  const output = dryRun ? fs.mkdtempSync(path.join(os.tmpdir(), "preferred-v2-workers-")) : path.resolve(values.get("--out"));
  try {
    if (!dryRun) fs.mkdirSync(output, { mode: 0o700 });
    prepare(output, accountId, source, dryRun, alternateCompiler);
    if (dryRun) {
      const checkout = process.env.EDGE_PROXY_WORKER_CHECKOUT;
      if (!checkout || run("git", ["-C", checkout, "rev-parse", "HEAD"]) !== expectedWorker) {
        throw new Error("EDGE_PROXY_WORKER_CHECKOUT must point to locked Worker revision");
      }
      const wrangler = path.join(checkout, "node_modules", ".bin", "wrangler");
      if (!fs.existsSync(wrangler)) throw new Error("run npm ci in edge-proxy-worker first");
      for (const name of ["preferred-v2", "delivery-v2"]) {
        run(wrangler, ["deploy", "--dry-run", "--config", path.join(output, `${name}.json`)],
          {
            cwd: checkout,
            stdio: "inherit",
            timeout: 60000,
            // Banner 的在线版本检查可能在本机 DNS 代理上挂起；打包无需该请求。
            env: { ...process.env, WRANGLER_HIDE_BANNER: "true", WRANGLER_SEND_METRICS: "false" },
          });
      }
      process.stdout.write("v2 Wrangler dry-run passed for both locked entrypoints\n");
    } else {
      process.stdout.write(`Prepared v2 Worker configs and secret references in ${output}\n`);
    }
  } finally {
    if (dryRun) fs.rmSync(output, { recursive: true, force: true });
  }
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}
