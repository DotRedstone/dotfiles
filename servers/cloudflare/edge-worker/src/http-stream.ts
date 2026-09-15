export function immediateStreamResponse(
  run: (
    controller: ReadableStreamDefaultController<Uint8Array>,
  ) => Promise<void>,
  headers: HeadersInit,
  cancel?: () => void,
): Response {
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      void run(controller)
        .then(() => {
          if (!cancelled) controller.close();
        })
        .catch((error: unknown) => {
          if (!cancelled) controller.error(error);
        });
    },
    cancel() {
      cancelled = true;
      cancel?.();
    },
  });

  return new Response(body, { headers });
}
