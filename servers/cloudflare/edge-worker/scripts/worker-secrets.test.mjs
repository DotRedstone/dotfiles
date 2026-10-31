import assert from "node:assert/strict";
import test from "node:test";

import {
  buildWorkerSecrets,
  normalizeSubNodesJson,
} from "./worker-secrets.mjs";

const edge = {
  vless_uuid: "00000000-0000-0000-0000-000000000000",
  trojan_password: "fake-trojan-password",
  route_secret: "fake-route-secret",
  subscription_token: "fake-subscription-token",
  preferred_endpoints_token: "fake-preferred-token",
  config_tokens: { router: "fake-config-token" },
  ip_update_key: "fake-ip-update-key",
};

const legacySecrets = {
  VLESS_UUID: edge.vless_uuid,
  TROJAN_PASSWORD: edge.trojan_password,
  ROUTE_SECRET: edge.route_secret,
  SUBSCRIPTION_TOKEN: edge.subscription_token,
  PREFERRED_ENDPOINTS_TOKEN: edge.preferred_endpoints_token,
  CONFIG_TOKENS: JSON.stringify(edge.config_tokens),
  IP_UPDATE_KEY: edge.ip_update_key,
};

function validSubNodes() {
  return {
    version: 1,
    origins: {
      la: {
        reality: {
          server: "reality.example.invalid",
          port: 443,
          uuid: "00000000-0000-0000-0000-000000000000",
          sni: "reality.example.invalid",
          publicKey: "0000000000000000000000000000000000000000000",
          shortId: "00000000",
        },
        ws: {
          host: "ws.example.invalid",
          port: 443,
          uuid: "00000000-0000-0000-0000-000000000000",
          path: "/ws",
        },
      },
    },
    includeWorkerRelay: false,
  };
}

function assertPathError(callback, expectedPath) {
  assert.throws(callback, (error) => {
    assert.equal(error.message, expectedPath);
    return true;
  });
}

test("omits SUB_NODES_JSON when the optional SOPS field is absent or empty", () => {
  for (const value of [undefined, null, "", "   "]) {
    const secrets = buildWorkerSecrets({ ...edge, sub_nodes_json: value });
    assert.deepEqual(secrets, legacySecrets);
    assert.equal(Object.hasOwn(secrets, "SUB_NODES_JSON"), false);
  }
});

test("normalizes both object and JSON-text inputs to compact JSON", () => {
  const subNodes = validSubNodes();
  const expected = JSON.stringify(subNodes);

  assert.equal(normalizeSubNodesJson(subNodes), expected);
  assert.equal(normalizeSubNodesJson(JSON.stringify(subNodes)), expected);
  assert.equal(
    buildWorkerSecrets({ ...edge, sub_nodes_json: subNodes }).SUB_NODES_JSON,
    expected,
  );
});

test("rejects missing Reality and WebSocket fields using field paths only", () => {
  const requiredFields = [
    ["reality", "server"],
    ["reality", "port"],
    ["reality", "uuid"],
    ["reality", "sni"],
    ["reality", "publicKey"],
    ["reality", "shortId"],
    ["ws", "host"],
    ["ws", "port"],
    ["ws", "uuid"],
    ["ws", "path"],
  ];

  for (const [section, field] of requiredFields) {
    const invalid = structuredClone(validSubNodes());
    delete invalid.origins.la[section][field];
    assertPathError(
      () => normalizeSubNodesJson(invalid),
      `edge_next.sub_nodes_json.origins.la.${section}.${field}`,
    );
  }
});

test("rejects unsupported versions without including the supplied value", () => {
  const invalid = validSubNodes();
  invalid.version = "DO_NOT_LOG_VERSION_VALUE";
  assertPathError(
    () => normalizeSubNodesJson(invalid),
    "edge_next.sub_nodes_json.version",
  );
});

test("rejects empty origins and non-boolean includeWorkerRelay", () => {
  const noOrigins = validSubNodes();
  noOrigins.origins = {};
  assertPathError(
    () => normalizeSubNodesJson(noOrigins),
    "edge_next.sub_nodes_json.origins",
  );

  const invalidRelay = validSubNodes();
  invalidRelay.includeWorkerRelay = "DO_NOT_LOG_RELAY_VALUE";
  assertPathError(
    () => normalizeSubNodesJson(invalidRelay),
    "edge_next.sub_nodes_json.includeWorkerRelay",
  );
});

test("does not include malformed JSON text in parse errors", () => {
  const invalidJson = '{"secret":"DO_NOT_LOG_JSON_VALUE"';
  assertPathError(
    () => normalizeSubNodesJson(invalidJson),
    "edge_next.sub_nodes_json",
  );
});
