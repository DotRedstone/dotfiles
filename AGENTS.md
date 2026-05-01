# Dotfiles Agent Guide

## Repository Purpose

This repository manages the user’s personal NixOS system and Home Manager configuration for host `warden` and user `dot`. For human-readable documentation, see [README.md](./README.md).

Principles:

* Keep changes reversible.
* Keep modules small and single-purpose.
* Do not sacrifice the global desktop experience to fix one application.
* Prefer local, app-specific workarounds over global hacks.
* Keep the Noctalia visual system consistent.

## Common Commands

```bash
home-manager build --flake .#dot@warden
home-manager switch --flake .#dot@warden
sudo nixos-rebuild dry-run --flake .#warden
sudo nixos-rebuild switch --flake .#warden
nix flake check .
```

Validation Rules:

* Home Manager changes should be validated with `home-manager build` or `home-manager switch`.
* System module changes should be validated with `nixos-rebuild dry-run` or `nixos-rebuild switch`.
* Do not use `sudo nixos-rebuild switch` for Home Manager-only changes.
* Do not claim full validation if only one side was tested.

## Nix Module Header Format

All `.nix` modules should start with:

```nix
# ---
# Module: <Human-readable module name>
# Description: <one sentence responsibility>
# Scope: <System | Home Manager | Host | Theme | Script | Flake>
# ---
```

Optional:

```nix
# Notes:
# - <maintenance warning>
# - <do not modify X here>
```

Rules:

* `Description` must describe a single responsibility.
* Avoid vague descriptions like “configuration”.
* `default.nix` files should use `Entry` or `Switchboard` in the `Module` field.
* High-risk modules should include `Notes`.

## Repository Boundaries

Notes:

* `flake.nix`: flake entry point.
* `hosts/warden/`: host-specific hardware, mounts, identity, swap.
* `modules/system/`: NixOS system-level modules.
* `home/dot/`: Home Manager user-level modules.
* `home/dot/fcitx5/`: Fcitx5, Rime, and input-method theme integration.
* `home/dot/noctalia/`: Noctalia shell config and user templates.
* `home/dot/wechat/`: WeChat package and notification bridge.
* `scripts/`: manual diagnostics and helper scripts.

Rules:

* Change one behavior in one module.
* Do not put app-specific workarounds into global desktop config.
* Do not mix refactors with behavior changes.

## Fcitx5 and Rime Rules

Notes:

* Fcitx5 and Rime config are atomized.
* Rime patches live under `home/dot/fcitx5/rime/patches/`.
* Candidate key changes should only touch `keybindings.nix`.
* CapsLock / Shift behavior should only touch `ascii-composer.nix`.
* Lua processor changes should only touch the Rime Lua modules or `lua-processors.nix`.
* Theme changes should only touch `theme.nix`, custom themes, or Noctalia templates.

Important:

* WeChat UOS uses the XWayland / fcitx4 compatibility path.
* Transparent rounded candidate backgrounds can render as black corners there.
* Inflex sync themes are the XWayland-safe rectangular fallback.
* Do not reintroduce transparent rounded corners into XWayland-safe themes.

## Noctalia Theme Rules

Notes:

* Noctalia user templates are used for dynamic palette sync.
* Prefer Noctalia color tokens over hardcoded hex colors.
* Use MD3 semantic tokens:

  * `surface`
  * `on_surface`
  * `surface_variant` / `outline`
  * `primary`
  * `on_primary`
* Do not commit generated cache files.
* Do not make `~/.local/share/fcitx5/themes` a read-only `symlinkJoin` again if Noctalia needs to generate themes there.

## Persistence / Impermanence Rules

High-risk rules:

* Do not persist `/etc/shadow`, `/etc/passwd`, `/etc/group`, or `/etc/gshadow`.
* Password hashes should live in `/persist/secrets/*.passwd`.
* Do not casually change Btrfs subvolume mount options.
* `/persist` must remain writable.
* Avoid duplicating persistence for paths already mounted as subvolumes.

## WeChat Rules

Notes:

* The WeChat notification bridge is fragile and security-sensitive.
* Do not print SQLCipher keys.
* Do not commit runtime key caches.
* Do not read or expose private message database contents.
* Do not fix WeChat by lowering global opacity or degrading the global theme.

## QQ Rules

Notes:

* Linux QQ already emits native `org.freedesktop.Notifications.Notify`.
* Do not build a QQ database bridge unless explicitly requested.
* Prefer native notification / portal diagnostics first.

## Commit Style

Use Conventional Commits:

```text
feat(scope): ...
fix(scope): ...
refactor(scope): ...
style(scope): ...
docs(scope): ...
chore(scope): ...
```

Recommended scopes:

* `fcitx5`
* `rime`
* `noctalia`
* `wechat`
* `qq`
* `persistence`
* `i18n`
* `niri`
* `theme`
* `system`
* `home`
* `repo`

Rules:

* One commit should do one type of change.
* Do not mix refactors and behavior changes.
* Mention validation commands and results before committing.
* **Commit messages must use Chinese descriptions.**
    * Keep type and scope in English (e.g., `fix(wechat):`).
    * The description after the colon must be in Chinese.

Examples:

```text
refactor(fcitx5): 原子化 Rime 配置
fix(wechat): 缓存所有 SQLCipher 密钥候选
docs(repo): 添加 agent 协作规范
```

## Safety Rules

Notes:

* Do not update lock files unless dependency updates are intended.
* Do not commit secrets, tokens, private keys, or generated runtime cache.
* Do not edit persisted user data under `/persist` from repository code.
* Do not remove user customizations just because they look unusual.
* Ask before destructive changes.
* Safe diagnostics do not need confirmation.

## Agent Output Requirements

After every task, agents should report:

* changed files
* whether behavior changed
* validation commands run
* risks and rollback notes
* whether the user needs to run Home Manager, NixOS rebuild, reboot, or restart services
