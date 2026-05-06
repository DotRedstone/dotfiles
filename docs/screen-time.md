# 屏幕时间管理

本模块实现一个基于 ActivityWatch / awatcher 与 Noctalia 插件的屏幕时间管理 MVP。当前版本只做本地采集、聚合展示和状态提示，不实现强制锁屏、杀进程、封应用，也不采集或展示窗口标题、网页标题、URL、文件名或完整事件时间线。

## 当前实现

已采用 `awatcher` 作为 Niri / Wayland 下的 ActivityWatch watcher。

验证闸门结果：

- `pkgs.activitywatch`：可用。
- `pkgs.awatcher`：可用，采用。
- `pkgs.aw-watcher-window-wayland`：可用，保留为后备方案。
- 临时 `aw-server --host 127.0.0.1 --port 5600` + `awatcher` 能生成：
  - `aw-watcher-window_warden`
  - `aw-watcher-afk_warden`

只查询过 bucket 名称；没有打印原始事件、窗口标题或 URL。

## 架构

```text
Niri / Wayland session
  -> awatcher
  -> ActivityWatch server (127.0.0.1:5600)
     - aw-watcher-window_<hostname>
     - aw-watcher-afk_<hostname>
  -> screen-time-json
  -> ~/.cache/noctalia/screen-time/summary.json
  -> Noctalia screen-time plugin
```

职责边界：

- ActivityWatch server 负责本地存储和 API。
- awatcher 负责窗口活动和 AFK watcher，不从零写采集器。
- `screen-time-json` 是短命聚合 helper，运行后退出。
- Noctalia 插件只展示摘要、刷新状态和设置，不长期采集窗口事件。

## 文件位置

Home Manager 服务：

- `home/dot/activitywatch/default.nix`

Noctalia helper：

- `home/dot/noctalia/scripts/screen-time-json`
- `home/dot/noctalia/scripts.nix`

Noctalia 插件：

- `home/dot/noctalia/config/plugins/screen-time/manifest.json`
- `home/dot/noctalia/config/plugins/screen-time/Main.qml`
- `home/dot/noctalia/config/plugins/screen-time/BarWidget.qml`
- `home/dot/noctalia/config/plugins/screen-time/Panel.qml`
- `home/dot/noctalia/config/plugins/screen-time/Settings.qml`
- `home/dot/noctalia/config/plugins/screen-time/i18n/zh-CN.json`
- `home/dot/noctalia/config/plugins/screen-time/i18n/en.json`

Noctalia 配置入口：

- `home/dot/noctalia/config/plugins.json`
- `home/dot/noctalia/config/settings.json`

Home Manager 入口：

- `home/dot/default.nix`

## systemd 用户服务

新增 user services：

- `activitywatch-server.service`
- `awatcher.service`

服务策略：

- `activitywatch-server.service` 执行 `aw-server --host 127.0.0.1 --port 5600 --no-legacy-import`。
- `awatcher.service` 执行 `awatcher --host 127.0.0.1 --port 5600 --idle-timeout 180`。
- `awatcher.service` `Wants` 并 `After` `activitywatch-server.service`。
- 两个服务都 `WantedBy=graphical-session.target`。
- 两个服务都使用 `Restart=on-failure` 和 `RestartSec=10s`，避免快速无限重启。
- 不启用 browser watcher。
- 不开放局域网访问。
- 不加入 persistence。

启用后检查：

```bash
systemctl --user status activitywatch-server awatcher --no-pager
curl -s http://127.0.0.1:5600/api/0/buckets/ | jq 'keys'
```

注意：只建议查看 bucket 名称，不要把原始 events 输出到终端或提交到仓库。

## screen-time-json

helper 输出并缓存同一份安全摘要 JSON：

```text
~/.cache/noctalia/screen-time/summary.json
```

字段：

```json
{
  "ok": true,
  "source": "activitywatch",
  "watcher": "awatcher",
  "fetchedAt": "2026-05-06T00:00:00+08:00",
  "range": {
    "start": "2026-05-06T00:00:00+08:00",
    "end": "2026-05-07T00:00:00+08:00"
  },
  "todayTotalSeconds": 0,
  "weekTotalSeconds": 0,
  "monthTotalSeconds": 0,
  "afkSeconds": 0,
  "weekAfkSeconds": 0,
  "monthAfkSeconds": 0,
  "dailyTotals": [
    { "date": "2026-05-06", "label": "6", "seconds": 0 }
  ],
  "currentApp": "",
  "topApps": [
    { "app": "example", "seconds": 0 }
  ],
  "weekTopApps": [
    { "app": "example", "seconds": 0 }
  ],
  "monthTopApps": [
    { "app": "example", "seconds": 0 }
  ]
}
```

