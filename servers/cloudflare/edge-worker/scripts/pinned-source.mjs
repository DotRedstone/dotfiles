import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

export const sourceRepository = "/home/dot/Projects/edge-proxy-worker";
export const sourceCommit = "489e9bbbb8ad54c0e6f76a1e6fbe0cf959276ea0";

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

export function preparePinnedSource(temporaryDirectory) {
  const resolved = run("git", [
    "-C",
    sourceRepository,
    "rev-parse",
    "--verify",
    `${sourceCommit}^{commit}`,
  ]).trim();
  if (resolved !== sourceCommit) {
    throw new Error("pinned Worker commit does not match the local Git object");
  }

  const archivePath = path.join(temporaryDirectory, "worker.tar");
  const sourceDirectory = path.join(temporaryDirectory, "source");
  fs.mkdirSync(sourceDirectory, { mode: 0o700 });
  run("git", [
    "-C",
    sourceRepository,
    "archive",
    "--format=tar",
    `--output=${archivePath}`,
    sourceCommit,
  ]);
  run("tar", ["-xf", archivePath, "-C", sourceDirectory]);
  fs.rmSync(archivePath);
  run("npm", ["ci", "--no-audit", "--no-fund"], { cwd: sourceDirectory });
  return sourceDirectory;
}
