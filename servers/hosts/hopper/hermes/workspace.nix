# ---
# Module: Hopper Hermes Workspace
# Description: Permissions and isolated workspace Python virtualenv for Hermes
# Scope: Host
# ---

{ lib, pkgs, ... }: {
  # `dot` already administers Hopper through passwordless sudo. Membership lets
  # the operator use the shared Hermes CLI and inspect its task output locally.
  users.users.dot.extraGroups = [ "hermes" ];

  # Keep experimental Python dependencies writable but isolated from the
  # Nix-managed service environment. This stays in Hermes's own workspace,
  # is created once, and survives service restarts and ordinary rebuilds.
  system.activationScripts.hermes-workspace-venv = lib.stringAfter [ "users" ] ''
    venv_dir=/var/lib/hermes/workspace/.venv
    if [ ! -x "$venv_dir/bin/python" ]; then
      ${pkgs.coreutils}/bin/mkdir -p /var/lib/hermes/workspace
      ${pkgs.coreutils}/bin/chown hermes:hermes /var/lib/hermes/workspace
      ${pkgs.util-linux}/bin/runuser -u hermes -- \
        env HOME=/var/lib/hermes \
        ${pkgs.python3}/bin/python3 -m venv --system-site-packages "$venv_dir"
    fi
  '';
}
