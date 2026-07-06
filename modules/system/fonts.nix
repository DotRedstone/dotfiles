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
      (runCommand "mfga-selfuse-font" {} ''
        mkdir -p $out/share/fonts/truetype
        cp ${./fonts/mfga-selfuse}/*.ttf $out/share/fonts/truetype/
      '')
      sarasa-gothic
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Inter" "FZYJHK B" "Noto Sans CJK SC" ];
        serif     = [ "FZYJHK B" "Noto Serif CJK SC" ];
        monospace = [ "Maple Mono NF" "FZYJHK B" "Sarasa Mono SC" "Noto Sans Mono CJK SC" ];
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
              <string>FZYJHK B</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
