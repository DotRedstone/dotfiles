# ---
# Module: Zen Browser - Settings
# Description: Performance, behavior, locale, and typography overrides for Zen Browser
# Scope: Home Manager
# ---

{ ... }: {
  programs.zen-browser.profiles.dot.settings = {
    # [Locale & UI]
    "intl.locale.requested" = "zh-CN";
    "intl.locale.matchOS" = true;
    "browser.startup.page" = 3; # Restore previous session
    "browser.tabs.loadInBackground" = false; # Switch to new tabs immediately
    "browser.tabs.insertRelatedAfterCurrent" = true;

    # [Theme & Contrast]
    "ui.systemUsesDarkTheme" = 1;
    "browser.theme.content-theme" = 0; # 0 = Dark
    "browser.theme.toolbar-theme" = 0; # 0 = Dark
    "layout.css.prefers-color-scheme.content-override" = 0; # 0 = Dark
    "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
    "devtools.chrome.enabled" = true;

    # [Typography]
    # Matching Warden's system-wide fonts
    "font.name.sans-serif.zh-CN" = "FZYJHK B";
    "font.name.serif.zh-CN" = "FZYJHK B";
    "font.name.monospace.zh-CN" = "Sarasa Mono SC";
    "font.default.zh-CN" = "sans-serif";

    "font.name.sans-serif.x-western" = "Inter";
    "font.name.serif.x-western" = "FZYJHK B";
    "font.name.monospace.x-western" = "Maple Mono NF";
    "font.default.x-western" = "sans-serif";

    # [Downloads]
    "browser.download.dir" = "/home/dot/Downloads";
    "browser.download.folderList" = 2;

    # [Wayland / Mixed DPI]
    "widget.wayland.fractional-scale.enabled" = true;

    # [Privacy & Behavior]
    "general.autoScroll" = true;
    "signon.rememberSignons" = false; # Use Bitwarden
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "zen.window-sync.enabled" = false; # Keep windows independent instead of mirroring all tabs

    # [Performance]
    "gfx.webrender.all" = true; # Force hardware acceleration
    "media.ffmpeg.vaapi.enabled" = true; # Video hardware decoding

    # [Media & MPRIS Integration]
    "media.hardwaremediakeys.enabled" = true;
    "dom.media.mediasession.enabled" = true;
  };
}
