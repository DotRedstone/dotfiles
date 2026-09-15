# ---
# Module: Server Xray Subscriptions
# Description: Static Nginx subscription responses rendered from SOPS secrets
# Scope: System
# Notes:
# - Route paths and response bodies are runtime templates and never enter the Nix store.
# - Nginx cannot start until every decoded subscription uses the host's declared public address.
# ---

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dot.services.xraySubscriptions;
  placeholder = name: config.sops.placeholder."xray/${name}";
  secretNames = lib.concatMap (name: [
    "subscription_${name}_path"
    "subscription_${name}_content"
  ]) cfg.entryNames;

  subscriptionCheck = pkgs.writeText "check-xray-subscriptions.py" ''
    import base64
    import pathlib
    import sys
    import urllib.parse

    expected_address = sys.argv[1]
    arguments = sys.argv[2:]
    if len(arguments) % 2 != 0:
        raise SystemExit("subscription check received incomplete arguments")

    checked = 0
    for name, secret_path in zip(arguments[0::2], arguments[1::2]):
        encoded = pathlib.Path(secret_path).read_text(encoding="utf-8").strip()
        try:
            decoded = base64.b64decode(encoded, validate=True).decode("utf-8")
        except (ValueError, UnicodeDecodeError) as error:
            raise SystemExit(f"{name}: invalid base64 subscription: {error}") from error

        uris = [line.strip() for line in decoded.splitlines() if line.strip()]
        if not uris:
            raise SystemExit(f"{name}: subscription contains no endpoints")

        for uri in uris:
            endpoint = urllib.parse.urlsplit(uri)
            if endpoint.scheme != "vless":
                raise SystemExit(f"{name}: unsupported subscription scheme")
            if endpoint.hostname != expected_address:
                raise SystemExit(f"{name}: subscription address does not match the host profile")
            checked += 1

    print(f"validated {checked} Xray subscription endpoints")
  '';

  subscriptionCheckArguments = lib.concatMapStringsSep " " (
    name:
    "${lib.escapeShellArg name} ${
      lib.escapeShellArg config.sops.secrets."xray/subscription_${name}_content".path
    }"
  ) cfg.entryNames;
in
{
  options.dot.services.xraySubscriptions = {
    enable = lib.mkEnableOption "the static Xray subscription endpoint";

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "HTTP virtual host used by existing subscription clients.";
      example = "node.example.com";
    };

    publicAddress = lib.mkOption {
      type = lib.types.str;
      description = "Public IP address encoded into every rendered subscription endpoint.";
      example = "203.0.113.10";
    };

    entryNames = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_-]+");
      default = [
        "websocket"
        "reality"
      ];
      description = "Stable identifiers used to map subscription paths and bodies from SOPS.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.entryNames != [ ] && lib.length cfg.entryNames == lib.length (lib.unique cfg.entryNames);
        message = "dot.services.xraySubscriptions.entryNames must be non-empty and unique.";
      }
    ];

    sops.secrets = lib.genAttrs (map (name: "xray/${name}") secretNames) (_: {
      restartUnits = [
        "xray-subscriptions-check.service"
        "nginx.service"
      ];
    });

    sops.templates =
      lib.listToAttrs (
        map (name: {
          name = "xray-subscription-${name}.txt";
          value = {
            owner = "nginx";
            group = "nginx";
            mode = "0400";
            content = placeholder "subscription_${name}_content";
          };
        }) cfg.entryNames
      )
      // {
        "xray-subscriptions.conf" = {
          owner = "root";
          group = "nginx";
          mode = "0440";
          content = lib.concatMapStringsSep "\n" (name: ''
            location = ${placeholder "subscription_${name}_path"} {
              alias ${config.sops.templates."xray-subscription-${name}.txt".path};
              default_type text/plain;
              add_header Cache-Control "no-store";
            }
          '') cfg.entryNames;
        };
      };

    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts.${cfg.hostName} = {
        default = true;
        locations."/".return = "404";
        extraConfig = ''
          include ${config.sops.templates."xray-subscriptions.conf".path};
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 ];

    systemd.services.xray-subscriptions-check = {
      description = "Validate Xray subscription endpoints against the host profile";
      before = [ "nginx.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${subscriptionCheck} ${lib.escapeShellArg cfg.publicAddress} ${subscriptionCheckArguments}";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };

    systemd.services.nginx = {
      after = [ "xray-subscriptions-check.service" ];
      requires = [ "xray-subscriptions-check.service" ];
    };
  };
}
