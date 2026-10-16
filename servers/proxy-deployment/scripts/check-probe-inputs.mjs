#!/usr/bin/env node

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createPrivateKey, createPublicKey, X509Certificate } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const directory = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const servers = path.resolve(directory, "..");
const lock = JSON.parse(fs.readFileSync(path.join(servers, "flake.lock"), "utf8"));
const expectedWorker = "052a959dad36e4ea23ca45a1885c657761a5903c";
const expectedHash = "sha256-dlZaqcG6ap80iBw5ZC9pdwcVFgaNW/fA5ikhNqYz4Ww=";
let failurePhase = "locked source";

function command(program, args) {
  const result = spawnSync(program, args, { encoding: "utf8", maxBuffer: 20 * 1024 * 1024 });
  if (result.status !== 0) throw new Error(`${program} failed`);
  return result.stdout.trim();
}

function decrypt(host) {
  return JSON.parse(command("sops", [
    "-d", "--output-type", "json", path.join(servers, "secrets", `${host}.yaml`),
  ]));
}

function parseEnvironment(value) {
  assert.equal(typeof value, "string");
  const lines = value.trim().split("\n");
  const entries = lines.map((line) => {
    const index = line.indexOf("=");
    assert.ok(index > 0, "invalid probe environment assignment");
    assert.ok(/^[A-Z][A-Z0-9_]+$/.test(line.slice(0, index)),
      "invalid probe environment name");
    let content = line.slice(index + 1);
    if (content.startsWith("'") && content.endsWith("'")) {
      content = content.slice(1, -1);
      assert.ok(!content.includes("'"));
    } else {
      assert.ok(/^[^\s'"]+$/.test(content), "invalid probe environment value");
    }
    return [line.slice(0, index), content];
  });
  assert.equal(new Set(entries.map(([name]) => name)).size, entries.length);
  return Object.fromEntries(entries);
}

function certificate(host, name, pem, privateKey) {
  const parts = pem.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g);
  assert.ok(parts?.length >= 2, `${host}: missing certificate chain`);
  const leaf = new X509Certificate(parts[0]);
  assert.ok(leaf.checkHost(name), `${host}: certificate hostname mismatch`);
  assert.ok(Date.now() > Date.parse(leaf.validFrom) && Date.now() < Date.parse(leaf.validTo),
    `${host}: certificate outside validity window`);
  assert.equal(leaf.publicKey.export({ type: "spki", format: "pem" }),
    createPublicKey(createPrivateKey(privateKey)).export({ type: "spki", format: "pem" }),
    `${host}: certificate and key mismatch`);

  // 仅将公开证书写入受限临时目录；私钥和 probe 环境始终只在内存中。
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "proxy-probe-cert-"));
  try {
    const leafPath = path.join(temporary, "leaf.pem");
    const chainPath = path.join(temporary, "chain.pem");
    fs.writeFileSync(leafPath, parts[0], { mode: 0o600 });
    fs.writeFileSync(chainPath, parts.slice(1).join("\n"), { mode: 0o600 });
    command("openssl", [
      "verify", "-CAfile", "/etc/ssl/certs/ca-certificates.crt",
      "-untrusted", chainPath, leafPath,
    ]);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

async function main() {
  assert.equal(lock.nodes.edgeProxyWorker.locked.rev, expectedWorker);
  assert.equal(lock.nodes.edgeProxyWorker.locked.narHash, expectedHash);
  const source = command("nix", [
    "eval", "--raw", "--impure", "--expr",
    `(builtins.getFlake "path:${servers}").inputs.edgeProxyWorker.outPath`,
  ]);
  assert.equal(command("nix", ["hash", "path", source]), expectedHash);
  const { configFromEnvironment } = await import(pathToFileURL(path.join(source, "probe/server.mjs")));

  failurePhase = "encrypted inputs";
  const cloudflare = decrypt("cloudflare");
  const endpoints = JSON.parse(cloudflare.canary.probe_endpoints_json);
  assert.equal(endpoints.version, 1);
  assert.deepEqual(Object.keys(endpoints.origins).sort(), ["la", "sg"]);
  const nodes = JSON.parse(fs.readFileSync(path.join(directory, "nodes.json"), "utf8"));
  const hosts = {
    conduit: { origin: "sg", other: "hopper", name: "probe-sg-v2-canary.bdot.in" },
    hopper: { origin: "la", other: "conduit", name: "probe-la-v2-canary.bdot.in" },
  };
  const secrets = Object.fromEntries(Object.keys(hosts).map((host) => [host, decrypt(host)]));
  const keys = [];
  for (const [host, { origin, other, name }] of Object.entries(hosts)) {
    failurePhase = `${host} mapping`;
    const proxy = secrets[host].proxy;
    const environment = parseEnvironment(proxy.probe_env);
    const config = configFromEnvironment(environment);
    const endpoint = endpoints.origins[origin];
    assert.equal(new URL(endpoint.url).href, `https://${name}/probe`);
    assert.ok(config.requestKey === endpoint.requestKey, `${host}: request key mismatch`);
    assert.ok(config.responseKey === endpoint.responseKey, `${host}: response key mismatch`);
    assert.deepEqual(Object.keys(config.origins), [origin]);
    const target = config.origins[origin];
    assert.equal(target.host, nodes.origins[origin].cf.host);
    assert.equal(target.port, 443);
    assert.equal(target.originId, `${origin}-origin`);
    assert.equal(target.path, "/proof");
    assert.ok(target.proofKey === secrets[other].proxy.origin_proof_key,
      `${host}: proof key mismatch`);
    assert.ok(target.accessToken === secrets[other].proxy.origin_proof_token,
      `${host}: proof token mismatch`);
    failurePhase = `${host} certificate`;
    certificate(host, name, proxy.probe_tls_cert, proxy.probe_tls_key);
    keys.push(config.requestKey, config.responseKey);
    process.stdout.write(`${host}: probe input, cross-origin proof, and TLS chain passed\n`);
  }
  failurePhase = "cross-region keys";
  assert.equal(new Set(keys).size, 4, "probe HMAC keys must be distinct");
  process.stdout.write("dual-region probe input check passed\n");
}

main().catch(() => {
  // 第三方解析器的异常可能包含解密正文；只打印固定阶段名称。
  process.stderr.write(`probe input check failed: ${failurePhase}\n`);
  process.exitCode = 1;
});
