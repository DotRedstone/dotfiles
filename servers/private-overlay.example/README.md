# 私有服务器部署 overlay 示例

本目录仅含 `example.test` 和合成 origin ID，不包含当前部署值。NixOS 的证书名称、
回源身份和虚拟主机名称在求值期进入系统闭包，运行期 SOPS 文件不能替代这些
Nix 选项。独立私有 Flake 通过公开的 `lib.mkConduit`、`lib.mkHopper` 构造器
追加少量主机专属值，通用服务实现仍由公开仓库维护。公开 Flake 不再输出这两台
可直接部署的系统配置，避免缺少私有输入时生成错误闭包。

## 评审与迁移顺序

1. 将本目录复制到不公开的独立 Git 仓库；只在该仓库填写两地主机的 origin
   身份和探测证书名称。固定已审查的公开服务器 Flake 修订并保存私有 lock。
   不在公开仓库或 PR 中提交真实 overlay、构建日志或解密文件。
2. 先用合成值验证接口；再在私有仓库比较 overlay 的有效 `originId`、
   `serverName`、Target TLS `domain` 与当前系统声明值是否一致。分别评估
   Conduit、Hopper、Target 的系统闭包，并核对 Nginx、ACME、探测及旧回源。
3. 在有定时回退保护的维护窗口逐机执行 `nixos-rebuild test`，实测 TLS、
   回源证明、SSH 和旧订阅；验收后再 `switch`。保留旧闭包和受限输入。
4. 公开主机模块已去除这些部署字面量，直接以公开 Flake 构建两地主机不再
   提供目标输出。实际私有 overlay 已用于 Conduit 临时测试并回退，尚未用于
   本轮持久切换；公开历史及远端缓存仍待单独处理。

合成原型可在 dotfiles worktree 中执行以下只求值检查；它不部署主机：

```bash
cd /path/to/dotfiles-worktree
nix flake check --no-build --no-write-lock-file \
  --override-input public "path:$PWD/servers" \
  path:./servers/private-overlay.example
```

本示例保持 Target TLS 探测关闭。私有 overlay 只提供未来启用时的名称，不启用
服务或修改当前 DNS/证书。
