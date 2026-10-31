#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { parseTarget } from "./targets.mjs";

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
const host = parseTarget(process.argv.slice(2)).publicHost;

const result = spawnSync(
  "sops",
  ["decrypt", "--output-type", "json", secretsPath],
  {
    encoding: "utf8",
  },
);
if (result.status !== 0) {
  throw new Error(result.stderr || "unable to decrypt Cloudflare secrets");
}

const configTokens = JSON.parse(result.stdout).edge_next.config_tokens;
for (const profile of ["router", "desktop", "mobile", "root"]) {
  console.log(
    `${profile}: https://${host}/clash/${configTokens[profile]}/${profile}`,
  );
}
