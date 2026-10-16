#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

import { preparePinnedSource } from "./pinned-source.mjs";

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
const workerName = "edge-proxy-next";
const preferredControlWorkerName = "edge-preferred-control";
const namespaceTitle = "edge-proxy-next-state";
const publicHost = "edge-next.dotdot.ggff.net";
const preferredPools = ["la", "sg"];
const preferredPoolVars = {
  PREFERRED_POOLS: JSON.stringify(preferredPools),
  DEFAULT_PREFERRED_POOL: "la",
};
const dryRun = process.argv.includes("--dry-run");

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

async function ensureNamespace(credentials) {
  const namespaces = await cloudflareApi(
    credentials,
    `/accounts/${credentials.account_id}/storage/kv/namespaces?per_page=100`,
  );
  const existing = namespaces.find((item) => item.title === namespaceTitle);
  if (existing) return existing.id;
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
    "--secrets-file",
    secretsPath,
    "--strict",
    "--minify",
    "--message",
    message,
  ];
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
  const runtimeDirectory = process.env.XDG_RUNTIME_DIR ?? os.tmpdir();
  const temporaryDirectory = fs.mkdtempSync(
    path.join(runtimeDirectory, "edge-worker-deploy-"),
  );
  try {
    const sourceDirectory = preparePinnedSource(temporaryDirectory);
    const { buildProfiles } = await import(
      pathToFileURL(path.join(sourceDirectory, "scripts", "clash-config.mjs"))
        .href
    );
    const stored = loadSecrets();
    const credentials = stored.accounts.proxy;
    const edge = stored.edge_next;
    const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
    const profiles = buildProfiles({
      baseline,
      providers: stored.clash?.providers,
    });
    if (Object.keys(profiles).length !== 4) {
      throw new Error("expected exactly four Clash profiles");
    }
    // Dry run must stay local; the placeholder validates Wrangler's binding shape.
    const namespaceId = dryRun
      ? "00000000000000000000000000000000"
      : await ensureNamespace(credentials);
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

    if (!dryRun) {
      await deployClashProfiles(credentials, namespaceId, profiles);
    }
    fs.writeFileSync(
      configPath,
      `${JSON.stringify(
        {
          account_id: credentials.account_id,
          name: workerName,
          main: path.join(sourceDirectory, "src", "index.ts"),
          compatibility_date: "2026-09-01",
          // Keep a private-token control-plane fallback independent of the
          // custom domain.  It is used only for configuration and preferred
          // endpoint lists; traffic nodes keep their own CDN hostnames.
          workers_dev: true,
          routes: [{ pattern: publicHost, custom_domain: true }],
          kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
          vars: {
            PUBLIC_HOST: publicHost,
            SITE_NAME: "CF-Next",
            DOH_URL: "https://dns.google/dns-query",
            ...preferredPoolVars,
          },
        },
        null,
        2,
      )}\n`,
      { mode: 0o600 },
    );
    fs.writeFileSync(workerSecretsPath, JSON.stringify(workerSecrets), {
      mode: 0o600,
    });

    deployWorker({
      sourceDirectory,
      configPath,
      secretsPath: workerSecretsPath,
      credentials,
      message: "原子化边缘代理声明式部署",
      dryRun,
    });
    fs.writeFileSync(
      preferredControlConfigPath,
      `${JSON.stringify(
        {
          account_id: credentials.account_id,
          name: preferredControlWorkerName,
          main: path.join(sourceDirectory, "src", "preferred-control.ts"),
          compatibility_date: "2026-09-01",
          workers_dev: true,
          kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
          vars: preferredPoolVars,
        },
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
        : `Workers ${workerName} and ${preferredControlWorkerName} deployed successfully.`,
    );
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

await main();
