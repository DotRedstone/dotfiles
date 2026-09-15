export function matchesTransportPath(
  pathname: string,
  transportPath: string,
): boolean {
  return pathname === transportPath || pathname === `${transportPath}/`;
}
