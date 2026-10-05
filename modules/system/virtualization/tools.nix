# ---
# Module: Virtualization - Tools
# Description: Graphical management tools for virtualization
# Scope: System
# ---

{ pkgs, ... }: {
  programs.virt-manager = {
    enable = true;
    package = pkgs.virt-manager.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace virtinst/__init__.py \
          --replace-fail 'gettext.bindtextdomain("virt-manager", BuildConfig.gettext_dir)' \
                         'gettext.bindtextdomain("virt-manager", BuildConfig.gettext_dir); locale.bindtextdomain("virt-manager", BuildConfig.gettext_dir)'
      '';
    });
  };
}
