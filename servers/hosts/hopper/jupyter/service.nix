# ---
# Module: Hopper JupyterHub Service
# Description: Core JupyterHub daemon, kernels, environment, and spawner hooks
# Scope: Host
# ---

{ config, pkgs, jupyterExtensions, jupyterPaths, ... }: {
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
      # Kernel and package-management baseline.
      ipykernel
      pip
      setuptools
      wheel
      jupyterhub
      jupyterlab
      nbconvert
      jupyterExtensions.chinese
      jupyterExtensions.catppuccin
      jupyterExtensions.themeToggler
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
          system_paths = "${jupyterPaths.jupyterPdfExportPath}:${jupyterPaths.jupyterToolPath}:/run/current-system/sw/bin"
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
