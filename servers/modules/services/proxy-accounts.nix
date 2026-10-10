# ---
# Module: Managed Proxy Accounts
# Description: Defines the public lifecycle metadata for independently revocable proxy accounts.
# Scope: System
# ---
# Notes:
# - UUIDs and subscription tokens are kept in each host's SOPS file; never add them here.
# - Quotas are calendar-month lifecycle metadata; enforcement is added only with a verified controller.

{ lib, ... }:

let
  catalog = builtins.fromJSON (builtins.readFile ../../proxy-accounts.json);
in

{
  options.dot.proxyAccounts.accounts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this account may authenticate and receive a subscription.";
          };

          quotaGiB = lib.mkOption {
            type = lib.types.ints.positive;
            description = "Declared monthly aggregate traffic budget across every assigned node.";
          };

          expiresAt = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional UTC expiry timestamp in RFC 3339 form.";
          };
        };
      }
    );
    default = { };
    description = "Friends-only proxy accounts; the owner's legacy credentials remain outside this catalog.";
  };

  config = {
    assertions = [
      {
        assertion = catalog.version == 1;
        message = "servers/proxy-accounts.json has an unsupported schema version.";
      }
    ];
    dot.proxyAccounts.accounts = catalog.accounts;
  };
}
