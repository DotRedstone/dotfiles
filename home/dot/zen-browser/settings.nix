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
    "browser.theme.content-theme" = 2; # 2 = Follow system
    "browser.theme.toolbar-theme" = 2; # 2 = Follow system
    "layout.css.prefers-color-scheme.content-override" = 2; # 2 = Follow system
    "extensions.activeThemeID" = "default-theme@mozilla.org";
    "zen.view.window.scheme" = 2; # 2 = Follow system (Auto)
    "zen.theme.use-system-colors" = true;
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

    # [Privacy & Password Management]
    "general.autoScroll" = true;
    "signon.rememberSignons" = false; # Handled by 1Password
    "signon.autofillForms" = false;
    "signon.generation.enabled" = false;
    "signon.management.page.breach-alerts.enabled" = false;
    "signon.firefoxRelay.feature" = "disabled";
    "extensions.formautofill.addresses.enabled" = false;
    "extensions.formautofill.creditCards.enabled" = false;
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "zen.window-sync.enabled" = false; # Keep windows independent instead of mirroring all tabs

    # [WebRTC Privacy & Functionality (RFC 8828)]
    # Prevent local LAN IP leaks without disabling WebRTC functionality
    "media.peerconnection.enabled" = true;
    "media.peerconnection.ice.default_address_only" = true;
    "media.peerconnection.ice.no_host" = true;
    "media.peerconnection.ice.proxy_only" = false;

    # [Performance]
    "gfx.webrender.all" = true; # Force hardware acceleration
    "media.ffmpeg.vaapi.enabled" = true; # Video hardware decoding

    # [Media & MPRIS Integration]
    "media.hardwaremediakeys.enabled" = true;
    "dom.media.mediasession.enabled" = true;
  };
}
