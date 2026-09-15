export function concatBytes(...parts: Uint8Array[]): Uint8Array {
  const length = parts.reduce((sum, part) => sum + part.byteLength, 0);
  const output = new Uint8Array(length);
  let offset = 0;

  for (const part of parts) {
    output.set(part, offset);
    offset += part.byteLength;
  }

  return output;
}

export function equalBytes(left: Uint8Array, right: Uint8Array): boolean {
  if (left.byteLength !== right.byteLength) return false;

  let difference = 0;
  for (let index = 0; index < left.byteLength; index += 1) {
    difference |= left[index]! ^ right[index]!;
  }
  return difference === 0;
}

export function toUint8Array(value: unknown): Promise<Uint8Array> {
  if (value instanceof ArrayBuffer) {
    return Promise.resolve(new Uint8Array(value));
  }
  if (ArrayBuffer.isView(value)) {
    return Promise.resolve(
      new Uint8Array(value.buffer, value.byteOffset, value.byteLength),
    );
  }
  if (typeof value === "string") {
    return Promise.resolve(new TextEncoder().encode(value));
  }
  if (value instanceof Blob) {
    return value.arrayBuffer().then((buffer) => new Uint8Array(buffer));
  }
  return Promise.reject(new Error("unsupported binary message"));
}

export function uuidToBytes(uuid: string): Uint8Array {
  const compact = uuid.toLowerCase().replaceAll("-", "");
  if (!/^[0-9a-f]{32}$/.test(compact)) {
    throw new Error("invalid VLESS UUID");
  }

  const output = new Uint8Array(16);
  for (let index = 0; index < output.byteLength; index += 1) {
    output[index] = Number.parseInt(
      compact.slice(index * 2, index * 2 + 2),
      16,
    );
  }
  return output;
}

export function utf8ToBase64(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (let offset = 0; offset < bytes.byteLength; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}
