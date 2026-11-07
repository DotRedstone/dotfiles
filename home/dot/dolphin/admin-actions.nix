# ---
# Module: Dolphin Admin Actions
# Description: Context menu actions and helpers for privileged delete and folder browsing
# Scope: Home Manager
# ---

{ pkgs, ... }:

let
  dolphinAdminDelete = pkgs.writeShellScriptBin "dolphin-admin-delete" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then
      exit 0
    fi

    # 检查系统安全路径，防止误删危险根路径
    for item in "$@"; do
      real=$(${pkgs.coreutils}/bin/realpath -q "$item" 2>/dev/null || echo "$item")
      case "$real" in
        "/" | "/bin" | "/boot" | "/dev" | "/etc" | "/home" | "/lib" | "/lib64" | "/nix" | "/proc" | "/root" | "/run" | "/sbin" | "/sys" | "/tmp" | "/usr" | "/var" | "$HOME")
          ${pkgs.kdePackages.kdialog}/bin/kdialog --title "操作已阻止" --error "为了系统安全，禁止以管理员权限删除系统关键目录：\n$real"
          exit 1
          ;;
      esac
    done

    total_count=$#
    display_limit=8
    item_list=""
    count=0

    for item in "$@"; do
      count=$((count + 1))
      if [ "$count" -le "$display_limit" ]; then
        item_list+="$(${pkgs.coreutils}/bin/basename "$item")\n"
      fi
    done

    if [ "$total_count" -gt "$display_limit" ]; then
      remaining=$((total_count - display_limit))
      item_list+="... 以及另外 $remaining 个项目\n"
    fi

    msg="确定要以管理员权限永久删除以下 $total_count 个项目吗？\n\n$item_list\n警告：此操作将永久删除目标且无法撤销！"

    if ! ${pkgs.kdePackages.kdialog}/bin/kdialog --title "以管理员权限删除" --warningcontinuecancel "$msg"; then
      exit 0
    fi

    if ! /run/wrappers/bin/pkexec ${pkgs.coreutils}/bin/rm -rf -- "$@"; then
      status=$?
      if [ "$status" -ne 126 ] && [ "$status" -ne 127 ]; then
        ${pkgs.kdePackages.kdialog}/bin/kdialog --title "删除失败" --error "以管理员权限删除文件时发生错误（退出码：$status）。"
      fi
      exit "$status"
    fi

    exit 0
  '';

  dolphinAdminOpen = pkgs.writeShellScriptBin "dolphin-admin-open" ''
    set -euo pipefail

    target="''${1:-$HOME}"
    target="''${target#file://}"

    if [[ "$target" != /* ]]; then
      target="$(${pkgs.coreutils}/bin/realpath "$target")"
    fi

    exec dolphin "admin://$target"
  '';
in
{
  home.packages = [
    dolphinAdminDelete
    dolphinAdminOpen
  ];

  xdg.dataFile."kio/servicemenus/admin-delete.desktop".text = ''
    [Desktop Entry]
    Type=Service
    MimeType=all/allfiles;inode/directory;
    Actions=adminDelete;
    X-KDE-Priority=TopLevel

    [Desktop Action adminDelete]
    Name=以管理员权限删除...
    Name[zh_CN]=以管理员权限删除...
    Name[en_US]=Delete as Administrator...
    Icon=edit-delete-shred
    Exec=${dolphinAdminDelete}/bin/dolphin-admin-delete %F
  '';

  xdg.dataFile."kio/servicemenus/admin-open.desktop".text = ''
    [Desktop Entry]
    Type=Service
    MimeType=inode/directory;
    Actions=openAsAdmin;
    X-KDE-Priority=TopLevel

    [Desktop Action openAsAdmin]
    Name=以管理员身份打开文件夹
    Name[zh_CN]=以管理员身份打开文件夹
    Name[en_US]=Open Folder as Administrator
    Icon=folder-root
    Exec=${dolphinAdminOpen}/bin/dolphin-admin-open %f
  '';
}
