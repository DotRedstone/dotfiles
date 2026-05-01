# 密钥管理 (Secrets with Sops)

本仓库使用 [sops-nix](https://github.com/Mic92/sops-nix) 作为 Secret 管理的统一入口。

## 管理原则

- **入口**: 统一由 `home/dot/secrets/` 模块管理。
- **存储位置**: 
  - 私钥 (`age key`) 存放于 `~/.config/sops/age/keys.txt`。
  - 加密后的数据存放于 `secrets/secrets.yaml`。
- **三不原则**:
  - 不提交私钥或明文 Token。
  - 不提交生成后的运行时缓存。
  - 不将非敏感的配置项（如普通的 App 设置）放入 Sops。

## 当前配置

目前仓库仅保留了 Sops 的框架与入口定义，具体的业务 Secret（如 Gemini API Key）在各自模块中通过 Sops 变量引用。如果遇到 Secret 缺失，请确本地 `keys.txt` 包含正确的解密密钥。
