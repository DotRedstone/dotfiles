# 服务器主机组装层

每个 `hosts/<name>/` 目录只做三件事：导入硬件 / 平台和服务域、声明主机身份、连接
该主机的 SOPS 密文。可复用逻辑不得复制到多个主机目录。

## 目录约定

| 位置 | 职责 |
| --- | --- |
| `default.nix` | 主机 switchboard、hostname、SOPS 入口、stateVersion |
| `disko.nix` / `hardware-configuration.nix` | 安装与硬件特定事实 |
| `networking.nix` / `*-platform.nix` | 云厂商或网络接口特定配置 |
| `infra/` | 监控、备份、Nginx、EasyTier 等主机实例化 |
| `proxy/` | 该主机启用的代理入口和订阅组合 |
| 业务域目录 | 例如 `jupyter/`、`storage/`、`media/`、`hermes/` |

## 已受管主机

- `conduit`：洛杉矶边缘节点；仅承载声明式代理与基础设施。
- `hopper`：Oracle ARM 应用节点；业务按域拆分，原生服务优先。
- `gcp-free`：GCE 免费层代理节点；地址恢复或退役决定见 inventory。
- `target`：国内 EasyTier / 反代 / 游戏转发节点。

`repeater` 和其他尚未完整收编的机器不能直接照抄进本目录；先满足
`../inventory/README.md` 中的收编条件。
