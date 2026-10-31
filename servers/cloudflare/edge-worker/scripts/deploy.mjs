#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { preparePinnedSource } from "./pinned-source.mjs";
import { buildProfiles } from "./clash-profiles.mjs";
import { parseTarget, buildMainConfig, buildPreferredControlConfig } from "./targets.mjs";

const workerDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const secretsPath = path.resolve(
  workerDirectory,
  "..",
  "..",
  "secrets",
  "cloudflare.yaml",
);
const baselinePath = path.resolve(
  workerDirectory,
  "..",
  "..",
  "clash",
  "router-policy.json",
);
const dryRun = process.argv.includes("--dry-run");
const mainOnly = process.argv.includes("--main-only");
const withSecrets = process.argv.includes("--with-secrets");
const uploadSecrets = !mainOnly || withSecrets;

function run(command, arguments_, options = {}) {
  const result = spawnSync(command, arguments_, {
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
    ...options,
  });
  if (result.status !== 0) {
    throw new Error(`${command} failed: ${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function loadSecrets() {
  return JSON.parse(
    run("sops", ["decrypt", "--output-type", "json", secretsPath]),
  );
}

async function cloudflareApi(credentials, apiPath, init = {}) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4${apiPath}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${credentials.api_token}`,
        "Content-Type": "application/json",
        ...(init.headers ?? {}),
      },
    },
  );
  const body = await response.json();
  if (!response.ok || !body.success) {
    const message = (body.errors ?? [])
      .map((error) => error.message)
      .join("; ");
    throw new Error(`Cloudflare API ${response.status}: ${message}`);
  }
  return body.result;
}

async function ensureNamespace(credentials, namespaceTitle, allowCreate = true) {
  const namespaces = await cloudflareApi(
    credentials,
    `/accounts/${credentials.account_id}/storage/kv/namespaces?per_page=100`,
  );
  const existing = namespaces.find((item) => item.title === namespaceTitle);
  if (existing) return existing.id;
  if (!allowCreate) throw new Error(`KV namespace ${namespaceTitle} is missing`);
  const created = await cloudflareApi(
    credentials,
    `/accounts/${credentials.account_id}/storage/kv/namespaces`,
    {
      method: "POST",
      body: JSON.stringify({ title: namespaceTitle }),
    },
  );
  return created.id;
}

async function ensureWorkerRoute(credentials, host, workerName) {
  const domains = await cloudflareApi(
    credentials,
    `/accounts/${credentials.account_id}/workers/domains`,
  );
  const domain = domains.find((item) => item.hostname === host);
  if (!domain || domain.service !== workerName) {
    throw new Error(
      `custom domain ${host} is not attached to ${workerName}`,
    );
  }
  const routeBase = `/zones/${domain.zone_id}/workers/routes`;
  const pattern = `${host}/*`;
  const matches = (await cloudflareApi(credentials, routeBase)).filter(
    (route) => route.pattern === pattern,
  );
  if (matches.length > 1) throw new Error(`duplicate Worker route: ${pattern}`);
  if (matches[0]?.script === workerName) return;
  await cloudflareApi(
    credentials,
    matches.length === 1 ? `${routeBase}/${matches[0].id}` : routeBase,
    {
      method: matches.length === 1 ? "PUT" : "POST",
      body: JSON.stringify({ pattern, script: workerName }),
    },
  );
}

