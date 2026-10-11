# Proxy deployment data

This directory holds deployment-owned, non-secret inputs for the separate `proxy-stack` Flake.
It does not replace `servers/proxy-accounts.json`, `servers/clash/router-policy.json`, or current
subscriptions until the new endpoints pass isolated tests and a reviewed rollout.

- `accounts.json` starts empty on purpose. The current managed friend account stays in the
  legacy catalog. Give each migrated account a verified `primaryOrigin`, two approved source
  IDs, four node exits, lifecycle metadata, and separate SOPS credentials before enabling it.
- `nodes.json` records the two existing public node endpoints and CF names. REALITY client
  metadata and WebSocket paths are private runtime inputs, not fields in this file.
- `preferred-sources.json` registers the current router's two origin-specific CFST sources.
  GitHub sources require explicit owner/ref/path review and origin health validation.
- `owned-domains.json` lists only the user's registered suffixes and node IPs for direct rules.
- `profiles/` separates router network behavior from desktop and mobile defaults. The router
  profile preserves the old local TUN, DNS, ports, and controller settings for testing; it has
  not been installed on the router.

Run the locked compiler's `validate` command against this directory. Generated private YAML,
tokens, UUIDs, path secrets, and pool snapshots must remain outside Git and Nix store.
