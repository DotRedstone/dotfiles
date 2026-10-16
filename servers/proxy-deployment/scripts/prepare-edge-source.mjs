#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(fs.readFileSync(path.resolve(here, "../edge-worker-source.json"), "utf8"));
const repository = process.argv[2];
if (!repository || manifest.version !== 1 || !/^[0-9a-f]{40}$/.test(manifest.revision) ||
    !/^sha256-[A-Za-z0-9+/=]+$/.test(manifest.narHash)) {
  throw new Error("usage: prepare-edge-source.mjs WORKER_REPOSITORY");
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout: 30000, maxBuffer: 1024 * 1024 });
  if (result.status !== 0) throw new Error("pinned Worker source preparation failed");
  return result.stdout.trim();
}

const resolved = run("git", ["-C", repository, "rev-parse", "--verify", `${manifest.revision}^{commit}`]);
if (resolved !== manifest.revision) throw new Error("pinned Worker commit unavailable");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "edge-source-"));
try {
  fs.chmodSync(temporary, 0o700);
  const source = path.join(temporary, "source");
  const archive = path.join(temporary, "source.tar");
  fs.mkdirSync(source, { mode: 0o700 });
  run("git", ["-C", repository, "archive", "--format=tar", `--output=${archive}`, manifest.revision]);
  run("tar", ["-xf", archive, "-C", source]);
  if (run("nix", ["hash", "path", "--sri", source]) !== manifest.narHash) {
    throw new Error("pinned Worker source hash mismatch");
  }
  const storePath = run("nix", ["store", "add-path", "--name", "edge-proxy-worker-source", source]);
  process.stdout.write(`${storePath}\n`);
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
