# ---
# Module: Java Development
# Description: JDK and build automation tools for the JVM ecosystem
# Scope: Home Manager
# ---

{ pkgs, ... }:
let
  awtDemoScale = "1.75";
in
{
  home.packages = with pkgs; [
    # [Runtime & SDK]
    jdk21

    # [Build Tools]
    maven
    gradle
  ];

  programs.fish.functions.java = ''
    if string match -q "/home/dot/Projects/java-5*" (pwd)
      command java \
        -Dsun.java2d.uiScale=${awtDemoScale} \
        -Dsun.awt.X11.XWMClass=java-awt-demo \
        $argv
    else
      command java $argv
    end
  '';
}
