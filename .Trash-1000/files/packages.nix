{ pkgs, ... }: {
  # 这些包会被安装到全局 PATH，所有 GUI 软件和脚本都能直接访问
  environment.systemPackages = with pkgs; [
    python3  # 🌟 核心救命包：解决 Noctalia 脚本的解释器依赖
    wget
    curl
    unzip
    git      # 顺手带上，系统级排障必备
  ];
}
