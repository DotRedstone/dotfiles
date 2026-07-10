# ---
# Module: Xiaomi WMI Fan Mode Override
# Description: Uses acpi_call to bypass buggy bitland_mifs_wmi for performance mode
# Scope: System
# ---
{ pkgs, ... }:

let
  xiaomi-fan-mode = pkgs.writeShellScriptBin "xiaomi-fan-mode" ''
    if [ "$#" -ne 1 ]; then
      echo "Usage: xiaomi-fan-mode [quiet|balanced|performance]"
      exit 1
    fi

    # 确保加载了 acpi_call
    if ! lsmod | grep -q acpi_call; then
      modprobe acpi_call || echo "Warning: acpi_call not loaded"
    fi

    case "$1" in
      quiet|low-power)
        # 0x02
        echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x02,0x00,0x00,0x00,0x00,0x00}' > /proc/acpi/call
        ;;
      balanced)
        # 0x01
        echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x01,0x00,0x00,0x00,0x00,0x00}' > /proc/acpi/call
        ;;
      performance|berserk)
        # 0x03
        echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x03,0x00,0x00,0x00,0x00,0x00}' > /proc/acpi/call
        ;;
      full-speed|max)
        # 0x04
        echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x04,0x00,0x00,0x00,0x00,0x00}' > /proc/acpi/call
        ;;
      *)
        echo "Unknown mode: $1"
        exit 1
        ;;
    esac
  '';
in
{
  # 允许普通用户执行免密码调用以写入 acpi_call
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/tee /proc/acpi/call";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "xiaomi-fan-mode" ''
      if [ "$#" -ne 1 ]; then
        echo "Usage: xiaomi-fan-mode [quiet|balanced|performance]"
        exit 1
      fi
      
      case "$1" in
        quiet|low-power)
          echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x02,0x00,0x00,0x00,0x00,0x00}' | sudo tee /proc/acpi/call > /dev/null
          ;;
        balanced)
          echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x01,0x00,0x00,0x00,0x00,0x00}' | sudo tee /proc/acpi/call > /dev/null
          ;;
        performance|berserk)
          echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x03,0x00,0x00,0x00,0x00,0x00}' | sudo tee /proc/acpi/call > /dev/null
          ;;
        full-speed|max)
          echo '\_SB.PC00.WMID.WMAA 1 1 {0x00,0xFB,0x00,0x08,0x04,0x00,0x00,0x00,0x00,0x00}' | sudo tee /proc/acpi/call > /dev/null
          ;;
        *)
          echo "Unknown mode: $1"
          exit 1
          ;;
      esac
    '')
  ];
}
