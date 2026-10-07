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
    \documentclass[UTF8,11pt,fontset=none]{ctexart}
    ((*- endblock docclass -*))

    ((*- block packages -*))
    ((( super() )))
    \usepackage{fontspec}
    \usepackage{tcolorbox}
    \tcbuselibrary{skins,breakable}
    \usepackage{fancyhdr}
    \usepackage{lastpage}
    \usepackage{booktabs}
    \usepackage{tabularx}
    \usepackage{enumitem}
    \usepackage{amssymb}
    \usepackage{newunicodechar}

    % Unicode character fallbacks
    \newunicodechar{≈}{\ensuremath{\approx}}
    \newunicodechar{□}{\ensuremath{\square}}
    \newunicodechar{≤}{\ensuremath{\le}}
    \newunicodechar{≥}{\ensuremath{\ge}}
    \newunicodechar{≠}{\ensuremath{\ne}}
    \newunicodechar{±}{\ensuremath{\pm}}
    \newunicodechar{×}{\ensuremath{\times}}
    \newunicodechar{÷}{\ensuremath{\div}}

    % Page Geometry: Modern clean margins on A4
    \geometry{a4paper, top=2.2cm, bottom=2.2cm, left=2.2cm, right=2.2cm, headheight=16pt, footskip=14pt}

    % Line spacing & paragraph
    \linespread{1.18}
    \setlength{\parskip}{0.5em plus 0.2em minus 0.1em}
    \setlength{\parindent}{0pt}
    \setlist{nosep, leftmargin=1.5em}

    % Section depth
    \setcounter{secnumdepth}{-1}
    ((*- endblock packages -*))

    ((*- block definitions -*))
    ((( super() )))

    % Disable legacy margin-hanging prompt
    \renewcommand{\prompt}[4]{}

    % Modern Color Palette
    \definecolor{brandblue}{HTML}{0969DA}
    \definecolor{darkslate}{HTML}{24292F}
    \definecolor{lightgray}{HTML}{57606A}
    \definecolor{codebg}{HTML}{F6F8FA}
    \definecolor{codeframe}{HTML}{D0D7DE}
    \definecolor{outbg}{HTML}{FFFFFF}
    \definecolor{outframe}{HTML}{D0D7DE}
    \definecolor{streambg}{HTML}{F6F8FA}
    \definecolor{streambar}{HTML}{0969DA}
    \definecolor{quoteframe}{HTML}{0969DA}
    \definecolor{quotebg}{HTML}{F0F7FF}

    % Transform Pandoc default 0.5\linewidth horizontal rules (---) into full-width modern dividers
    \NewCommandCopy{\origrule}{\rule}
    \RenewDocumentCommand{\rule}{o m m}{%
      \IfValueTF{#1}{%
        \origrule[#1]{#2}{#3}%
      }{%
        \def\targetw{0.5\linewidth}%
        \def\currw{#2}%
        \ifx\currw\targetw
          {\par\vspace{0.4em}\noindent\color{codeframe}\origrule{\linewidth}{0.6pt}\par\vspace{0.4em}}%
        \else
          \origrule{#2}{#3}%
        \fi
      }%
    }

    % Font Configuration
    \setmainfont{DejaVu Sans}[
      BoldFont = DejaVu Sans,
      BoldFeatures = {Weight=bold}
    ]
    \setsansfont{DejaVu Sans}

    % Monospace font: JetBrains Mono
    \setmonofont{JetBrainsMono-Regular.ttf}[
      Path = ${pkgs.jetbrains-mono}/share/fonts/truetype/,
      BoldFont = JetBrainsMono-Bold.ttf,
      ItalicFont = JetBrainsMono-Italic.ttf,
      Scale = 0.88
    ]

    % CJK Fonts
    \setCJKmainfont{SourceHanSans.ttc}[
      Path = ${pkgs.source-han-sans}/share/fonts/truetype/,
      FontIndex = 2,
      AutoFakeBold = 2.5
    ]
    \setCJKsansfont{SourceHanSans.ttc}[
      Path = ${pkgs.source-han-sans}/share/fonts/truetype/,
      FontIndex = 2,
      AutoFakeBold = 2.5
    ]
    \setCJKmonofont{LXGWWenKaiMono-Regular.ttf}[
      Path = ${pkgs.lxgw-wenkai}/share/fonts/truetype/,
      BoldFont = LXGWWenKaiMono-Medium.ttf,
      Scale = 0.9
    ]

    % Modern Section Headings with Accent Decorations
    \ctexset{
      section = {
        format = \Large\bfseries\color{darkslate}\raggedright\color{brandblue}\rule[-0.15ex]{3.5pt}{1.15em}\hspace{0.5em}\color{darkslate},
        beforeskip = 2.4ex plus 0.5ex minus 0.2ex,
        afterskip = 1.2ex
      },
      subsection = {
        format = \large\bfseries\color{darkslate}\raggedright\color{brandblue!80}\raisebox{0.1ex}{\footnotesize\ensuremath{\blacktriangleright}}\hspace{0.4em}\color{darkslate},
        beforeskip = 1.8ex plus 0.4ex minus 0.2ex,
        afterskip = 0.8ex
      },
      subsubsection = {
        format = \normalsize\bfseries\color{brandblue}\raggedright,
        beforeskip = 1.2ex plus 0.3ex minus 0.2ex,
        afterskip = 0.6ex
      }
    }

    % Modern GitHub Primer Syntax Highlighting
    \makeatletter
    \expandafter\def\csname PY@tok@c\endcsname{\let\PY@it=\textit\color[HTML]{6E7781}}
    \expandafter\def\csname PY@tok@c1\endcsname{\let\PY@it=\textit\color[HTML]{6E7781}}
    \expandafter\def\csname PY@tok@cm\endcsname{\let\PY@it=\textit\color[HTML]{6E7781}}
    \expandafter\def\csname PY@tok@k\endcsname{\let\PY@bf=\textbf\color[HTML]{CF222E}}
    \expandafter\def\csname PY@tok@kn\endcsname{\let\PY@bf=\textbf\color[HTML]{CF222E}}
    \expandafter\def\csname PY@tok@kd\endcsname{\let\PY@bf=\textbf\color[HTML]{CF222E}}
    \expandafter\def\csname PY@tok@s\endcsname{\color[HTML]{0A3069}}
    \expandafter\def\csname PY@tok@s1\endcsname{\color[HTML]{0A3069}}
    \expandafter\def\csname PY@tok@s2\endcsname{\color[HTML]{0A3069}}
    \expandafter\def\csname PY@tok@nb\endcsname{\color[HTML]{8250DF}}
    \expandafter\def\csname PY@tok@nf\endcsname{\color[HTML]{8250DF}}
    \expandafter\def\csname PY@tok@m\endcsname{\color[HTML]{0550AE}}
    \expandafter\def\csname PY@tok@mi\endcsname{\color[HTML]{0550AE}}
    \expandafter\def\csname PY@tok@mf\endcsname{\color[HTML]{0550AE}}
    \expandafter\def\csname PY@tok@o\endcsname{\color[HTML]{CF222E}}
    \makeatother

    % Modern Header & Footer (fancyhdr)
    \pagestyle{fancy}
    \fancyhf{}
    \renewcommand{\headrulewidth}{0.4pt}
    \renewcommand{\headrule}{\hbox to\headwidth{\color{codeframe}\leaders\hrule height \headrulewidth\hfill}}
    \renewcommand{\footrulewidth}{0pt}
    \fancyhead[L]{\small\color{lightgray}\textsf{Jupyter Notebook}}
    \fancyhead[R]{\small\color{lightgray}\textsf{\thepage\ / \pageref{LastPage}}}
    \fancyfoot[L]{\footnotesize\color{lightgray!70}\textsf{Generated with JupyterLab}}
    \fancyfoot[R]{\footnotesize\color{lightgray}\textsf{\today}}

    % Modern Blockquote
    \renewenvironment{quote}{%
      \begin{tcolorbox}[
        breakable,
        enhanced,
        colback=quotebg,
        colframe=quoteframe,
        borderline west={2.5pt}{0pt}{quoteframe},
        boxrule=0pt,
        frame hidden,
        arc=0pt,
        left=3.5mm, right=3mm, top=2mm, bottom=2mm,
        before skip=2mm, after skip=2mm
      ]
    }{%
      \end{tcolorbox}
    }

    % Box styles for code & outputs
    \tcbset{
      jupyterinbox/.style={
        breakable,
        enhanced,
        colback=codebg,
        colframe=codeframe,
        boxrule=0.6pt,
        arc=3.5pt,
        left=3.5mm,
        right=3.5mm,
        top=2.5mm,
        bottom=2.5mm,
        before skip=2.5mm,
        after skip=1mm
      },
      jupyteroutbox/.style={
        breakable,
        enhanced,
        colback=outbg,
        colframe=outframe,
        boxrule=0.5pt,
        arc=3.5pt,
        left=3.5mm,
        right=3.5mm,
        top=2mm,
        bottom=2mm,
        before skip=0.8mm,
        after skip=2.5mm
      },
      jupyterstreambox/.style={
        breakable,
        enhanced,
        borderline west={2pt}{0pt}{streambar},
        colback=streambg,
        boxrule=0pt,
        frame hidden,
        arc=0pt,
        left=3mm,
        right=2mm,
        top=1.5mm,
        bottom=1.5mm,
        before skip=1mm,
        after skip=2mm
      }
    }
    ((*- endblock definitions -*))

    ((*- block maketitle -*))
    ((*- endblock maketitle -*))

    ((* block input scoped *))
    ((*- if cell.execution_count is defined and cell.execution_count is not none -*))
      ((*- set count = cell.execution_count -*))
    ((*- else -*))
      ((*- set count = " " -*))
    ((*- endif -*))
    \begin{tcolorbox}[jupyterinbox,
      title={\scriptsize\sffamily\bfseries\color{brandblue!90!black}\textsc{In}\,[((( count )))]},
      attach boxed title to top left={xshift=2.5mm, yshift=-2.2mm},
      boxed title style={size=small, colframe=codeframe, colback=codebg, arc=2pt, boxrule=0.5pt, left=1.5mm, right=1.5mm, top=0.5mm, bottom=0.5mm}
    ]
    \begin{Verbatim}[commandchars=\\\{\}]
    ((( cell.source | highlight_code(strip_verbatim=True) )))
    \end{Verbatim}
    \end{tcolorbox}
    ((* endblock input *))

    ((* block execute_result scoped *))
    ((*- if cell.execution_count is defined and cell.execution_count is not none -*))
      ((*- set count = cell.execution_count -*))
    ((*- else -*))
      ((*- set count = " " -*))
    ((*- endif -*))
    ((*- for type in output.data | filter_data_type -*))
      ((*- if type in ['text/plain'] -*))
    \begin{tcolorbox}[jupyteroutbox,
      title={\scriptsize\sffamily\bfseries\color{orange!85!black}\textsc{Out}\,[((( count )))]},
      attach boxed title to top left={xshift=2.5mm, yshift=-2.2mm},
      boxed title style={size=small, colframe=outframe, colback=white, arc=2pt, boxrule=0.5pt, left=1.5mm, right=1.5mm, top=0.5mm, bottom=0.5mm}
    ]
    \begin{Verbatim}[commandchars=\\\{\}]
    ((( output.data['text/plain'] | wrap_text(charlim) | escape_latex | ansi2latex )))
    \end{Verbatim}
    \end{tcolorbox}
      ((*- else -*))
        ((( super() )))
      ((*- endif -*))
    ((*- endfor -*))
    ((* endblock execute_result *))

    ((* block stream *))
    \begin{tcolorbox}[jupyterstreambox]
    \begin{Verbatim}[commandchars=\\\{\}]
    ((( output.text | wrap_text(charlim) | escape_latex | strip_trailing_newline | ansi2latex )))
    \end{Verbatim}
    \end{tcolorbox}
    ((* endblock stream *))
  '';

  fonts.packages = [
    pkgs.noto-fonts-cjk-sans
    pkgs.noto-fonts-cjk-serif
    pkgs.source-han-sans
    pkgs.jetbrains-mono
    pkgs.lxgw-wenkai
  ];

  services.jupyterhub = {
    enable = true;
    host = "127.0.0.1";
    # 8001 is ConfigurableHTTPProxy's internal API port; keep its public
    # listener on the conventional adjacent loopback port instead.
    port = 8000;
    kernels = {
      python3 = {
        displayName = "Python 3";
        argv = [
          "${config.services.jupyterhub.jupyterlabEnv.interpreter}"
          "-m"
          "ipykernel_launcher"
          "-f"
          "{connection_file}"
        ];
        language = "python";
        logo32 = "${config.services.jupyterhub.jupyterlabEnv}/${config.services.jupyterhub.jupyterlabEnv.sitePackages}/ipykernel/resources/logo-32x32.png";
        logo64 = "${config.services.jupyterhub.jupyterlabEnv}/${config.services.jupyterhub.jupyterlabEnv.sitePackages}/ipykernel/resources/logo-64x64.png";
      };
    };
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
          venv_site_packages = f"{home_dir}/.venvs/python-project/lib/${config.services.jupyterhub.jupyterlabEnv.libPrefix}/site-packages"
          local_bin = f"{home_dir}/.local/bin"
          system_paths = "${jupyterPdfExportPath}:${jupyterToolPath}:/run/current-system/sw/bin"
          current_jupyter_path = spawner.environment.get("JUPYTER_PATH", "")
          spawner.environment["PATH"] = f"{venv_bin}:{local_bin}:${config.services.jupyterhub.jupyterlabEnv}/bin:{system_paths}"
          spawner.environment["VIRTUAL_ENV"] = f"{home_dir}/.venvs/python-project"
          spawner.environment["PYTHONPATH"] = venv_site_packages
          spawner.environment["JUPYTER_PATH"] = f"{home_dir}/.local/share/jupyter:{current_jupyter_path}"
          spawner.environment["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"

      c.SystemdSpawner.pre_spawn_hook = pre_spawn_hook
    '';
  };
}
