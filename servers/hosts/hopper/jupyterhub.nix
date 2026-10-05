# ---
# Module: Hopper Personal JupyterHub
# Description: Private JupyterLab workspace with one low-privilege local account
# Scope: Host
# Notes:
# - JupyterHub only listens on loopback; Nginx is the sole public-facing path.
# - Add future people as separate Unix users and SOPS password hashes, never as sudo users.
# ---

{ config, lib, pkgs, ... }:
let
  pythonPackages = pkgs.python3Packages;
  # nbconvert invokes these executables from each per-user Jupyter server.
  # The spawner environment must contain them explicitly; system packages are
  # not guaranteed to be inherited by SystemdSpawner units.
  jupyterPdfExportPath = lib.makeBinPath [
    pkgs.pandoc
    pkgs.texliveFull
  ];
  # These are terminal tools inside each single-user Jupyter server.  Python
  # itself is supplied by jupyterlabEnv below so imported packages and the
  # notebook kernel always use the same interpreter.
  jupyterToolPath = lib.makeBinPath [
    pkgs.gcc
    pkgs.gnumake
    pkgs.pkg-config
    pkgs.binutils
    pkgs.nodejs
    pkgs.jdk
    pkgs.git
    pkgs.zip
    pkgs.unzip
    pkgs.tree
    pkgs.file
  ];
  jupyterNbconvertConfig = ''
    c.TemplateExporter.extra_template_basedirs = ["/etc/jupyter/nbconvert/templates"]
    c.PDFExporter.template_name = "ctex"
    c.PDFExporter.latex_command = ["xelatex", "{filename}", "-quiet"]
  '';

  jupyterlabChinese = pythonPackages.buildPythonPackage {
    pname = "jupyterlab-language-pack-zh-CN";
    version = "4.5.post3";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "jupyterlab_language_pack_zh_cn";
      version = "4.5.post3";
      format = "wheel";
      hash = "sha256-R82wxBxrBm55XIZ3hsnCn95SfivxWqaz6bK6uZKTBLU=";
    };

    doCheck = false;
  };

  jupyterlabCatppuccin = pythonPackages.buildPythonPackage {
    pname = "catppuccin-jupyterlab";
    version = "0.2.5";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "catppuccin_jupyterlab";
      version = "0.2.5";
      format = "wheel";
      python = "py3";
      dist = "py3";
      hash = "sha256-d5uxZIf3AJ7AX9GEfWdb/+KMTi7xA3Df+SkZgVD6C6Y=";
    };

    doCheck = false;
  };

  # The upstream extension is a JupyterLab 4 prebuilt extension.  Keep its
  # small, maintained top-bar switch, but point it at the two Catppuccin
  # variants already shipped by our theme package instead of JupyterLab's
  # stock themes.
  jupyterlabThemeToggler = pythonPackages.buildPythonPackage {
    pname = "jupyterlab-theme-toggler";
    version = "1.0.0";
    format = "wheel";

    src = pkgs.fetchPypi {
      pname = "jupyterlab_theme_toggler";
      version = "1.0.0";
      format = "wheel";
      python = "py3";
      dist = "py3";
      hash = "sha256-yzcgNQodJL1xD7jyxEKJ8EP52oV3PcQUee7oINRfkoI=";
    };

    postInstall = ''
      substituteInPlace "$out/share/jupyter/labextensions/jupyterlab-theme-toggler/static/789.c7eee2235cc74ef156cd.js" \
        --replace-fail "JupyterLab Light" "Catppuccin Latte" \
        --replace-fail "JupyterLab Dark" "Catppuccin Mocha"
    '';

    propagatedBuildInputs = [ pythonPackages.jupyterlab ];

    doCheck = false;
  };
