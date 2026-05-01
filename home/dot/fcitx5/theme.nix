# ---
# Module: Fcitx5 Theming
# Description: Classic UI configuration with Mellow & Inflex Themes
# ---

{ pkgs, ... }: 
# let
#   # 1. Fetch Mellow themes
#   mellowThemes = pkgs.fetchFromGitHub {
#     owner = "sanweiya";
#     repo = "fcitx5-mellow-themes";
#     rev = "a66028fe22daa81df20e7aac1575918347b60a40";
#     sha256 = "0zg2c42lqbng8kb36w5basjj52jmk9ra050kzh011czp25k8k59m";
#   };
# 
#   # 2. Fetch Inflex themes
#   inflexThemes = pkgs.fetchFromGitHub {
#     owner = "sanweiya";
#     repo = "fcitx5-inflex-themes";
#     rev = "master";
#     sha256 = "12rngpcv3ly2d38vcvi9gja5rdfgy2rjhndf0g3y8jp7pn49dh43";
#   };
# in
{
  # [UI Settings]
  home.file.".config/fcitx5/conf/classicui.conf" = {
    force = true;
    text = ''
      Vertical Candidate List=False
      Theme=noctalia-mellow-dark
      Font="Maple Mono NF 13"
      MenuFont="Maple Mono NF 13"
      TrayFont="Maple Mono NF 10"
    '';
  };

  # [Theme Assets]
  # Merge local custom themes into a single directory using symlinkJoin
  home.file.".local/share/fcitx5/themes" = {
    source = pkgs.symlinkJoin {
      name = "fcitx5-themes-all";
      paths = [ 
        # mellowThemes 
        # inflexThemes 
        ./ori-theme 
        ./custom-themes
      ];
    };
    recursive = true;
    force = true;
  };
}
