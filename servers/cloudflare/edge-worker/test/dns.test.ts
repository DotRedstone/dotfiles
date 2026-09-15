import { afterEach, describe, expect, it, vi } from "vitest";
import { concatBytes } from "../src/bytes";
import { relayLengthPrefixedDns, relayXudpDns } from "../src/dns";

afterEach(() => vi.unstubAllGlobals());

describe("DNS UDP relay", () => {
  it("posts one DNS message and restores VLESS and packet framing", async () => {
    const query = new Uint8Array([0xc0, 0xde, 0x01, 0x00]);
    const answer = new Uint8Array([0xc0, 0xde, 0x81, 0x80]);
    const fetchMock = vi.fn(async () => new Response(answer, { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    const reader = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.close();
      },
    }).getReader();
    const output: Uint8Array[] = [];

    await relayLengthPrefixedDns(
      reader,
      concatBytes(new Uint8Array([0, query.byteLength]), query),
      "https://dns.example/dns-query",
      (chunk) => output.push(chunk),
      new Uint8Array([0, 0]),
    );

    expect(fetchMock).toHaveBeenCalledOnce();
    expect(output).toEqual([
      concatBytes(new Uint8Array([0, 0, 0, answer.byteLength]), answer),
    ]);
  });

  it("translates Mihomo XUDP DNS frames without enabling arbitrary UDP", async () => {
    const query = new Uint8Array([0xc0, 0xde, 0x01, 0x00]);
    const answer = new Uint8Array([0xc0, 0xde, 0x81, 0x80]);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(answer, { status: 200 })),
    );

    const address = new Uint8Array([0, 53, 1, 1, 1, 1, 1]);
    const globalId = new Uint8Array(8);
    const frameLength = 5 + address.byteLength + globalId.byteLength;
    const request = concatBytes(
      new Uint8Array([frameLength >>> 8, frameLength & 0xff, 0, 7, 1, 1, 2]),
      address,
      globalId,
      new Uint8Array([0, query.byteLength]),
      query,
    );
    const reader = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.close();
      },
    }).getReader();
    const output: Uint8Array[] = [];

    await relayXudpDns(
      reader,
      request,
      "https://dns.example/dns-query",
      (chunk) => output.push(chunk),
      new Uint8Array([0, 0]),
    );

    const responseFrameLength = 5 + address.byteLength;
    expect(output).toEqual([
      concatBytes(
        new Uint8Array([
          0,
          0,
          responseFrameLength >>> 8,
          responseFrameLength & 0xff,
          0,
          7,
          2,
          1,
          2,
        ]),
        address,
        new Uint8Array([0, answer.byteLength]),
        answer,
      ),
    ]);
  });
});
