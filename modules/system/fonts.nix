# ---
# Module: Typography
# Description: System-wide fonts and fontconfig settings
# Scope: System
# ---

{ pkgs, ... }: {
  fonts = {
    packages = with pkgs; [
      maple-mono.NF
      inter
      lxgw-neoxihei
      lxgw-wenkai
      sarasa-gothic
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Inter" "LXGW Neo XiHei" "Noto Sans CJK SC" ];
        serif     = [ "LXGW WenKai" "Noto Serif CJK SC" ];
        monospace = [ "Maple Mono NF" "Sarasa Mono SC" "Noto Sans Mono CJK SC" ];
        emoji     = [ "Noto Color Emoji" ];
      };

      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <match target="pattern">
            <test name="lang">
              <string>zh-cn</string>
            </test>
            <edit name="family" mode="prepend">
              <string>LXGW Neo XiHei</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
