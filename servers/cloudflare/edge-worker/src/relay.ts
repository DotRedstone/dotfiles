import { connect } from "cloudflare:sockets";
import { concatBytes, toUint8Array } from "./bytes";
import { relayLengthPrefixedDns, relayXudpDns } from "./dns";
import { immediateStreamResponse } from "./http-stream";
import { readProxyRequest } from "./protocol";
import type { Env, ProxyAuth, ProxyRequest } from "./types";

const DEFAULT_DOH_URL = "https://dns.google/dns-query";

function closeWebSocket(webSocket: WebSocket, code = 1000): void {
  try {
    if (
      webSocket.readyState === WebSocket.OPEN ||
      webSocket.readyState === WebSocket.CLOSING
    ) {
      webSocket.close(code, code === 1000 ? "" : "connection failed");
    }
  } catch {
    // The peer may already have closed the connection.
  }
}

function webSocketReadable(
  webSocket: WebSocket,
  earlyData: Uint8Array,
): ReadableStream<Uint8Array> {
  return new ReadableStream<Uint8Array>({
    start(controller) {
      let settled = false;
      let queue = Promise.resolve();
      if (earlyData.byteLength > 0) controller.enqueue(earlyData);

      webSocket.addEventListener("message", (event) => {
        queue = queue
          .then(() => toUint8Array(event.data))
          .then((chunk) => {
            if (!settled) controller.enqueue(chunk);
          })
          .catch((error: unknown) => {
            if (!settled) {
              settled = true;
              controller.error(error);
            }
          });
      });
      webSocket.addEventListener("close", () => {
        void queue.finally(() => {
          if (!settled) {
            settled = true;
            controller.close();
          }
        });
      });
      webSocket.addEventListener("error", () => {
        if (!settled) {
          settled = true;
          controller.error(new Error("websocket failed"));
        }
      });
    },
    cancel() {
      closeWebSocket(webSocket);
    },
  });
}

function decodeEarlyData(request: Request): Uint8Array {
  const header = request.headers.get("Sec-WebSocket-Protocol")?.trim();
  if (
    !header ||
    header.includes(",") ||
    !/^[A-Za-z0-9_-]+={0,2}$/.test(header)
  ) {
    return new Uint8Array();
  }
  try {
    const normalized = header.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const binary = atob(padded);
    if (binary.length > 8192) return new Uint8Array();
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    return new Uint8Array();
  }
}

async function openSocket(request: ProxyRequest): Promise<Socket> {
  if (request.port === 25) throw new Error("destination port is blocked");
  const socket = connect(
    { hostname: request.hostname, port: request.port },
    { allowHalfOpen: true },
  );
  await socket.opened;
  return socket;
}

async function pumpClientToSocket(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  socket: Socket,
  initialPayload: Uint8Array,
): Promise<void> {
  const writer = socket.writable.getWriter();
  try {
    if (initialPayload.byteLength > 0) await writer.write(initialPayload);
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value.byteLength > 0) await writer.write(value);
    }
    // XHTTP finishes its upload body before the destination necessarily sends
    // a response. Closing the writable side here can tear down the whole
    // Workers socket, so the response pump owns the final socket close.
  } finally {
    writer.releaseLock();
  }
}

async function pumpSocketToWebSocket(
  socket: Socket,
  webSocket: WebSocket,
  responseHeader: Uint8Array,
): Promise<void> {
  const reader = socket.readable.getReader();
  let headerPending = responseHeader.byteLength > 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const output = headerPending ? concatBytes(responseHeader, value) : value;
      headerPending = false;
      if (webSocket.readyState !== WebSocket.OPEN) break;
      webSocket.send(output);
    }
  } finally {
    reader.releaseLock();
  }
}

