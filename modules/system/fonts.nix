# ---
# Module: Typography
# Description: System-wide fonts and fontconfig settings
# ---

{ pkgs, ... }: {
  fonts = {
    packages = with pkgs; [
      maple-mono.NF
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Maple Mono NF" "Noto Sans CJK SC" ];
        serif     = [ "Maple Mono NF" "Noto Serif CJK SC" ];
        monospace = [ "Maple Mono NF" "Noto Sans Mono CJK SC" ];
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
              <string>Noto Sans CJK SC</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
