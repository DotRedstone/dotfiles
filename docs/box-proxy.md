# 用户级 Mihomo 代理与独立 Chrome

模块位于 `home/dot/box-proxy/`，由 Home Manager 用户级 switchboard 引入。默认关闭，不启用主机级服务，也不会安装 Chrome。

## 启用

在目标 Home Manager 用户配置中显式设置：

```nix
programs.box-proxy = {
  enable = true;
  chrome = {
    enable = true;
    executable = "google-chrome";
    timeZone = "America/Los_Angeles";
    lang = "en-US";
  };
};
```

仅使用代理命令时只需启用父级 `enable`。Chrome 启动器要求父级同时启用。

## 使用

订阅地址只在刷新时通过环境变量提供：

```bash
export BOX_PROXY_SUBSCRIPTION_URL='在本机安全地设置订阅链接'
box-proxy refresh
unset BOX_PROXY_SUBSCRIPTION_URL
box-proxy on
box-proxy status
box-proxy run curl https://example.com
box-chrome
box-proxy off
```

`BOX_PROXY_MIHOMO` 可临时覆盖打包的 Mihomo 可执行文件。支持 `on|off|status|refresh|run <cmd...>`。

## 网络与数据边界

- Mihomo 仅监听 `127.0.0.1:7890`；刷新时设置 `bind-address`、`mixed-port`、`allow-lan = false`，并显式关闭 `tun.enable`，不开 TUN。
- 不设置全局代理环境变量；仅 `box-proxy run` 的子进程接收临时代理变量。
- 订阅链接仅由 `refresh` 读取，经 curl 标准输入传递，不写入文件或日志，也不进入 Nix store。下载内容和生成配置属于运行时数据。
- 运行时目录为 `~/.local/state/box-proxy`，目录权限 `0700`，文件权限 `0600`。
- `box-chrome` 使用独立的 `~/.local/state/box-chrome` profile，并仅为该实例指定本机代理，不影响其他 Chrome 实例。
- `TZ` 设置启动进程时区，`LANG` 设置系统语言环境，`--lang` 设置 Chrome 界面语言；`--force-webrtc-ip-handling-policy=disable_non_proxied_udp` 禁止 WebRTC 使用绕过代理的 UDP。
- 预期出口应与路由器默认出口（洛杉矶）一致。模块不修改路由器或替用户选择节点，需确认 Mihomo 策略实际选出的出口符合此目标。
