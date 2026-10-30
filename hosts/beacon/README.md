# Beacon (Mac mini) 无头服务器指南

## 主机角色与定位

- **设备**：Apple Silicon Mac mini（局域网主机名 `beacon`）
- **操作系统**：原生 macOS
- **纳管方案**：声明式 `nix-darwin` + `home-manager`
- **主要用途**：
  1. **我的世界（Minecraft）高可用服务器**：基于 PaperMC + Java 21，内置 Aikar's Flags 低延迟 GC 优化，由 launchd 守护自动重启。
  2. **AI 本地推理与 DSH Agent 计算节点**：借助 Apple Silicon 统一内存与 Metal 硬件加速，常驻运行 Ollama（局域网端口 `11434`），提供 OpenAI 兼容接口；内置 DSH（DeepSeek Harness）运行环境与工具链。

## 目录结构

```text
hosts/beacon/
├── default.nix            # 主机入口：nixpkgs 平台架构与 Nix 守护配置
├── headless.nix           # 无头优化：pmset 防睡眠、息屏不挂起、断电自启、唤醒
├── networking.nix         # 网络与权限：主机名设置、SSH 免密公钥
├── services/
│   ├── default.nix        # 服务组织总控
│   ├── minecraft.nix      # Minecraft 服务器（PaperMC / Aikar's GC / launchd）
│   └── ai.nix             # AI 服务（Metal-accelerated Ollama + DSH 运行环境）
├── home.nix               # 用户 dot 的 Home Manager CLI 环境
└── README.md              # 本说明文档
```

## 初次接入流程 (Bootstrap)

在 Mac mini 联网后，直接按以下三步完成声明式收编：

### 1. 安装 Nix

推荐使用官方或 Determinate Nix 安装器：

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

安装完成后重新打开终端，或执行 `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`。

### 2. 克隆配置

```bash
git clone https://github.com/DotRedstone/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 3. 应用 nix-darwin 配置

```bash
nix run nix-darwin -- switch --flake .#beacon
```

后续更新配置只需要在 Mac mini 上执行：

```bash
darwin-rebuild switch --flake ~/.dotfiles#beacon
```

## 服务使用与运维

### 1. 我的世界服务器 (Minecraft)

- **服务状态与日志**：
  - 数据与插件目录：`/Users/Shared/minecraft`
  - 标准输出日志：`/Users/Shared/minecraft/logs/launchd-stdout.log`
  - 错误日志：`/Users/Shared/minecraft/logs/launchd-stderr.log`
- **连接方式**：局域网内任意客户端直接连接 `beacon:25565`（或 Mac mini 的局域网 IP）。
- **更新版本或更换核心**：直接替换 `/Users/Shared/minecraft/server.jar` 即可。

### 2. AI 本地推理 (Ollama) 与 DSH

- **Ollama 局域网接口**：
  - 服务自动常驻并在后台监听 `http://0.0.0.0:11434`。
  - 在你的主力 Linux 工作站（`warden`）或手机上，可直接将 OpenAI Base URL 设置为 `http://beacon:11434/v1`。
  - 拉取模型（例如 DeepSeek 或 Qwen 系列）：
    ```bash
    ollama pull deepseek-r1:14b
    ollama pull qwen2.5-coder:14b
    ```
- **DSH (DeepSeek Harness) 运行时**：
  - 系统内置 `dsh-run` 命令，预设指向本地 Metal 加速端点。
  - 工作目录位于 `~/.dsh`，用于执行多步 Agent 工具调用与代码推理。

### 3. 无头状态检查

- 检查防休眠状态：
  ```bash
  pmset -g
  ```
  应显示 `sleep 0`、`displaysleep 0`、`disksleep 0`、`autorestart 1`。