in {
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

  # The Nix kernel is intentionally immutable.  Give each Hub user a separate
  # project virtualenv that inherits the reviewed baseline packages while
  # keeping later `pip install` work in that user's home directory.  The
  # activation is idempotent: it creates an environment only when absent and
  # never overwrites a user's installed project dependencies.
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

      # Register default 'python3' and custom 'python-project' kernel specs to point to the user venv
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
export PATH="\$HOME/.venvs/python-project/bin:\$HOME/.local/bin:${jupyterToolPath}:${jupyterPdfExportPath}:\$PATH"

if [ -f "\$HOME/.venvs/python-project/bin/activate" ]; then
  source "\$HOME/.venvs/python-project/bin/activate"
fi
EOF
      chown "$account:jupyter-users" "$bashrc"
      chmod 644 "$bashrc"
    done
  '';

  environment.etc."jupyter/labconfig/default_setting_overrides.json".text = builtins.toJSON {
    "@jupyterlab/translation-extension:plugin".locale = "zh_CN";

    "@jupyterlab/terminal-extension:plugin" = {
      fontFamily = "'Maple Mono NF', 'Maple Mono', 'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Sarasa Mono SC', Consolas, monospace";
      fontSize = 14;
      lineHeight = 1.2;
    };

    "@jupyterlab/apputils-extension:themes" = {
      theme = "Catppuccin Mocha";
      "adaptive-theme" = false;
      "theme-scrollbars" = true;
      overrides = {
        "code-font-family" = "'Maple Mono NF', 'Maple Mono', 'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Sarasa Mono SC', Consolas, monospace";
        "code-font-size" = "14px";
        "content-font-family" = "Inter, Noto Sans SC, system-ui, sans-serif";
        "content-font-size1" = "14px";
        "ui-font-family" = "Inter, Noto Sans SC, system-ui, sans-serif";
        "ui-font-size1" = "13px";
      };
    };

    "catppuccin_jupyterlab:plugin" = {
      brandColor = "mauve";
      accentColor = "green";
    };
  };

  # Keep the canonical JupyterLab “Export Notebook As → PDF” route available
  # for every Hub user.  XeLaTeX handles Unicode/Chinese notebooks more
  # reliably than the default pdfLaTex engine.
  environment.etc."jupyter/jupyter_nbconvert_config.py".text = jupyterNbconvertConfig;

  # The CLI loads jupyter_nbconvert_config.py, but the in-browser export
  # endpoint receives the running Jupyter Server configuration instead.
  environment.etc."jupyter/jupyter_server_config.py".text = jupyterNbconvertConfig;

  # `article` does not configure CJK fonts even when XeLaTeX is selected.
  # Keep nbconvert's maintained LaTex template and override only its document
  # class, so Chinese Markdown, code comments, and headings render correctly.
  environment.etc."jupyter/nbconvert/templates/ctex/conf.json".text = builtins.toJSON {
    base_template = "latex";
  };
  environment.etc."jupyter/nbconvert/templates/ctex/index.tex.j2".text = ''
    ((*- extends 'latex/index.tex.j2' -*))

    ((*- block docclass -*))
    \documentclass[UTF8,11pt]{ctexart}
    ((*- endblock docclass -*))

    ((*- block packages -*))
    ((( super() )))
    % CTeX's bundled Fandol Chinese font is reliable with XeLaTeX in NixOS.
    % Map common notebook symbols explicitly: otherwise Latin Modern silently
    % drops them even though all Chinese glyphs are present.
    \usepackage{newunicodechar}
    \newunicodechar{≈}{\ensuremath{\approx}}
    \newunicodechar{□}{\ensuremath{\square}}
    \setcounter{secnumdepth}{-1}
    ((*- endblock packages -*))

    ((*- block margins -*))
    % Chinese coursework is normally printed on A4, not nbconvert's Letter
    % default.  These margins leave a conventional, readable text block.
    \geometry{a4paper,top=2.2cm,bottom=2.2cm,left=2.35cm,right=2.35cm}
    ((*- endblock margins -*))

    % Notebook file names such as "Untitled (2)" are not document titles.
    ((*- block maketitle -*))
    ((*- endblock maketitle -*))
  '';

  fonts.packages = [
    pkgs.noto-fonts-cjk-sans
    pkgs.noto-fonts-cjk-serif
  ];

  services.jupyterhub = {
    enable = true;
    host = "127.0.0.1";
    # 8001 is ConfigurableHTTPProxy's internal API port; keep its public
    # listener on the conventional adjacent loopback port instead.
    port = 8000;
    jupyterlabEnv = pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
      # Kernel and package-management baseline.  Add durable dependencies here
      # instead of installing into Nix's read-only interpreter at runtime.
      ipykernel
      pip
      setuptools
      wheel
      jupyterhub
      jupyterlab
      nbconvert
      jupyterlabChinese
      jupyterlabCatppuccin
      jupyterlabThemeToggler
      # General data analysis and visualization.
      numpy
      scipy
      pandas
      matplotlib
      scikit-learn
      sympy
      seaborn
      plotly
      # CSV/XLSX, Word, PowerPoint and PDF coursework/document tooling.
      openpyxl
      python-docx
      python-pptx
      pypdf
      pdfplumber
      reportlab
      # Web/data exchange and common service clients.
      requests
      beautifulsoup4
      lxml
      sqlalchemy
      pymongo
      redis
      pyyaml
      tqdm
      tabulate
    ]);
    extraConfig = ''
      c.Authenticator.allowed_users = {"jupyter-dot", "jupyter-fogelamp"}
      c.JupyterHub.admin_users = {"jupyter-dot"}
      c.SystemdSpawner.cpu_limit = 2.0
      c.SystemdSpawner.mem_limit = '4G'

      # Inject user venv bin, user local bin, jupyterlabEnv, and tools into PATH
      def pre_spawn_hook(spawner):
          username = spawner.user.name
          home_dir = f"/home/{username}"
          venv_bin = f"{home_dir}/.venvs/python-project/bin"
          local_bin = f"{home_dir}/.local/bin"
          system_paths = "${jupyterPdfExportPath}:${jupyterToolPath}:/run/current-system/sw/bin"
          spawner.environment["PATH"] = f"{venv_bin}:{local_bin}:${config.services.jupyterhub.jupyterlabEnv}/bin:{system_paths}"
          spawner.environment["VIRTUAL_ENV"] = f"{home_dir}/.venvs/python-project"
          spawner.environment["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"

      c.SystemdSpawner.pre_spawn_hook = pre_spawn_hook
    '';
  };
}
