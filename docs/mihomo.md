# 本机 Mihomo 与 Noctalia 控制面

Warden 不再运行 FlClash。Mihomo 是受 NixOS 管理、默认不随开机拉起的本机核心；
Noctalia 通过独立项目 [`DotRedstone/noctalia-mihomo-control`](https://github.com/DotRedstone/noctalia-mihomo-control)
的固定版本 `v0.1.0` 控制其状态栏入口、生命周期、代理组选择、延迟测试、模式切换和
实时流量显示。

系统模块另提供 `mihomo-profile-helper`，实现独立插件 v0.2 的配置管理协议。当前 Flake
仍固定在 v0.1.0，因此仅构建宿主 helper 不会在面板显示配置管理入口；发布并固定审核过的
v0.2 提交后，才在插件设置中填写 `command -v mihomo-profile-helper` 返回的绝对路径。

## 安全边界

- Mihomo 服务以 root 运行，以便未来由配置显式启用 TUN；当前迁移不会自动开启 TUN、
  修改默认路由或替代路由器透明代理。`mihomo.service` 没有开机目标依赖，只有 Noctalia
  面板通过受限 helper 才能启动、停止或重启它。Polkit 仅授权本机用户 `dot` 对该唯一
  单元执行这三个动作；它不能管理其他 systemd 单元，也不能启用、禁用或屏蔽 Mihomo。
- 控制器固定为 `127.0.0.1:9090`，不监听局域网，也不设置远程管理入口。
- 配置和 provider 缓存位于 `/var/lib/mihomo`，由 impermanence 持久化，权限为 root-only。
- `mihomo-profile-import` 只接受**未定义** `external-controller` 或 `secret` 的配置，避免
  悄悄覆盖一个已经审计过的控制面。
- `mihomo-profile-helper` 仅接受 `list`、`import <本地绝对路径>` 和
  `activate <ID>`；Polkit 只授权用户 `dot` 执行固定的 root helper。来源必须是
  `/home/dot/Downloads/` 下由 `dot` 拥有的普通文件，不能经过符号链接、硬链接或
  `..`，大小不超过 2 MiB，且不能由组或其他用户写入。其他路径、URL 和订阅下载不在
  该接口范围。导入的内容、provider URL 和令牌只保存在 root-only 的
  `/var/lib/mihomo`，不写入 Nix store、Git 或成功输出。
- 新导入配置必须有本机代理端口，不能自行设置 controller/secret、TUN、局域网监听、
  外部 UI 或任意顶层选项。helper 固定附加 `127.0.0.1:9090` 控制器。含这些功能的
  既有配置不会被新导入策略悄悄改写；如需迁移，应先单独审核配置。

## 配置库与切换

部署新的系统模块后，可先用 `mihomo-profile-helper list` 核对已有配置的元数据。首次
读取会把现有 `/var/lib/mihomo/config.yaml` 登记为 `legacy`，不会重启服务。插件 v0.2
启用后，面板导入只新增条目，不改变活动配置，也不启动或重启 Mihomo。切换选择后，
helper 将活动文件与选择 ID 持久写入；若服务正在运行，则重启并检查 loopback API 与
代理端口。失败时用私有备份恢复旧文件和选择，并尝试恢复服务；服务原本停止时保持停止。
中断后的下一次 helper 调用会优先处理未完成的事务。配置库最多 100 项，列表只返回
名称和不透明 ID。

旧的 `mihomo-profile-import` 继续作为手工恢复入口，保留原有备份与回退行为；它直接
替换当前配置并重启服务。随后调用新 helper 时，外部改动会登记为“手工恢复配置”，
使面板所示活动条目与文件一致。恢复前应保存旧配置和服务状态，并核查
`/var/lib/mihomo/backups/`；若切换及回退都失败，先检查 `mihomo.service` 与
`profile-transaction`，不要重复切换。

当前交付只验证源码、合成配置和系统 dry run。要使桌面功能生效，还需审核插件 v0.2
提交、发布固定版本、更新本 Flake 的 `noctalia-mihomo-control` 引用与锁文件，分别完成
NixOS 与 Home Manager 构建，然后按主机变更流程切换系统、切换 Home Manager 并重启
Noctalia。实际运行时的配置切换与流量需要单独验收。

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
