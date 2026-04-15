{ pkgs, ... }: {
  # --- 音频系统 (PipeWire) ---
  # Wayland 环境下必须使用 PipeWire
  security.rtkit.enable = true; # 用于实时音频调度
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # 如果需要低延迟音频可以开启 jack
    # jack.enable = true;
  };

  # --- 蓝牙配置 ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # 开机自启蓝牙
  };
  services.blueman.enable = true; # 提供蓝牙图形管理界面

  # --- 硬件控制工具 (亮度、音量等) ---
  environment.systemPackages = with pkgs; [
    brightnessctl # 亮度调节 (Fn 键必须)
    pamixer       # 命令行音量调节
    pulsemixer    # TUI 音量混音器
  ];
}
