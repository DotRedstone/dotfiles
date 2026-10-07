# ---
# Module: Default Applications
# Description: Declarative MIME type associations and default application bindings
# Scope: Home Manager
# ---

{ pkgs, lib, ... }: {
  # [Session Variables]
  home.sessionVariables = {
    BROWSER = "zen";
    DEFAULT_BROWSER = "zen";
    FILEMANAGER = "dolphin";
  };

  # [Desktop Entries]
  # Provide zen.desktop alias pointing to zen %U for tools that look for generic zen.desktop
  xdg.desktopEntries.zen = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "zen %U";
    icon = "zen-browser";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  # [MIME Associations]
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Web Browsing (Zen Browser)
      "text/html" = [ "zen-beta.desktop" "zen.desktop" ];
      "text/xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/xhtml_xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/rss+xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/rdf+xml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/x-extension-htm" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/x-extension-html" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/x-extension-shtml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/x-extension-xhtml" = [ "zen-beta.desktop" "zen.desktop" ];
      "application/x-extension-xht" = [ "zen-beta.desktop" "zen.desktop" ];
      "x-scheme-handler/http" = [ "zen-beta.desktop" "zen.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" "zen.desktop" ];
      "x-scheme-handler/chrome" = [ "zen-beta.desktop" "zen.desktop" ];
      "x-scheme-handler/about" = [ "zen-beta.desktop" "zen.desktop" ];
      "x-scheme-handler/unknown" = [ "zen-beta.desktop" "zen.desktop" ];

      # File Manager (KDE Dolphin)
      "inode/directory" = [ "org.kde.dolphin.desktop" ];
      "x-scheme-handler/file" = [ "org.kde.dolphin.desktop" ];

      # PDF Documents (Zathura)
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];

      # Images (imv)
      "image/png" = [ "imv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "image/webp" = [ "imv.desktop" ];
      "image/bmp" = [ "imv.desktop" ];
      "image/svg+xml" = [ "imv.desktop" ];

      # Messaging & Utilities
      "x-scheme-handler/tg" = [ "org.telegram.desktop.desktop" ];
      "x-scheme-handler/tonsite" = [ "org.telegram.desktop.desktop" ];
      "x-scheme-handler/clash" = [ "clash-verge.desktop" ];
      "x-scheme-handler/clash-verge" = [ "clash-verge.desktop" ];
      "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
    };
  };

  # [Portal Cache Cleanup]
  # Ensure portal PermissionStore never retains stale Chrome overrides for PDF or HTML
  home.activation.cleanPortalUsedApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v gdbus >/dev/null 2>&1; then
      ${pkgs.glib}/bin/gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
        --object-path /org/freedesktop/impl/portal/PermissionStore \
        --method org.freedesktop.impl.portal.PermissionStore.Delete 'desktop-used-apps' 'application/pdf' 2>/dev/null || true
      ${pkgs.glib}/bin/gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
        --object-path /org/freedesktop/impl/portal/PermissionStore \
        --method org.freedesktop.impl.portal.PermissionStore.Delete 'desktop-used-apps' 'text/html' 2>/dev/null || true
      ${pkgs.glib}/bin/gdbus call --session --dest org.freedesktop.impl.portal.PermissionStore \
        --object-path /org/freedesktop/impl/portal/PermissionStore \
        --method org.freedesktop.impl.portal.PermissionStore.Delete 'desktop-used-apps' 'application/xhtml+xml' 2>/dev/null || true
    fi
  '';
}
