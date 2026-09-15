import { concatBytes } from "./bytes";

const MAXIMUM_DNS_PACKET_BYTES = 4096;
const MAXIMUM_XUDP_FRAME_BYTES = 64 * 1024;

async function resolveDns(
  packet: Uint8Array,
  dohUrl: string,
): Promise<Uint8Array> {
  const response = await fetch(dohUrl, {
    method: "POST",
    headers: {
      Accept: "application/dns-message",
      "Content-Type": "application/dns-message",
    },
    body: packet,
  });
  if (!response.ok) throw new Error("DNS upstream rejected the request");

  const answer = new Uint8Array(await response.arrayBuffer());
  if (answer.byteLength > 0xffff) throw new Error("DNS answer is too large");
  return answer;
}

export async function relayLengthPrefixedDns(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  initialPayload: Uint8Array,
  dohUrl: string,
  send: (chunk: Uint8Array) => void,
  responseHeader: Uint8Array,
): Promise<void> {
  let buffered = initialPayload;
  let headerPending = responseHeader.byteLength > 0;

  while (true) {
    while (buffered.byteLength >= 2) {
      const packetLength = (buffered[0]! << 8) | buffered[1]!;
      if (packetLength === 0 || packetLength > MAXIMUM_DNS_PACKET_BYTES) {
        throw new Error("invalid DNS packet length");
      }
      if (buffered.byteLength < packetLength + 2) break;

      const packet = buffered.slice(2, packetLength + 2);
      buffered = buffered.slice(packetLength + 2);
      const answer = await resolveDns(packet, dohUrl);
      const length = new Uint8Array([
        answer.byteLength >>> 8,
        answer.byteLength & 0xff,
      ]);
      send(
        concatBytes(
          headerPending ? responseHeader : new Uint8Array(),
          length,
          answer,
        ),
      );
      headerPending = false;
    }

    const { done, value } = await reader.read();
    if (done) break;
    if (value.byteLength > 0) buffered = concatBytes(buffered, value);
    if (buffered.byteLength > MAXIMUM_DNS_PACKET_BYTES + 2) {
      throw new Error("DNS buffer is too large");
    }
  }

  if (buffered.byteLength !== 0) throw new Error("incomplete DNS packet");
}

function parseMuxAddress(
  data: Uint8Array,
  offset: number,
  limit: number,
): { port: number; raw: Uint8Array } {
  if (offset + 3 > limit) throw new Error("incomplete XUDP address");
  const port = (data[offset]! << 8) | data[offset + 1]!;
  const type = data[offset + 2]!;
  let end: number;

  if (type === 1) {
    end = offset + 7;
  } else if (type === 3) {
    end = offset + 19;
  } else if (type === 2) {
    if (offset + 4 > limit) throw new Error("incomplete XUDP domain");
    const length = data[offset + 3]!;
    if (length === 0) throw new Error("empty XUDP domain");
    end = offset + 4 + length;
  } else {
    throw new Error("unsupported XUDP address type");
  }

  if (end > limit) throw new Error("incomplete XUDP address");
  return { port, raw: data.slice(offset, end) };
}

function xudpDnsResponse(
  sessionId: number,
  address: Uint8Array,
  answer: Uint8Array,
): Uint8Array {
  const frameLength = 5 + address.byteLength;
  const output = new Uint8Array(2 + frameLength + 2 + answer.byteLength);
  let offset = 0;
  output[offset++] = frameLength >>> 8;
  output[offset++] = frameLength & 0xff;
  output[offset++] = sessionId >>> 8;
  output[offset++] = sessionId & 0xff;
  output[offset++] = 2; // keep
  output[offset++] = 1; // data
  output[offset++] = 2; // UDP
  output.set(address, offset);
  offset += address.byteLength;
  output[offset++] = answer.byteLength >>> 8;
  output[offset++] = answer.byteLength & 0xff;
  output.set(answer, offset);
  return output;
}

export async function relayXudpDns(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  initialPayload: Uint8Array,
  dohUrl: string,
  send: (chunk: Uint8Array) => void,
  responseHeader: Uint8Array,
): Promise<void> {
  let buffered = initialPayload;
  let headerPending = responseHeader.byteLength > 0;

  while (true) {
    while (buffered.byteLength >= 2) {
      const frameLength = (buffered[0]! << 8) | buffered[1]!;
      if (frameLength < 4 || frameLength > MAXIMUM_XUDP_FRAME_BYTES) {
        throw new Error("invalid XUDP frame length");
      }
      const headerEnd = 2 + frameLength;
      if (buffered.byteLength < headerEnd) break;

      const sessionId = (buffered[2]! << 8) | buffered[3]!;
      const status = buffered[4]!;
      const option = buffered[5]!;
      if (status !== 1 && status !== 2) {
        throw new Error("unsupported XUDP session status");
      }
      if ((option & 1) === 0) {
        buffered = buffered.slice(headerEnd);
        continue;
      }
      if (frameLength <= 5 || buffered[6] !== 2) {
        throw new Error("only XUDP DNS is supported");
      }

      const address = parseMuxAddress(buffered, 7, headerEnd);
      if (address.port !== 53) throw new Error("only XUDP DNS is supported");
      if (buffered.byteLength < headerEnd + 2) break;
      const packetLength =
        (buffered[headerEnd]! << 8) | buffered[headerEnd + 1]!;
      if (packetLength === 0 || packetLength > MAXIMUM_DNS_PACKET_BYTES) {
        throw new Error("invalid XUDP DNS packet length");
      }
      const frameEnd = headerEnd + 2 + packetLength;
      if (buffered.byteLength < frameEnd) break;

      const packet = buffered.slice(headerEnd + 2, frameEnd);
      buffered = buffered.slice(frameEnd);
      const answer = await resolveDns(packet, dohUrl);
      const response = xudpDnsResponse(sessionId, address.raw, answer);
      send(headerPending ? concatBytes(responseHeader, response) : response);
      headerPending = false;
    }

    const { done, value } = await reader.read();
    if (done) break;
    if (value.byteLength > 0) buffered = concatBytes(buffered, value);
    if (buffered.byteLength > MAXIMUM_XUDP_FRAME_BYTES + 4) {
      throw new Error("XUDP buffer is too large");
    }
  }

  if (buffered.byteLength !== 0) throw new Error("incomplete XUDP frame");
}
