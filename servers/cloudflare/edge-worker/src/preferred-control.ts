import {
  parsePreferredEndpointPool,
  preferredEndpointsResponse,
  updatePreferredEndpoints,
} from "./preferred-ips";
import type { Env } from "./types";

const SECRET_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

function notFound(): Response {
  return new Response("404 Not Found\n", {
    status: 404,
    headers: {
      "Cache-Control": "no-store",
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function isConfigured(env: Env): boolean {
  return (
    SECRET_PATTERN.test(env.PREFERRED_ENDPOINTS_TOKEN) &&
    env.IP_UPDATE_KEY.length >= 32
  );
}

/**
 * A deliberately tiny control-plane Worker.
 *
 * VLESS/XHTTP transport code lives in the main Worker; this endpoint carries
 * only the signed preferred-IP pools so CloudflareST maintenance remains
 * available even when transport code is being changed or debugged.
 */
export default {
  async fetch(request, env): Promise<Response> {
    if (!isConfigured(env)) return notFound();

    const url = new URL(request.url);
    const publicPrefix = `/preferred/${env.PREFERRED_ENDPOINTS_TOKEN}/`;
    const adminPrefix = "/admin/preferred-ips/";

    if (request.method === "GET" && url.pathname.startsWith(publicPrefix)) {
      const pool = parsePreferredEndpointPool(
        url.pathname.slice(publicPrefix.length),
      );
      return pool ? preferredEndpointsResponse(env, pool) : notFound();
    }

    if (request.method === "POST" && url.pathname.startsWith(adminPrefix)) {
      const pool = parsePreferredEndpointPool(
        url.pathname.slice(adminPrefix.length),
      );
      return pool ? updatePreferredEndpoints(request, env, pool) : notFound();
    }

    return notFound();
  },
} satisfies ExportedHandler<Env>;
