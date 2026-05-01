# ---
# Module: Chrome - Flags
# Description: Command line arguments for Wayland, IME, and experimental features
# Scope: Home Manager
# ---

{ ... }: {
  programs.google-chrome.commandLineArgs = [
    "--password-store=gnome-libsecret"
    "--ozone-platform-hint=auto"
    "--enable-features=WaylandWindowDecorations,VerticalTabs,VerticalTabsPreviewBadge"
    "--enable-wayland-ime=true"
    "--wayland-text-input-version=3"
    "--lang=zh-CN"
  ];
}