安全约束：

- `currentApp` 只允许 app id/app name。
- `topApps` 只包含 `app` 和 `seconds`。
- `dailyTotals` 只包含日期标签和聚合秒数，不包含窗口事件。
- `weekTopApps` / `monthTopApps` 仍只包含 app 级聚合摘要。
- 不输出 `title`、`url`、`windowTitle`、`fileName` 或 raw events。
- 失败时输出泛化错误 JSON，不打印 ActivityWatch 原始响应。

验证：

```bash
screen-time-json | jq .
cat ~/.cache/noctalia/screen-time/summary.json | jq .
```

安全验证示例：

```bash
screen-time-json | jq '[paths | map(tostring) | join(".") | select(test("title|url|windowTitle|fileName"; "i"))] | length'
```

期望输出为 `0`。

## Noctalia 插件

插件 ID：

```text
screen-time
```

入口：

- `Main.qml`：调用 `screen-time-json`，读取 cache，维护状态。
- `BarWidget.qml`：显示今日总时长或当前应用。
- `Panel.qml`：显示今日总时长、本周/本月统计、近 7 天柱状趋势、当前应用、Top 应用、AFK 时间、最后更新时间、ActivityWatch 连接状态。
- `Settings.qml`：设置刷新间隔、Top 应用数量、是否显示当前应用、Bar 显示模式。

显示限制：

- 只展示应用级摘要。
- 不展示窗口标题、网页标题、URL、文件名、完整时间线。
- 使用 Noctalia / MD3 语义 token，不修改全局透明度或主题。

## 持久化策略

当前不把 ActivityWatch 加入 `modules/system/persistence/user-apps.nix`。

后续如需长期保留历史，再单独评审这些候选路径：

- `~/.local/share/activitywatch/`
- `~/.config/activitywatch/`
- `~/.config/awatcher/`

不建议持久化：

- `~/.cache/noctalia/screen-time/`
- ActivityWatch export JSON
- 测试 fixture 中的真实使用数据

## 隐私风险

高风险数据：

- ActivityWatch 原始事件可还原完整使用时间线。
- 窗口标题可能包含聊天对象、文件名、网页标题、工单标题或密钥片段。
- Browser watcher 会引入 URL / 标签页标题，当前不启用。
- helper cache 虽然只保留摘要，也不应提交。

缓解：

- helper 只输出 app 级摘要。
- Noctalia QML 解析失败时只显示泛化错误。
- ActivityWatch server 只监听 `127.0.0.1`。
- 不加入 persistence，长期保留另行评审。
- `git status --short` 中不应出现 ActivityWatch 数据库、cache、summary、token、session。

## 路线图

第一阶段：MVP 展示

- ActivityWatch server + awatcher user service。
- `screen-time-json` 聚合摘要。
- Noctalia Bar / Panel / Settings 插件。
- 只展示今日总屏幕时间、本周/月聚合、近 7 天趋势、当前应用、Top 应用、AFK 时间、数据源状态。

第二阶段：温和提醒

- 增加每日总时长和单应用连续使用阈值。
- 只通过 Noctalia toast / panel 提醒。
- 支持稍后提醒、今日静音、打开 ActivityWatch UI。
- 不做锁屏、杀进程或封应用。

第三阶段：复盘分析

- 增加周视图和趋势摘要。
- 支持软预算和分类规则。
- 评估是否持久化 ActivityWatch 数据，并单独修改 persistence 模块。

## 上游参考

- ActivityWatch Watchers: https://docs.activitywatch.net/en/latest/watchers.html
- ActivityWatch REST API: https://docs.activitywatch.net/en/latest/api/rest.html
- ActivityWatch data examples: https://docs.activitywatch.net/en/latest/examples/working-with-data.html
- awatcher: https://github.com/2e3s/awatcher
- aw-watcher-window-wayland: https://github.com/ActivityWatch/aw-watcher-window-wayland
- Niri integration / autostart: https://github.com/niri-wm/niri/wiki/Integrating-niri
