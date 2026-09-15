import { describe, expect, it } from "vitest";
import { immediateStreamResponse } from "../src/http-stream";

describe("immediate streaming response", () => {
  it("returns headers before the producer receives request data", async () => {
    let releaseProducer: (() => void) | undefined;
    const producerReady = new Promise<void>((resolve) => {
      releaseProducer = resolve;
    });

    const response = immediateStreamResponse(
      async (controller) => {
        await producerReady;
        controller.enqueue(new TextEncoder().encode("ready"));
      },
      { "Content-Type": "application/octet-stream" },
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe(
      "application/octet-stream",
    );
    releaseProducer?.();
    await expect(response.text()).resolves.toBe("ready");
  });
});
