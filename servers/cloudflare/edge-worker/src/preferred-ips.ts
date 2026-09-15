import { equalBytes } from "./bytes";
import type { Env, PreferredEndpoint, PreferredEndpointState } from "./types";

const KV_KEY = "preferred-endpoints-v1";
const MAXIMUM_BODY_BYTES = 256 * 1024;
const MAXIMUM_ENDPOINTS = 1000;
const MAXIMUM_CLOCK_SKEW_SECONDS = 300;

function normalizeAddress(value: string): string | undefined {
  const address = value.trim().replace(/^\[|\]$/g, "");
  if (!address || address.length > 253 || /[\s/#?@]/.test(address))
    return undefined;
  if (!/^[A-Za-z0-9:.-]+$/.test(address)) return undefined;
  return address;
}

function normalizeLabel(value: string, index: number): string {
  const compact = value
    .trim()
    .replace(/[\r\n#]/g, " ")
    .slice(0, 48);
  return compact || `CF-${String(index + 1).padStart(3, "0")}`;
}

function parseLine(line: string, index: number): PreferredEndpoint | undefined {
  const [targetPart = "", labelPart = ""] = line.split("#", 2);
  const csv = targetPart.split(",").map((part) => part.trim());
  let addressPart = csv[0] ?? "";
  let port = 443;
  let label = labelPart || csv[2] || csv[1] || "";

  const bracketed = addressPart.match(/^\[([^\]]+)](?::(\d+))?$/);
  const hostPort = addressPart.match(/^([^:]+):(\d+)$/);
  if (bracketed) {
    addressPart = bracketed[1]!;
    if (bracketed[2]) port = Number(bracketed[2]);
  } else if (hostPort) {
    addressPart = hostPort[1]!;
    port = Number(hostPort[2]);
  } else if (csv[1] && /^\d+$/.test(csv[1])) {
    port = Number(csv[1]);
    label = labelPart || csv[2] || "";
  }

  const address = normalizeAddress(addressPart);
  if (!address || !Number.isInteger(port) || port < 1 || port > 65535)
    return undefined;
  return { address, port, label: normalizeLabel(label, index) };
}

export function parsePreferredEndpoints(text: string): PreferredEndpoint[] {
  const endpoints: PreferredEndpoint[] = [];
  const seen = new Set<string>();

  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const endpoint = parseLine(trimmed, endpoints.length);
    if (!endpoint) throw new Error("invalid preferred endpoint list");
    const key = `${endpoint.address.toLowerCase()}:${endpoint.port}`;
    if (seen.has(key)) continue;
    seen.add(key);
    endpoints.push(endpoint);
    if (endpoints.length > MAXIMUM_ENDPOINTS)
      throw new Error("too many endpoints");
  }

  if (endpoints.length === 0) throw new Error("endpoint list is empty");
  return endpoints;
}

async function expectedSignature(
  key: string,
  payload: string,
): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(payload),
    ),
  );
}

function hexToBytes(value: string): Uint8Array | undefined {
  if (!/^[0-9a-f]{64}$/i.test(value)) return undefined;
  return Uint8Array.from({ length: 32 }, (_, index) =>
    Number.parseInt(value.slice(index * 2, index * 2 + 2), 16),
  );
}

export async function updatePreferredEndpoints(
  request: Request,
  env: Env,
): Promise<Response> {
  const timestampText = request.headers.get("X-Edge-Timestamp") ?? "";
  const suppliedSignature = hexToBytes(
    request.headers.get("X-Edge-Signature") ?? "",
  );
  const timestamp = Number(timestampText);
  const now = Math.floor(Date.now() / 1000);
  if (
    !suppliedSignature ||
    !Number.isInteger(timestamp) ||
    Math.abs(now - timestamp) > MAXIMUM_CLOCK_SKEW_SECONDS
  ) {
    return new Response("Not Found", { status: 404 });
  }

  const body = await request.text();
  if (new TextEncoder().encode(body).byteLength > MAXIMUM_BODY_BYTES) {
    return new Response("Payload Too Large", { status: 413 });
  }
  const expected = await expectedSignature(
    env.IP_UPDATE_KEY,
    `${timestampText}\n${body}`,
  );
  if (!equalBytes(suppliedSignature, expected)) {
    return new Response("Not Found", { status: 404 });
  }

  try {
    const endpoints = parsePreferredEndpoints(body);
    const state: PreferredEndpointState = {
      version: 1,
      updatedAt: new Date().toISOString(),
      endpoints,
    };
    await env.EDGE_STATE.put(KV_KEY, JSON.stringify(state));
    return new Response(null, { status: 204 });
  } catch {
    return new Response("Bad Request", { status: 400 });
  }
}

export async function getPreferredEndpoints(
  env: Env,
): Promise<PreferredEndpoint[]> {
  const state = await env.EDGE_STATE.get<PreferredEndpointState>(
    KV_KEY,
    "json",
  );
  if (
    state?.version === 1 &&
    Array.isArray(state.endpoints) &&
    state.endpoints.length > 0
  ) {
    return state.endpoints.slice(0, MAXIMUM_ENDPOINTS);
  }
  return [{ address: env.PUBLIC_HOST, port: 443, label: "CF-Origin" }];
}
