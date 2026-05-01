# 密钥管理 (Secrets with Sops)

本仓库使用 [sops-nix](https://github.com/Mic92/sops-nix) 管理加密密钥，确保敏感信息（如 API Key、服务器地址）不会以明文形式提交至 Git。

## 管理规范

- **入口**: `home/dot/secrets/default.nix` 为 Home Manager 的密钥管理入口。
- **私钥位置**: `age` 私钥应存放于 `~/.config/sops/age/keys.txt`。
- **加密文件**: 
  - 全局 Secret: `secrets.yaml`
  - 模块特定 Secret: 如 `secrets/noctalia.yaml`

## 已定义的 Secret 框架

| 密钥名称 | 对应功能 |
| :--- | :--- |
| `gemini_api_key` | Noctalia Assistant Panel 插件使用的 AI 密钥 |
| `vps/beacon` | 香港服务器远程地址 |
| `vps/conduit` | 节点服务器远程地址 |
| `vps/hopper` | 备份服务器远程地址 |
| `vps/target` | 远程构建服务器地址 |
| `vps/repeater` | 辅助服务器地址 |

## 安全禁令

- **禁止提交私钥**: 严禁将 `keys.txt` 或其内容通过 Git 提交。
- **禁止提交运行时缓存**: 如解密后的临时文件或应用生成的 Token 缓存。
- **诊断说明**: 若应用提示密钥缺失，请检查 `sops-nix` 服務是否正常。运行 `ls -l ~/.config/sops-nix/secrets` 查看密钥是否已解密并挂载。

## 仓库健康检查 (Repo Hygiene)

在提交代码前，建议运行以下脚本以确保没有误提交明文密钥或错误的持久化路径：

```bash
./scripts/check-repo-hygiene.sh
```

该脚本会自动审计：
- 是否存在明文私钥模式。
- 是否持久化了禁止的系统路径（如 `/etc/shadow`）。
- 是否有未加密的 SOPS 文件。
- 是否存在未被忽略的危险文件（如 `.env` 或 `keys.txt`）。

相关链接：
- [持久化存储](./impermanence.md)
- [Noctalia 视觉系统](./noctalia.md)
