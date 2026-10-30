# beacon 状态卡

`beacon` 是 Apple Silicon Mac mini，运行原生 macOS；仓库根目录
[`hosts/beacon`](../../hosts/beacon/README.md) 已包含独立的 nix-darwin / Home Manager
配置，以及无头、Minecraft 与 AI 服务的声明。

它**不属于** `servers/flake.nix` 管理的 NixOS 云服务器，也不应在此处重复创建
`servers/hosts/beacon`。本次仅对齐仓库源码状态；SSH 可达性、实际部署结果与运行状态
尚未重新验证。
