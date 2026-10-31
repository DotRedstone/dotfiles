const rootPath = "edge_next.sub_nodes_json";

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requireNonEmpty(value, fieldPath) {
  if (
    value === undefined ||
    value === null ||
    (typeof value === "string" && value.trim() === "")
  ) {
    throw new Error(fieldPath);
  }
}

export function normalizeSubNodesJson(value) {
  if (
    value === undefined ||
    value === null ||
    (typeof value === "string" && value.trim() === "")
  ) {
    return undefined;
  }

  let parsed = value;
  if (typeof value === "string") {
    try {
      parsed = JSON.parse(value);
    } catch {
      throw new Error(rootPath);
    }
  }

  if (!isObject(parsed)) throw new Error(rootPath);
  if (parsed.version !== 1) throw new Error(`${rootPath}.version`);
  if (!isObject(parsed.origins) || Object.keys(parsed.origins).length === 0) {
    throw new Error(`${rootPath}.origins`);
  }

  for (const [poolName, pool] of Object.entries(parsed.origins)) {
    const poolPath = `${rootPath}.origins.${poolName}`;
    if (!isObject(pool)) throw new Error(poolPath);

    const realityPath = `${poolPath}.reality`;
    if (!isObject(pool.reality)) throw new Error(realityPath);
    for (const field of ["server", "port", "uuid", "sni", "publicKey", "shortId"]) {
      requireNonEmpty(pool.reality[field], `${realityPath}.${field}`);
    }

    const wsPath = `${poolPath}.ws`;
    if (!isObject(pool.ws)) throw new Error(wsPath);
    for (const field of ["host", "port", "uuid", "path"]) {
      requireNonEmpty(pool.ws[field], `${wsPath}.${field}`);
    }
  }

  if (
    Object.hasOwn(parsed, "includeWorkerRelay") &&
    typeof parsed.includeWorkerRelay !== "boolean"
  ) {
    throw new Error(`${rootPath}.includeWorkerRelay`);
  }

  try {
    return JSON.stringify(parsed);
  } catch {
    throw new Error(rootPath);
  }
}

export function buildWorkerSecrets(edge) {
  const secrets = {
    VLESS_UUID: edge.vless_uuid,
    TROJAN_PASSWORD: edge.trojan_password,
    ROUTE_SECRET: edge.route_secret,
    SUBSCRIPTION_TOKEN: edge.subscription_token,
    PREFERRED_ENDPOINTS_TOKEN: edge.preferred_endpoints_token,
    CONFIG_TOKENS: JSON.stringify(edge.config_tokens),
    IP_UPDATE_KEY: edge.ip_update_key,
  };

  const subNodesJson = normalizeSubNodesJson(edge.sub_nodes_json);
  if (subNodesJson !== undefined) {
    secrets.SUB_NODES_JSON = subNodesJson;
  }
  return secrets;
}
