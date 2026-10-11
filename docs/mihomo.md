# 本机 Mihomo 与 Noctalia 控制面

Warden 不再运行 FlClash。Mihomo 是受 NixOS 管理、默认不随开机拉起的本机核心；
Noctalia 通过独立项目 [`DotRedstone/noctalia-mihomo-control`](https://github.com/DotRedstone/noctalia-mihomo-control)
的固定版本 `v0.1.0` 控制其状态栏入口、生命周期、代理组选择、延迟测试、模式切换和
实时流量显示。

## 安全边界

- Mihomo 服务以 root 运行，以便未来由配置显式启用 TUN；当前迁移不会自动开启 TUN、
  修改默认路由或替代路由器透明代理。`mihomo.service` 没有开机目标依赖，只有 Noctalia
  面板通过受限 helper 才能启动、停止或重启它。Polkit 仅授权本机用户 `dot` 对该唯一
  单元执行这三个动作；它不能管理其他 systemd 单元，也不能启用、禁用或屏蔽 Mihomo。
- 控制器固定为 `127.0.0.1:9090`，不监听局域网，也不设置远程管理入口。
- 配置和 provider 缓存位于 `/var/lib/mihomo`，由 impermanence 持久化，权限为 root-only。
- `mihomo-profile-import` 只接受**未定义** `external-controller` 或 `secret` 的配置，避免
  悄悄覆盖一个已经审计过的控制面。

## 从旧 FlClash 导入

旧 profile 保留在 `~/.local/share/com.follow.clash/` 直到下一次根目录清理；导入不会
删除它。先确认系统配置已切换，再执行：

```bash
sudo mihomo-profile-import \
  ~/.local/share/com.follow.clash/profiles/310018826903228416.yaml
```

该命令原子写入 `/var/lib/mihomo/config.yaml`，替换已有配置前会保存
`/var/lib/mihomo/backups/config.<UTC 时间>.yaml`，随后重启 `mihomo.service`。失败时，
若存在上一份配置则立即恢复它并尝试重启服务。

## 日常操作

```bash
systemctl status mihomo
journalctl -u mihomo -f
sudo systemctl restart mihomo
```

Noctalia 启动后会自动安装并启用固定版本的 Mihomo Control；状态栏中 `mihomo` 小组件默认
放在 Udiskie 与系统托盘之间。面板默认关闭；左键打开后可启动或停止核心，启动完成后选择
代理组、做延迟测试或切换 `rule` / `global` / `direct`。插件只连接本机控制器，未开放远程
管理入口。

若未来导入的配置已经包含控制器或密钥，不要强行使用导入工具；先检查它是否仍然仅
监听 loopback，再在 Noctalia 插件设置中按需填入安全的控制器资料。
