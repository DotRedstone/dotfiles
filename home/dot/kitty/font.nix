# ---
# Module: Kitty Typography
# Description: Font features and stylistic sets for Maple Mono NF
# ---

{ ... }: {
  programs.kitty = {
    font = {
      name = "Maple Mono NF";
      size = 12;
    };
    
    # [Stylistic Sets & Character Variants]
    # cv06/cv61: Modern operators
    # ss03: Ligatures
    # ss11: Stylistic variants
    extraConfig = ''
      font_features MapleMono-NF +cv06 +cv61 +cv66 +cv96 +cv97 +cv98 +cv99 +ss03 +ss11
      font_features MapleMono-NF-Bold +cv06 +cv61 +cv66 +cv96 +cv97 +cv98 +cv99 +ss03 +ss11
      font_features MapleMono-NF-Italic +cv06 +cv61 +cv66 +cv96 +cv97 +cv98 +cv99 +ss03 +ss11
    '';
  };
}
