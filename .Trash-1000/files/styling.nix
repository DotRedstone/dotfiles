{ pkgs, config, ... }: {

  # 1. 开启 Plymouth（开机动画）
  boot.plymouth = {
    enable = true;
    # 如果你想看到红米/小米的 Logo，可以选 'bgrt'（利用 BIOS 原生 Logo）
    # 或者用之前那个炫酷的 'colorful_loop'
    theme = "bgrt"; 
  };

  # 2. 核心：内核与启动参数（彻底闭嘴）
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  
  # 重点：开启 initrd 的 systemd 支持，能让动画衔接更丝滑
  boot.initrd.systemd.enable = true;

  boot.kernelParams = [
    "quiet"           # 核心：内核别说话
    "splash"          # 开启启动背景
    "boot.shell_on_fail"
    "loglevel=3"      # 只显示严重错误
    "rd.systemd.show_status=false" # 禁用 initrd 里的状态输出
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "vt.global_cursor_default=0"  # 👈 隐藏那个闪烁的光标
  ];

  # 3. 引导菜单优化
  boot.loader.systemd-boot = {
    configurationLimit = 5;
    consoleMode = "max"; # 强制高分屏
  };
  boot.loader.timeout = 1; # 菜单只停留1秒，或者设为 0 彻底跳过（不建议）

  # 4. 解决进入 SDDM 前的最后一次“黑屏/闪烁”
  # 让 SDDM 在图形驱动准备好之后再启动
  systemd.services.display-manager.after = [ "rc-local.service" ];
}
