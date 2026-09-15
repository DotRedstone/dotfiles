import { describe, expect, it } from "vitest";
import { concatBytes, uuidToBytes } from "../src/bytes";
import { parseProxyRequest, parseTrojan, parseVless } from "../src/protocol";
import { sha224Hex } from "../src/sha224";

const uuid = "00112233-4455-6677-8899-aabbccddeeff";
const uuidBytes = uuidToBytes(uuid);
const password = "correct horse battery staple";
const trojanHash = new TextEncoder().encode(sha224Hex(password));

describe("SHA-224", () => {
  it("matches the published abc test vector", () => {
    expect(sha224Hex("abc")).toBe(
      "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
    );
  });
});

describe("VLESS parser", () => {
  it("parses a TCP domain request and preserves initial payload", () => {
    const hostname = new TextEncoder().encode("example.com");
    const packet = concatBytes(
      new Uint8Array([0]),
      uuidBytes,
      new Uint8Array([0, 1, 1, 187, 2, hostname.byteLength]),
      hostname,
      new TextEncoder().encode("hello"),
    );
    const result = parseVless(packet, uuidBytes);
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.request).toMatchObject({
      protocol: "vless",
      command: "tcp",
      hostname: "example.com",
      port: 443,
    });
    expect(new TextDecoder().decode(result.request.payload)).toBe("hello");
    expect(result.request.responseHeader).toEqual(new Uint8Array([0, 0]));
  });

  it("waits for a partial header", () => {
    expect(parseVless(new Uint8Array([0, 1, 2]), uuidBytes).kind).toBe(
      "need-more",
    );
  });

  it("parses an XUDP mux request without a destination address", () => {
    const payload = new Uint8Array([0, 4, 0, 0, 4, 0]);
    const packet = concatBytes(
      new Uint8Array([0]),
      uuidBytes,
      new Uint8Array([0, 3]),
      payload,
    );
    const result = parseVless(packet, uuidBytes);
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.request.command).toBe("mux");
    expect(result.request.payload).toEqual(payload);
  });
});

describe("Trojan parser", () => {
  it("parses a TCP IPv4 request", () => {
    const packet = concatBytes(
      trojanHash,
      new Uint8Array([13, 10, 1, 1, 1, 1, 1, 1, 0, 80, 13, 10]),
      new TextEncoder().encode("GET /"),
    );
    const result = parseTrojan(packet, trojanHash);
    expect(result.kind).toBe("ok");
    if (result.kind !== "ok") return;
    expect(result.request).toMatchObject({
      protocol: "trojan",
      command: "tcp",
      hostname: "1.1.1.1",
      port: 80,
    });
    expect(new TextDecoder().decode(result.request.payload)).toBe("GET /");
  });

  it("does not identify unauthenticated traffic", () => {
    const result = parseProxyRequest(new Uint8Array(128), {
      uuid: uuidBytes,
      trojanHash,
    });
    expect(result.kind).toBe("invalid");
  });
});
