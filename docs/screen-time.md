# 屏幕时间数据

本仓库已声明 ActivityWatch 本地服务和 `awatcher`，并提供
`screen-time-json` 聚合脚本。当前仓库没有屏幕时间的 Noctalia 插件界面；
数据采集与摘要生成不等于面板已接入。

## 已实现的链路

```text
Niri / Wayland
  → awatcher
  → ActivityWatch server（127.0.0.1:5600）
  → screen-time-json
  → ~/.cache/noctalia/screen-time/summary.json
```

- [ActivityWatch 模块](../home/dot/activitywatch/default.nix)声明
  `activitywatch-server.service` 和 `awatcher.service`，由
  `graphical-session.target` 启动。服务只监听本机回环地址，不启用浏览器
  watcher。
- [聚合脚本](../home/dot/noctalia/scripts/screen-time-json)由
  [脚本模块](../home/dot/noctalia/scripts.nix)包装为 `screen-time-json` 命令。
  它按日、周、月查询窗口与 AFK 事件，输出应用级时长、趋势和比较结果，
  并原子更新缓存。可使用 `--mode day|week|month`、
  `--range calendar|rolling` 和 `--top <数量>` 选择摘要范围。
- 原始 ActivityWatch 事件仍保存在服务的数据目录。摘要文件是运行时缓存，
  不属于声明式配置。

## 验证边界

检查服务状态和 bucket 名称：

```bash
systemctl --user status activitywatch-server awatcher --no-pager
curl -fsS http://127.0.0.1:5600/api/0/buckets/ | jq 'keys'
```

检查聚合脚本的结构与状态时，避免输出可能包含应用名称的完整摘要：

```bash
screen-time-json | jq '{ok, mode, range, source, watcher, error}'
```

以上检查分别验证服务、数据源和脚本结果；不能据此声称 Noctalia
界面已显示数据。

## 隐私与持久化

- 不打印、提交或复制 ActivityWatch 原始事件、窗口标题、网页地址和缓存。
- 聚合脚本仅输出应用级名称与时长，不输出窗口标题或完整事件时间线。
- 当前未将 ActivityWatch 数据目录加入
  [持久化模块](../modules/system/persistence/user-apps.nix)。若需要长期保留
  历史数据，应先单独评审数据范围、访问权限与恢复方式。

## 后续界面

若需要 Noctalia 面板，应按当前 Noctalia 插件 API 单独实现和验证，
并在接入后更新本文的实现状态。当前插件结构见
[Noctalia 本地插件维护](./noctalia-plugin-ui.md)。
