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
    # Qt 6.12 下 qsb 编译 shader 需要 spirv-opt，nixpkgs 未把 spirv-tools 传进构建环境。
    nativeBuildInputs = (previous.nativeBuildInputs or [ ]) ++ [ pkgs.spirv-tools ];
    # 1.1.2 在 Qt 6.12 / GCC 15 下有几处漏掉的标准头文件 include。
    postPatch = (previous.postPatch or "") + ''
      sed -i '1i #include <unistd.h>' core/log.cpp
      sed -i '1i #include <mutex>' request/session_share.cpp
    '';
  });
in {
  home.packages = [ qcm ];
}
