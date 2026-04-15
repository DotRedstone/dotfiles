# ---
# Module: Fcitx5 Theming
# Description: Classic UI configuration and custom OriDark/Light themes
# ---

{ ... }: {
  # [UI Settings]
  home.file.".config/fcitx5/conf/classicui.conf" = {
    force = true;
    text = ''
      Vertical Candidate List=False
      Theme=OriDark
      Font="Sans Serif 12"
      MenuFont="Sans Serif 12"
      TrayFont="Sans Serif 12"
    '';
  };

  # [Theme Assets]
  home.file.".local/share/fcitx5/themes/OriDark" = {
    source = ./ori-theme/OriDark;
    force = true;
  };
  home.file.".local/share/fcitx5/themes/OriLight" = {
    source = ./ori-theme/OriLight;
    force = true;
  };
}
