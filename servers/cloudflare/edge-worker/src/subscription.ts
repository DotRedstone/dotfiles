import { utf8ToBase64 } from "./bytes";
import { getPreferredEndpoints } from "./preferred-ips";
import type { Env, PreferredEndpoint } from "./types";

function formatAddress(address: string): string {
  return address.includes(":") ? `[${address}]` : address;
}

function query(parameters: Record<string, string>): string {
  return new URLSearchParams(parameters).toString();
}

function nodeName(
  siteName: string,
  endpoint: PreferredEndpoint,
  transport: string,
): string {
  return encodeURIComponent(`${siteName}-${endpoint.label}-${transport}`);
}

function buildLinks(env: Env, endpoints: PreferredEndpoint[]): string[] {
  const host = env.PUBLIC_HOST.trim().toLowerCase();
  const path = `/edge/${env.ROUTE_SECRET}`;
  const siteName = (env.SITE_NAME ?? "edge").trim().slice(0, 32) || "edge";
  const links: string[] = [];

  for (const endpoint of endpoints) {
    const authority = `${formatAddress(endpoint.address)}:${endpoint.port}`;
    links.push(
      `vless://${env.VLESS_UUID}@${authority}?${query({
        encryption: "none",
        security: "tls",
        sni: host,
        fp: "chrome",
        type: "ws",
        host,
        path: `${path}?ed=2560`,
      })}#${nodeName(siteName, endpoint, "VLESS-WS")}`,
    );
    links.push(
      `vless://${env.VLESS_UUID}@${authority}?${query({
        encryption: "none",
        security: "tls",
        sni: host,
        fp: "chrome",
        type: "xhttp",
        mode: "stream-one",
        host,
        path,
      })}#${nodeName(siteName, endpoint, "VLESS-XHTTP")}`,
    );
    links.push(
      `trojan://${encodeURIComponent(env.TROJAN_PASSWORD)}@${authority}?${query(
        {
          security: "tls",
          sni: host,
          fp: "chrome",
          type: "ws",
          host,
          path: `${path}?ed=2560`,
        },
      )}#${nodeName(siteName, endpoint, "Trojan-WS")}`,
    );
  }
  return links;
}

export async function subscriptionResponse(
  request: Request,
  env: Env,
): Promise<Response> {
  const endpoints = await getPreferredEndpoints(env);
  const plain = buildLinks(env, endpoints).join("\n");
  const format = new URL(request.url).searchParams.get("format");
  const body = format === "plain" ? plain : utf8ToBase64(plain);
  return new Response(body, {
    headers: {
      "Cache-Control": "private, no-store",
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
}
