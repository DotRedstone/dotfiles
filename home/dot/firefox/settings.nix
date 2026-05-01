# ---
# Module: Firefox Settings
# Description: Performance, behavior, and typography overrides
# Scope: Home Manager
# ---

{ ... }: {
  programs.firefox.profiles.dot.settings = {
    # [Locale & UI]
    "intl.locale.requested" = "zh-CN";
    "browser.startup.page" = 3; # Restore previous session
    "browser.tabs.loadInBackground" = false; # Switch to new tabs immediately
    "browser.tabs.insertRelatedAfterCurrent" = true;
    "ui.systemUsesDarkTheme" = 1;

    # [Vertical Tabs - 2026 Modern UI]
    "sidebar.verticalTabs" = true;
    "sidebar.revamp" = true;

    # [Typography]
    # Matching Warden's system-wide fonts
    "font.name.sans-serif.zh-CN" = "Noto Sans CJK SC";
    "font.name.serif.zh-CN" = "Noto Serif CJK SC";
    "font.name.monospace.zh-CN" = "Maple Mono NF";
    "font.default.zh-CN" = "sans-serif";

    # [Downloads]
    "browser.download.dir" = "/home/dot/Downloads";
    "browser.download.folderList" = 2;

    # [Privacy & Behavior]
    "general.autoScroll" = true;
    "signon.rememberSignons" = false; # Use a password manager instead
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Enable userChrome.css

    # [Performance]
    "gfx.webrender.all" = true; # Force hardware acceleration
    "media.ffmpeg.vaapi.enabled" = true; # Video hardware decoding
  };
}
