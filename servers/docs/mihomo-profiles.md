# 统一 Mihomo 配置

路由器、桌面和 Android 均以同一份规则基线为准。生成后的配置包含私有订阅地址，
不提交到 Git；加密源位于 `servers/secrets/cloudflare.yaml`，由 Cloudflare KV 或路由器
活动配置提供给客户端。

## 节点结构

节点层只保留六个 provider：

- 洛杉矶：`Reality`、`WS 直连`、`WS + Cloudflare 优选`。
- 新加坡：`Reality`、`WS 直连`、`WS + Cloudflare 优选`。

每个区域有“直连自动/手动”和“优选自动/手动”四个选择组；`🇺🇸 洛杉矶` 与
`🇸🇬 新加坡` 汇总本地区四种选项，`🌐 Default` 默认选洛杉矶。ChatGPT、AI、开发、
流媒体、通讯、社交、Apple、Google、Microsoft、Cloudflare、Steam 和漏网流量等业务
规则组保持独立，均可选择默认、任一区域或直连。

## 两地优选池

CloudflareST 的“优选 IP”是用户到 Cloudflare 的入口，并不等于服务器所在地。为防止
把某次测得的 POP 名称误当成节点地区，路由器维护两份独立结果：

```text
CloudflareST --SNI la-cdn.bdot.in--> la pool --> 洛杉矶优选 provider
CloudflareST --SNI sg-cdn.bdot.in--> sg pool --> 新加坡优选 provider
```

两个测速 URL 均为私有 8 MiB、`Cache-Control: no-store` 的 Nginx 文件，因此测速会
经过相应的真实回源，而不是命中 Cloudflare 缓存。`edge-preferred-control` Worker 只
接收 HMAC 签名后的结果并存入 KV；它不承载代理传输，也不公开优选 IP 列表。

路由器上的 `/root/cfst/run_cfst.sh` 默认顺序跑完两个池；`--pool la` 或 `--pool sg`
可单独运行，`--upload-only` 仅重传上次成功结果。配置与签名密钥位于
`/root/cfst/edge.env`，权限为 `0600`。若测速或上传失败，脚本不会覆盖最后一份成功池。

## 更新和回滚

修改 Worker 或加密订阅源后，在仓库中运行：

```bash
cd /home/dot/.dotfiles/servers/cloudflare/edge-worker
npm run check
npm run deploy:dry-run
npm run deploy
```

修改路由器活动配置前必须创建备份。OpenClash 的活动配置与 provider 缓存由路由器管理；
不要通过 Mihomo Controller 覆盖整份配置。出现问题时，恢复对应
`/etc/openclash/backup/config.yaml.before-*` 备份并重启 OpenClash；优选池异常时直接在
选择组中切回本区直连自动或手动节点即可。