async function putNamespaceValue(credentials, namespaceId, key, value) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${credentials.account_id}/storage/kv/namespaces/${namespaceId}/values/${encodeURIComponent(key)}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${credentials.api_token}`,
        "Content-Type": "application/x-yaml; charset=utf-8",
      },
      body: value,
    },
  );
  if (!response.ok) {
    throw new Error(
      `Cloudflare KV upload ${response.status}: ${await response.text()}`,
    );
  }
}

async function deployClashProfiles(credentials, namespaceId, profiles) {
  for (const [profile, configuration] of Object.entries(profiles)) {
    await putNamespaceValue(
      credentials,
      namespaceId,
      `clash/config/${profile}`,
      configuration,
    );
  }
}

function deployWorker({
  sourceDirectory,
  configPath,
  secretsPath,
  credentials,
  message,
  dryRun,
}) {
  const arguments_ = [
    "wrangler",
    "deploy",
    "--config",
    configPath,
    "--strict",
    "--minify",
    "--message",
    message,
  ];
  if (secretsPath) arguments_.push("--secrets-file", secretsPath);
  if (dryRun) arguments_.push("--dry-run");
  const deployed = spawnSync("npx", arguments_, {
    cwd: sourceDirectory,
    env: {
      ...process.env,
      CLOUDFLARE_ACCOUNT_ID: credentials.account_id,
      CLOUDFLARE_API_TOKEN: credentials.api_token,
      WRANGLER_SEND_METRICS: "false",
    },
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
  });
  if (deployed.status !== 0) {
    throw new Error(`${deployed.stderr}\n${deployed.stdout}`);
  }
}

async function main() {
  const target = parseTarget(process.argv.slice(2));
  console.log(`target=${target.name} host=${target.publicHost}`);
  const runtimeDirectory = process.env.XDG_RUNTIME_DIR ?? os.tmpdir();
  const temporaryDirectory = fs.mkdtempSync(
    path.join(runtimeDirectory, "edge-worker-deploy-"),
  );
  try {
    const sourceDirectory = preparePinnedSource(temporaryDirectory);
    const stored = loadSecrets();
    const credentials = stored.accounts?.[target.accountKey];
    if (!credentials) {
      throw new Error(`missing SOPS stored.accounts.${target.accountKey} for target ${target.name}; confirm the account key before deploying`);
    }
    const edge = stored.edge_next;
    let profiles;
    if (!mainOnly) {
      const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
      profiles = buildProfiles({
        baseline,
        providers: stored.clash?.providers,
      });
      if (Object.keys(profiles).length !== 4) {
        throw new Error("expected exactly four Clash profiles");
      }
    }
    // Dry run must stay local; the placeholder validates Wrangler's binding shape.
    const namespaceId = dryRun
      ? "00000000000000000000000000000000"
      : process.env.EDGE_KV_NAMESPACE_ID?.trim() ||
        (await ensureNamespace(credentials, target.namespaceTitle, !mainOnly));
    const configPath = path.join(temporaryDirectory, "wrangler.jsonc");
    const workerSecretsPath = path.join(temporaryDirectory, "secrets.json");
    const preferredControlConfigPath = path.join(
      temporaryDirectory,
      "preferred-control.wrangler.jsonc",
    );
    const preferredControlSecretsPath = path.join(
      temporaryDirectory,
      "preferred-control.secrets.json",
    );
    const workerSecrets = {
      VLESS_UUID: edge.vless_uuid,
      TROJAN_PASSWORD: edge.trojan_password,
      ROUTE_SECRET: edge.route_secret,
      SUBSCRIPTION_TOKEN: edge.subscription_token,
      PREFERRED_ENDPOINTS_TOKEN: edge.preferred_endpoints_token,
      CONFIG_TOKENS: JSON.stringify(edge.config_tokens),
      IP_UPDATE_KEY: edge.ip_update_key,
    };

    if (!dryRun && !mainOnly) {
      await deployClashProfiles(credentials, namespaceId, profiles);
    }
    fs.writeFileSync(
      configPath,
      `${JSON.stringify(
        buildMainConfig({
          target,
          accountId: credentials.account_id,
          namespaceId,
          sourceDirectory,
        }),
        null,
        2,
      )}\n`,
      { mode: 0o600 },
    );
    if (uploadSecrets) {
      fs.writeFileSync(workerSecretsPath, JSON.stringify(workerSecrets), {
        mode: 0o600,
      });
    }

    deployWorker({
      sourceDirectory,
      configPath,
      secretsPath: uploadSecrets ? workerSecretsPath : undefined,
      credentials,
      message: "原子化边缘代理声明式部署",
      dryRun,
    });
    if (!dryRun) await ensureWorkerRoute(credentials, target.publicHost, target.workerName);
    if (mainOnly) {
      console.log(
        dryRun
          ? "Main Worker dry-run completed successfully."
          : `Worker ${target.workerName} deployed successfully.`,
      );
      return;
    }
    fs.writeFileSync(
      preferredControlConfigPath,
      `${JSON.stringify(
        buildPreferredControlConfig({
          target,
          accountId: credentials.account_id,
          namespaceId,
          sourceDirectory,
        }),
        null,
        2,
      )}\n`,
      { mode: 0o600 },
    );
    fs.writeFileSync(
      preferredControlSecretsPath,
      JSON.stringify({
        PREFERRED_ENDPOINTS_TOKEN: edge.preferred_endpoints_token,
        IP_UPDATE_KEY: edge.ip_update_key,
      }),
      { mode: 0o600 },
    );
    deployWorker({
      sourceDirectory,
      configPath: preferredControlConfigPath,
      secretsPath: preferredControlSecretsPath,
      credentials,
      message: "区域优选控制面声明式部署",
      dryRun,
    });
    console.log(
      dryRun
        ? "Worker dry-run completed successfully."
        : `Workers ${target.workerName} and ${target.preferredControlWorkerName} deployed successfully.`,
    );
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

await main();
