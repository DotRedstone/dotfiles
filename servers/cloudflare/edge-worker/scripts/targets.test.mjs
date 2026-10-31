import assert from "node:assert/strict";
import test from "node:test";
import { parseTarget, buildMainConfig, buildPreferredControlConfig } from "./targets.mjs";

const sourceDirectory = "/tmp/worker-source";
const accountId = "test-account";
const namespaceId = "00000000000000000000000000000000";
const options = (target) => ({ target, accountId, namespaceId, sourceDirectory });

test("legacy is the default and environment can select bdot", () => {
  assert.equal(parseTarget([], {}).name, "legacy");
  assert.equal(parseTarget([], { EDGE_DEPLOY_TARGET: "bdot" }).publicHost, "edge-next.bdot.in");
  assert.equal(parseTarget(["--target", "bdot"], {}).name, "bdot");
  assert.equal(parseTarget(["--target=bdot"], {}).name, "bdot");
  assert.equal(parseTarget(["--target", "legacy"], { EDGE_DEPLOY_TARGET: "bdot" }).name, "legacy");
});

test("missing or unknown target fails", () => {
  assert.throws(() => parseTarget(["--target"], {}), /requires legacy or bdot/);
  assert.throws(() => parseTarget(["--target=unknown"], {}), /unknown deploy target/);
  assert.throws(() => parseTarget([], { EDGE_DEPLOY_TARGET: "other" }), /unknown deploy target/);
});

test("legacy main config matches pre-migration shape", () => {
  const target = parseTarget([], {});
  assert.deepEqual(buildMainConfig(options(target)), {
    account_id: accountId,
    name: "edge-proxy-next-recovery",
    main: "/tmp/worker-source/src/index.ts",
    compatibility_date: "2026-09-01",
    workers_dev: false,
    preview_urls: false,
    routes: [{ pattern: "edge-next.dotdot.ggff.net", custom_domain: true }],
    kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
    vars: {
      PUBLIC_HOST: "edge-next.dotdot.ggff.net",
      SITE_NAME: "CF-Next",
      DOH_URL: "https://dns.google/dns-query",
      PREFERRED_POOLS: '["la","sg"]',
      DEFAULT_PREFERRED_POOL: "la",
    },
  });
});

test("legacy preferred-control config matches pre-migration shape", () => {
  assert.deepEqual(buildPreferredControlConfig(options(parseTarget([], {}))), {
    account_id: accountId,
    name: "edge-preferred-control",
    main: "/tmp/worker-source/src/preferred-control.ts",
    compatibility_date: "2026-09-01",
    workers_dev: true,
    kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
    vars: {
      PREFERRED_POOLS: '["la","sg"]',
      DEFAULT_PREFERRED_POOL: "la",
    },
  });
});

test("bdot uses its own domains, retains workers.dev and injected KV id", () => {
  const target = parseTarget(["--target", "bdot"], {});
  const main = buildMainConfig(options(target));
  const control = buildPreferredControlConfig(options(target));
  assert.equal(target.accountKey, "sites");
  assert.deepEqual(main.routes, [{ pattern: "edge-next.bdot.in", custom_domain: true }]);
  assert.equal(main.vars.PUBLIC_HOST, "edge-next.bdot.in");
  assert.deepEqual(control.routes, [{ pattern: "preferred-control.bdot.in", custom_domain: true }]);
  assert.equal(control.workers_dev, true);
  assert.equal(main.kv_namespaces[0].id, namespaceId);
  assert.equal(control.kv_namespaces[0].id, namespaceId);
  assert.equal(JSON.stringify({ main, control }).includes("api_token"), false);
});
