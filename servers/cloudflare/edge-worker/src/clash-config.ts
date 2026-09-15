import type { Env } from "./types";

const PROFILE_PATTERN = /^(router|desktop|mobile|root)$/;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

export function configurationProfile(
  pathname: string,
  serializedTokens: string,
): string | null {
  let tokens: Record<string, unknown>;
  try {
    tokens = JSON.parse(serializedTokens) as Record<string, unknown>;
  } catch {
    return null;
  }

  for (const profile of ["router", "desktop", "mobile", "root"]) {
    const token = tokens[profile];
    if (
      typeof token === "string" &&
      TOKEN_PATTERN.test(token) &&
      pathname === `/clash/${token}/${profile}`
    ) {
      return profile;
    }
  }
  return null;
}

export async function configurationResponse(
  profile: string,
  env: Env,
): Promise<Response | null> {
  if (!PROFILE_PATTERN.test(profile)) return null;
  const configuration = await env.EDGE_STATE.get(`clash/config/${profile}`);
  if (configuration === null) return null;
  return new Response(configuration, {
    headers: {
      "Cache-Control": "private, no-store",
      "Content-Disposition": `attachment; filename="mihomo-${profile}.yaml"`,
      "Content-Type": "application/x-yaml; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
