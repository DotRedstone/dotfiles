# ---
# Module: Java Development
# Description: OpenJDK 21, Maven, and Gradle build tooling
# Scope: Home Manager
# ---

{ pkgs, ... }: {
  home.packages = with pkgs; [
    jdk21
    maven
    gradle
  ];
}
