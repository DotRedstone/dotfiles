import { uuidToBytes } from "./bytes";
import { configurationProfile, configurationResponse } from "./clash-config";
import { updatePreferredEndpoints } from "./preferred-ips";
import { handleWebSocket, handleXHttp } from "./relay";
import { matchesTransportPath } from "./routes";
import { sha224Hex } from "./sha224";
import { subscriptionResponse } from "./subscription";
import type { Env, ProxyAuth } from "./types";

const SECRET_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

function hiddenNotFound(): Response {
  return new Response("404 Not Found\n", {
    status: 404,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function loadAuth(env: Env): ProxyAuth {
  if (!SECRET_PATTERN.test(env.ROUTE_SECRET))
    throw new Error("invalid route secret");
  if (!SECRET_PATTERN.test(env.SUBSCRIPTION_TOKEN)) {
    throw new Error("invalid subscription token");
  }
  if (env.TROJAN_PASSWORD.length < 16 || env.IP_UPDATE_KEY.length < 32) {
    throw new Error("weak secret");
  }
  return {
    uuid: uuidToBytes(env.VLESS_UUID),
    trojanHash: new TextEncoder().encode(sha224Hex(env.TROJAN_PASSWORD)),
  };
}

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    const transportPath = `/edge/${env.ROUTE_SECRET}`;
    const subscriptionPath = `/sub/${env.SUBSCRIPTION_TOKEN}`;

    if (request.method === "POST" && url.pathname === "/admin/preferred-ips") {
      try {
        loadAuth(env);
        return await updatePreferredEndpoints(request, env);
      } catch {
        return hiddenNotFound();
      }
    }

    if (request.method === "GET" && url.pathname === subscriptionPath) {
      try {
        loadAuth(env);
        return await subscriptionResponse(request, env);
      } catch {
        return hiddenNotFound();
      }
    }

    const profile =
      request.method === "GET"
        ? configurationProfile(url.pathname, env.CONFIG_TOKENS)
        : null;
    if (profile !== null) {
      try {
        loadAuth(env);
        const response = await configurationResponse(profile, env);
        return response ?? hiddenNotFound();
      } catch {
        return hiddenNotFound();
      }
    }

    if (!matchesTransportPath(url.pathname, transportPath)) {
      return hiddenNotFound();
    }

    try {
      const auth = loadAuth(env);
      if (request.headers.get("Upgrade")?.toLowerCase() === "websocket") {
        return handleWebSocket(request, env, auth);
      }
      if (request.method === "POST")
        return await handleXHttp(request, env, auth);
      return hiddenNotFound();
    } catch {
      return hiddenNotFound();
    }
  },
} satisfies ExportedHandler<Env>;
