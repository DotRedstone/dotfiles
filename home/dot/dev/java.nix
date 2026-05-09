# ---
# Module: Java Development
# Description: JDK and build automation tools for the JVM ecosystem
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    # [Runtime & SDK]
    jdk21

    # [Build Tools]
    maven
    gradle
  ];
}
