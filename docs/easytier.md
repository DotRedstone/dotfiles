# EasyTier Mesh VPN

EasyTier 是一个简单、去中心化、自带内网穿透能力的网状组网方案。本项目将 EasyTier Core 纳入 NixOS 服务管理，并通过本地环境变量文件读取敏感参数。

## 配置方式

EasyTier 服务会从以下路径读取参数：
`/persist/secrets/easytier.env`

该文件由用户手动创建，内容示例如下：

**方式一：使用快速连接 URI（推荐）**

如果 Web 面板或控制台提供了一键连接的 `-w` 参数（例如 `easytier-core -w udp://[ip]:[port]/[network]`），你可以直接使用 URI：

```bash
EASYTIER_URI="udp://[ip]:[port]/[network]"
# 可选：如果还需要附加参数，可以使用 EXTRA_ARGS
# EASYTIER_EXTRA_ARGS="--hostname my-nixos"
```

**方式二：手动配置连接参数**

```bash
# 组网名称 (必填)
EASYTIER_NETWORK_NAME=your_network_name
# 组网密码 (必填)
EASYTIER_NETWORK_SECRET=your_network_secret
# 本机虚拟 IP (可选)
EASYTIER_IPV4=10.14.4.1
# 种子节点地址 (可选，空格分隔多个地址)
EASYTIER_PEERS="tcp://public_peer:11010"
# 其他额外参数 (可选)
EASYTIER_EXTRA_ARGS="--hostname my-nixos --rpc-portal 127.0.0.1:15888"
```

> [!IMPORTANT]
> 请勿将包含真实参数的 `easytier.env` 文件提交到 Git 仓库。

## 管理服务

### 常用命令

- **查看状态**: `systemctl status easytier`
- **重启服务**: `sudo systemctl restart easytier` (或使用 `easytier-restart`)
- **查看简洁状态**: `easytier-status`
- **使用 CLI**: `easytier-cli peer`

### 脚本说明

- `easytier-start`: systemd 服务调用的启动包装脚本，负责参数校验和组装。
- `easytier-status`: 输出包含状态和 peer 数量的 JSON。
- `easytier-restart`: 调用 `systemctl restart` 的便捷脚本。

## 安全说明

1. **敏感参数保护**: 所有网络名称、密钥、Peer 地址均存储在 `/persist` 分区，不进入 Nix Store。
2. **权限隔离**: 服务使用 `CAP_NET_ADMIN` 和 `CAP_NET_RAW` 能力，无需以完整 root 权限运行所有逻辑（取决于 `easytier-core` 的实现细节，当前配置为 systemd 默认用户，通常为 root 以创建 TUN 设备）。
3. **日志安全**: 启动脚本会打印组网名称，但不会打印组网密码。

## 后续集成

后续 Noctalia 插件将通过调用 `easytier-status` 来展示连接状态，并提供开关功能。插件本身不会保存或处理组网密钥。
