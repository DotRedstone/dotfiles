# ---
# Module: QCM
# Description: Qt-based third-party NetEase Cloud Music client
# Scope: Home Manager
# ---

{ pkgs, ... }:

let
  # Nixpkgs' QCM expression omits the two private Qt components it links
  # against.  Keep the compatibility fix local until it lands upstream.
  qcm = pkgs.qcm.overrideAttrs (previous: {
    patches = (previous.patches or [ ]) ++ [ ./qcm-qt-private-targets.patch ];
  });
in {
  home.packages = [ qcm ];
}