async function relayWebSocket(
  webSocket: WebSocket,
  request: Request,
  env: Env,
  auth: ProxyAuth,
): Promise<void> {
  const incoming = webSocketReadable(webSocket, decodeEarlyData(request));
  const reader = incoming.getReader();
  let socket: Socket | undefined;

  try {
    const proxyRequest = await readProxyRequest(reader, auth);
    if (proxyRequest.command === "mux") {
      await relayXudpDns(
        reader,
        proxyRequest.payload,
        env.DOH_URL ?? DEFAULT_DOH_URL,
        (chunk) => webSocket.send(chunk),
        proxyRequest.responseHeader,
      );
      return;
    }
    if (proxyRequest.command === "udp") {
      if (proxyRequest.protocol !== "vless" || proxyRequest.port !== 53) {
        throw new Error("only VLESS DNS UDP is supported");
      }
      await relayLengthPrefixedDns(
        reader,
        proxyRequest.payload,
        env.DOH_URL ?? DEFAULT_DOH_URL,
        (chunk) => webSocket.send(chunk),
        proxyRequest.responseHeader,
      );
      return;
    }

    socket = await openSocket(proxyRequest);
    await Promise.race([
      pumpClientToSocket(reader, socket, proxyRequest.payload),
      pumpSocketToWebSocket(socket, webSocket, proxyRequest.responseHeader),
    ]);
  } finally {
    reader.releaseLock();
    socket?.close();
    closeWebSocket(webSocket);
  }
}

export function handleWebSocket(
  request: Request,
  env: Env,
  auth: ProxyAuth,
): Response {
  const pair = new WebSocketPair();
  const client = pair[0];
  const server = pair[1];
  server.accept();

  void relayWebSocket(server, request, env, auth).catch(() => {
    closeWebSocket(server, 1011);
  });

  return new Response(null, { status: 101, webSocket: client });
}

async function pumpSocketToResponse(
  socket: Socket,
  responseHeader: Uint8Array,
  controller: ReadableStreamDefaultController<Uint8Array>,
): Promise<void> {
  const reader = socket.readable.getReader();
  try {
    if (responseHeader.byteLength > 0) controller.enqueue(responseHeader);
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      controller.enqueue(value);
    }
  } finally {
    reader.releaseLock();
  }
}

export function handleXHttp(
  request: Request,
  env: Env,
  auth: ProxyAuth,
): Response {
  if (!request.body) return new Response("Bad Request", { status: 400 });
  const reader = request.body.getReader();
  let socket: Socket | undefined;

  const headers = {
    "Cache-Control": "no-store",
    "Content-Type": "application/octet-stream",
    "X-Accel-Buffering": "no",
  };

  // XHTTP stream-one clients wait for the successful response headers before
  // streaming the VLESS request body. Return the response immediately and do
  // all handshake and relay work inside its body producer.
  return immediateStreamResponse(
    async (controller) => {
      try {
        const proxyRequest = await readProxyRequest(reader, auth);
        if (proxyRequest.command === "mux") {
          await relayXudpDns(
            reader,
            proxyRequest.payload,
            env.DOH_URL ?? DEFAULT_DOH_URL,
            (chunk) => controller.enqueue(chunk),
            proxyRequest.responseHeader,
          );
          return;
        }
        if (proxyRequest.command === "udp") {
          if (proxyRequest.protocol !== "vless" || proxyRequest.port !== 53) {
            throw new Error("only VLESS DNS UDP is supported");
          }
          await relayLengthPrefixedDns(
            reader,
            proxyRequest.payload,
            env.DOH_URL ?? DEFAULT_DOH_URL,
            (chunk) => controller.enqueue(chunk),
            proxyRequest.responseHeader,
          );
          return;
        }

        socket = await openSocket(proxyRequest);
        const connectedSocket = socket;
        void pumpClientToSocket(
          reader,
          connectedSocket,
          proxyRequest.payload,
        ).catch(() => connectedSocket.close());
        await pumpSocketToResponse(
          connectedSocket,
          proxyRequest.responseHeader,
          controller,
        );
      } finally {
        reader.releaseLock();
        socket?.close();
      }
    },
    headers,
    () => {
      void reader.cancel().catch(() => undefined);
      socket?.close();
    },
  );
}
