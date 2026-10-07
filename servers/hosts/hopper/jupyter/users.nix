# ---
# Module: Hopper Jupyter Users & Virtualenvs
# Description: Accounts, secrets, and isolated project virtualenvs for Jupyter users
# Scope: Host
# ---

{ config, lib, pkgs, jupyterPaths, ... }: {
  sops.secrets."jupyter/users/jupyter-dot_password_hash" = {
    neededForUsers = true;
  };

  sops.secrets."jupyter/users/fogelamp_password_hash" = {
    neededForUsers = true;
  };

  users.groups.jupyter-users = { };

  users.users.jupyter-dot = {
    isNormalUser = true;
    description = "Personal JupyterHub account";
    group = "jupyter-users";
    createHome = true;
    home = "/home/jupyter-dot";
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets."jupyter/users/jupyter-dot_password_hash".path;
  };

  users.users.jupyter-fogelamp = {
    isNormalUser = true;
    description = "Fogelamp JupyterHub account";
    group = "jupyter-users";
    createHome = true;
    home = "/home/jupyter-fogelamp";
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets."jupyter/users/fogelamp_password_hash".path;
  };

  # The Nix kernel is intentionally immutable. Give each Hub user a separate
  # project virtualenv that inherits the reviewed baseline packages while
  # keeping later `pip install` work in that user's home directory.
  system.activationScripts.jupyter-project-venvs = lib.stringAfter [ "users" ] ''
    for account in jupyter-dot jupyter-fogelamp; do
      home_dir="$(getent passwd "$account" | cut -d: -f6)"
      venv_dir="$home_dir/.venvs/python-project"

      if [ ! -x "$venv_dir/bin/python" ] || [ ! -x "$venv_dir/bin/pip" ]; then
        ${pkgs.util-linux}/bin/runuser -u "$account" -- \
          env HOME="$home_dir" \
          ${config.services.jupyterhub.jupyterlabEnv}/bin/python3 \
          -m venv --system-site-packages "$venv_dir"
      fi

      # Remove EXTERNALLY-MANAGED marker so pip installs proceed without resistance
      rm -f "$venv_dir/EXTERNALLY-MANAGED" "$venv_dir/lib/"*"/EXTERNALLY-MANAGED" 2>/dev/null || true

      # Register default 'python3' and custom 'python-project' kernel specs to point to user venv
      ${pkgs.util-linux}/bin/runuser -u "$account" -- \
        env HOME="$home_dir" \
        "$venv_dir/bin/python" -m ipykernel install --user \
        --name python3 \
        --display-name "Python 3" >/dev/null

      ${pkgs.util-linux}/bin/runuser -u "$account" -- \
        env HOME="$home_dir" \
        "$venv_dir/bin/python" -m ipykernel install --user \
        --name python-project \
        --display-name "Python (项目扩展)" >/dev/null

      # Ensure login shells (bash -l in Jupyter terminal) load tools and auto-activate venv
      profile="$home_dir/.profile"
      bashrc="$home_dir/.bashrc"

      cat > "$profile" <<'EOF'
# [Jupyter User Login Profile]
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
      chown "$account:jupyter-users" "$profile"
      chmod 644 "$profile"

      cat > "$bashrc" <<EOF
# [Jupyter User Interactive Shell]
export PATH="\$HOME/.venvs/python-project/bin:\$HOME/.local/bin:${jupyterPaths.jupyterToolPath}:${jupyterPaths.jupyterPdfExportPath}:\$PATH"

if [ -f "\$HOME/.venvs/python-project/bin/activate" ]; then
  source "\$HOME/.venvs/python-project/bin/activate"
fi
EOF
      chown "$account:jupyter-users" "$bashrc"
      chmod 644 "$bashrc"
    done
  '';
}
