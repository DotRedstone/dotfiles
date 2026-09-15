import { concatBytes, equalBytes } from "./bytes";
import type { ParseResult, ProxyAuth, ProxyRequest } from "./types";

const decoder = new TextDecoder("utf-8", { fatal: true, ignoreBOM: false });

function parseAddress(
  data: Uint8Array,
  typeOffset: number,
  typeOverride?: number,
):
  | { kind: "need-more" }
  | { kind: "invalid" }
  | {
      kind: "ok";
      hostname: string;
      nextOffset: number;
    } {
  if (data.byteLength <= typeOffset) return { kind: "need-more" };
  const addressType = typeOverride ?? data[typeOffset]!;
  let cursor = typeOffset + 1;

  if (addressType === 1) {
    if (data.byteLength < cursor + 4) return { kind: "need-more" };
    const hostname = Array.from(data.subarray(cursor, cursor + 4)).join(".");
    return { kind: "ok", hostname, nextOffset: cursor + 4 };
  }

  if (addressType === 2 || addressType === 3) {
    // VLESS uses 2 for a domain and 3 for IPv6. Trojan/SOCKS uses 3 for a
    // domain and 4 for IPv6, so the caller normalizes Trojan's type first.
    if (addressType === 2) {
      if (data.byteLength <= cursor) return { kind: "need-more" };
      const length = data[cursor]!;
      cursor += 1;
      if (length === 0) return { kind: "invalid" };
      if (data.byteLength < cursor + length) return { kind: "need-more" };
      try {
        const hostname = decoder.decode(data.subarray(cursor, cursor + length));
        if (!hostname || hostname.includes("\0")) return { kind: "invalid" };
        return { kind: "ok", hostname, nextOffset: cursor + length };
      } catch {
        return { kind: "invalid" };
      }
    }

    if (data.byteLength < cursor + 16) return { kind: "need-more" };
    const groups: string[] = [];
    for (let index = 0; index < 16; index += 2) {
      groups.push(
        ((data[cursor + index]! << 8) | data[cursor + index + 1]!).toString(16),
      );
    }
    return { kind: "ok", hostname: groups.join(":"), nextOffset: cursor + 16 };
  }

  return { kind: "invalid" };
}

export function parseVless(data: Uint8Array, uuid: Uint8Array): ParseResult {
  if (data.byteLength < 18) return { kind: "need-more" };
  if (!equalBytes(data.subarray(1, 17), uuid)) return { kind: "invalid" };

  const version = data[0]!;
  if (version > 1) return { kind: "invalid" };
  const optionsLength = data[17]!;
  const commandOffset = 18 + optionsLength;
  if (data.byteLength <= commandOffset) return { kind: "need-more" };

  const commandByte = data[commandOffset]!;
  if (commandByte === 3) {
    return {
      kind: "ok",
      request: {
        protocol: "vless",
        command: "mux",
        hostname: "",
        port: 0,
        payload: data.subarray(commandOffset + 1),
        responseHeader: new Uint8Array([version, 0]),
      },
    };
  }
  if (commandByte !== 1 && commandByte !== 2) return { kind: "invalid" };
  const portOffset = commandOffset + 1;
  if (data.byteLength < portOffset + 3) return { kind: "need-more" };
  const port = (data[portOffset]! << 8) | data[portOffset + 1]!;
  if (port === 0) return { kind: "invalid" };

  const address = parseAddress(data, portOffset + 2);
  if (address.kind !== "ok") return address;

  const request: ProxyRequest = {
    protocol: "vless",
    command: commandByte === 1 ? "tcp" : "udp",
    hostname: address.hostname,
    port,
    payload: data.subarray(address.nextOffset),
    responseHeader: new Uint8Array([version, 0]),
  };
  return { kind: "ok", request };
}

export function parseTrojan(data: Uint8Array, hash: Uint8Array): ParseResult {
  if (data.byteLength < 58) return { kind: "need-more" };
  if (!equalBytes(data.subarray(0, 56), hash)) return { kind: "invalid" };
  if (data[56] !== 0x0d || data[57] !== 0x0a) return { kind: "invalid" };
  if (data.byteLength < 60) return { kind: "need-more" };

  const commandByte = data[58]!;
  if (commandByte !== 1 && commandByte !== 3) return { kind: "invalid" };
  const trojanAddressType = data[59]!;
  const normalizedType =
    trojanAddressType === 3
      ? 2
      : trojanAddressType === 4
        ? 3
        : trojanAddressType;
  if (normalizedType !== 1 && normalizedType !== 2 && normalizedType !== 3) {
    return { kind: "invalid" };
  }

  const address = parseAddress(data, 59, normalizedType);
  if (address.kind !== "ok") return address;
  if (data.byteLength < address.nextOffset + 4) return { kind: "need-more" };

  const port = (data[address.nextOffset]! << 8) | data[address.nextOffset + 1]!;
  if (port === 0) return { kind: "invalid" };
  if (
    data[address.nextOffset + 2] !== 0x0d ||
    data[address.nextOffset + 3] !== 0x0a
  ) {
    return { kind: "invalid" };
  }

  return {
    kind: "ok",
    request: {
      protocol: "trojan",
      command: commandByte === 1 ? "tcp" : "udp",
      hostname: address.hostname,
      port,
      payload: data.subarray(address.nextOffset + 4),
      responseHeader: new Uint8Array(),
    },
  };
}

export function parseProxyRequest(
  data: Uint8Array,
  auth: ProxyAuth,
): ParseResult {
  const vless = parseVless(data, auth.uuid);
  if (vless.kind === "ok") return vless;
  const trojan = parseTrojan(data, auth.trojanHash);
  if (trojan.kind === "ok") return trojan;
  if (vless.kind === "need-more" || trojan.kind === "need-more") {
    return { kind: "need-more" };
  }
  return { kind: "invalid" };
}

export async function readProxyRequest(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  auth: ProxyAuth,
): Promise<ProxyRequest> {
  let buffered: Uint8Array<ArrayBufferLike> = new Uint8Array();
  const maximumHandshakeBytes = 64 * 1024;

  while (true) {
    const parsed = parseProxyRequest(buffered, auth);
    if (parsed.kind === "ok") return parsed.request;
    if (parsed.kind === "invalid") throw new Error("invalid proxy request");
    if (buffered.byteLength > maximumHandshakeBytes) {
      throw new Error("proxy request header is too large");
    }

    const { done, value } = await reader.read();
    if (done) throw new Error("incomplete proxy request");
    if (value.byteLength > 0) buffered = concatBytes(buffered, value);
  }
}
