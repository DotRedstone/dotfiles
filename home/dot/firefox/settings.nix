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
    # Avoid toolbar popup offset and jumpiness on mixed-scale Niri outputs.
    "widget.wayland.fractional-scale.enabled" = false;

    # [Privacy & Password Management]
    "general.autoScroll" = true;
    "signon.rememberSignons" = false; # Handled by 1Password
    "signon.autofillForms" = false;
    "signon.generation.enabled" = false;
    "signon.management.page.breach-alerts.enabled" = false;
    "signon.firefoxRelay.feature" = "disabled";
    "extensions.formautofill.addresses.enabled" = false;
    "extensions.formautofill.creditCards.enabled" = false;
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # Enable userChrome.css

    # [Performance]
    "gfx.webrender.all" = true; # Force hardware acceleration
    "media.ffmpeg.vaapi.enabled" = true; # Video hardware decoding
  };
}
