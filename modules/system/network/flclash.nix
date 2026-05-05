# ---
# Module: Network - FlClash
# Description: Install FlClash GUI with NixOS wrapper-based core privileges on Linux
# Scope: System
# Notes:
# - FlClash upstream Linux flow uses sudo chown/chmod on FlClashCore for TUN privilege.
# - On NixOS, /nix/store is read-only, so we route core execution to /run/wrappers/bin instead.
# - Keep Clash Verge disabled to avoid mixed GUI state and migration confusion.
# ---

{ pkgs, ... }:
let
  flclashPatched = pkgs.flclash.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace lib/common/path.dart \
          --replace-fail "return join(executableDirPath, 'FlClashCore\$executableExtension');" "return '/run/wrappers/bin/FlClashCore';"
      '';
  });
in
{
  environment.systemPackages = [
    flclashPatched
    # FlClash Linux "set system proxy" relies on gsettings on many desktops.
    pkgs.glib
  ];

  # Use NixOS security wrapper to provide root+suid entrypoint for FlClashCore.
  # This avoids FlClash trying to mutate read-only /nix/store binaries via sudo.
  security.wrappers.FlClashCore = {
    owner = "root";
    group = "root";
    setuid = true;
    # FlClash Linux admin check requires stat output to contain "rws".
    # NixOS wrapper default perms ("u+rx,g+x,o+x") become "-r-s--s--x",
    # which fails that check and causes repeated sudo prompts.
    permissions = "u+rwx,g+rx,o+rx";
    source = "${flclashPatched.passthru.core}/bin/FlClashCore";
  };
}
