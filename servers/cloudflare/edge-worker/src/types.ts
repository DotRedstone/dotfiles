export interface Env {
  EDGE_STATE: KVNamespace;
  PUBLIC_HOST: string;
  SITE_NAME?: string;
  DOH_URL?: string;
  VLESS_UUID: string;
  TROJAN_PASSWORD: string;
  ROUTE_SECRET: string;
  SUBSCRIPTION_TOKEN: string;
  CONFIG_TOKENS: string;
  IP_UPDATE_KEY: string;
}

export type ProxyProtocol = "vless" | "trojan";
export type ProxyCommand = "tcp" | "udp" | "mux";

export interface ProxyRequest {
  protocol: ProxyProtocol;
  command: ProxyCommand;
  hostname: string;
  port: number;
  payload: Uint8Array;
  responseHeader: Uint8Array;
}

export type ParseResult =
  | { kind: "need-more" }
  | { kind: "invalid" }
  | { kind: "ok"; request: ProxyRequest };

export interface ProxyAuth {
  uuid: Uint8Array;
  trojanHash: Uint8Array;
}

export interface PreferredEndpoint {
  address: string;
  port: number;
  label: string;
}

export interface PreferredEndpointState {
  version: 1;
  updatedAt: string;
  endpoints: PreferredEndpoint[];
}
