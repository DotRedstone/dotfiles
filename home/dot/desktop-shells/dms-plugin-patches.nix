# ---
# Module: DMS Plugin Patches
# Description: 对第三方 DMS 插件做幂等的本地修复，避免插件更新后回归
# Scope: Home Manager
# ---
# Notes:
# - 插件目录 ~/.config/dms/plugins/ 由 DMS 自行维护（来自插件仓库的 git 副本），
#   因此这里用 activation 脚本就地改写文件，而不是 home.file 软链：
#   软链会让插件更新写入目标时踩到只读的 nix store。
# - 脚本按行定位、对语法变体宽容（上游与本地版本在 `panelByName &&` 空值保护上不同），
#   已打补丁则跳过；结构变化导致定位失败时只告警、不改文件。
# - 上游对应 PR: https://github.com/Dadangdut33/dms-plugins/pull/14
#   一旦该 PR 合并并发布新版本，本模块即可删除。

{ pkgs, lib, ... }:

let
  patchClipboardPlus = pkgs.writeShellScriptBin "dms-plugin-patch" ''
    set -eu

    file="''${DMS_CLIPBOARD_QML:-$HOME/.config/dms/plugins/clipboardPlus/ClipboardPlusWidget.qml}"

    if [ ! -f "$file" ]; then
      echo "dms-plugin-patch: $file 不存在，跳过" >&2
      exit 0
    fi

    if ${pkgs.gnugrep}/bin/grep -q 'panelKey' "$file"; then
      exit 0
    fi

    ${pkgs.python3}/bin/python3 - "$file" <<'PY'
import re
import sys

path = sys.argv[1]
src_all = open(path).read()
if "panelKey" in src_all:
    sys.exit(0)

lines = src_all.splitlines(keepends=True)
original = "".join(lines)
changed = False


def indent_of(line):
    return re.match(r"\s*", line).group(0)


def patch_map(map_name, window_name, key_prop):
    global changed
    assign = f"{map_name}[key] = {window_name};"
    for i, line in enumerate(lines):
        if "Component.onCompleted:" not in line:
            continue
        if assign not in "".join(lines[i:i + 6]):
            continue
        pad = indent_of(line)
        lines[i:i] = [
            f'{pad}readonly property string {key_prop}: screen?.name || "default"\n',
            "\n",
        ]
        for j in range(i, min(i + 10, len(lines))):
            if assign in lines[j]:
                lines[j] = lines[j].replace(f"{map_name}[key]", f"{map_name}[{key_prop}]")
                changed = True
                break
        break

    for i, line in enumerate(lines):
        if "Component.onDestruction:" not in line:
            continue
        if f"{map_name}[key] === {window_name}" not in "".join(lines[i:i + 8]):
            continue
        for j in range(i, min(i + 8, len(lines))):
            cur = lines[j]
            if re.match(r'\s*const key = screen\?\.name \|\| "default";\s*$', cur):
                lines[j] = ""
                changed = True
            elif f"{map_name}[key]" in cur:
                lines[j] = cur.replace(f"{map_name}[key]", f"{map_name}[{key_prop}]")
                changed = True
            elif "delete copy[key];" in cur:
                lines[j] = cur.replace("delete copy[key];", f"delete copy[{key_prop}];")
                changed = True
        break


patch_map("panelByName", "panelWindow", "panelKey")
patch_map("emojiPopupByName", "emojiPopupWindow", "emojiPanelKey")

text = "".join(lines)
for map_name in ("panelByName", "emojiPopupByName"):
    pattern = re.compile(
        r"( *)if \(name !== key && " + map_name + r"\[name\]\) \{\s*\n"
        r"( *)" + map_name + r"\[name\]\.setOpen\(false\);\s*\n"
        r"( *)\}",
    )

    def repl(match, map_name=map_name):
        pad, inner = match.group(1), match.group(2)
        return (
            f"{inner}const other = {map_name}[name];\n"
            f"{pad}if (name !== key && other && typeof other.setOpen === \"function\")\n"
            f"{inner}other.setOpen(false);\n"
            f"{pad}}}"
        )

    text, hits = pattern.subn(repl, text, count=1)
    if hits:
        changed = True
lines = text.splitlines(keepends=True)

if not changed or "".join(lines) == original:
    print("dms-plugin-patch: ClipboardPlus 结构已变化，补丁未能定位，请人工复核", file=sys.stderr)
    sys.exit(0)

open(path, "w").write("".join(lines))
print("dms-plugin-patch: 已修复 ClipboardPlus 面板残留引用")
PY
  '';

  # [ScreenshotPlus] Avoid clipboard.copyFile pointing to temp PNG deleted after 10s
  patchScreenshotPlus = pkgs.writeShellScriptBin "dms-screenshot-plus-patch" ''
    set -eu
    unset PYTHONHOME PYTHONPATH

    file="''${DMS_SCREENSHOT_PLUS_QML:-$HOME/.config/dms/plugins/screenshotPlus/ScreenshotPlusDaemon.qml}"
    if [ ! -f "$file" ]; then
      exit 0
    fi

    ${pkgs.python3}/bin/python3 - "$file" <<'PY'
import pathlib, sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """            if (copy) {
                DMSService.sendRequest("clipboard.copyFile", { "filePath": png }, resp => {
                    if (resp && resp.error)
                        console.warn("screenshotPlus: clipboard:", resp.error)
                })
            }"""
new = """            if (copy) {
                Quickshell.execDetached(["sh", "-c", 'dms cl copy -t image/png < "$1"', "sh", png])
            }"""
if new in text:
    sys.exit(0)
if old not in text:
    print("dms-screenshot-plus-patch: ScreenshotPlusDaemon.qml 结构已变化，跳过", file=sys.stderr)
    sys.exit(0)
path.write_text(text.replace(old, new, 1), encoding="utf-8")
print("dms-screenshot-plus-patch: 已改用纯 image/png 写入剪贴板，避免临时文件被删后粘贴失败")
PY
  '';
in {
  home.packages = [ patchClipboardPlus patchScreenshotPlus ];

  home.activation.dmsPluginPatches = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${patchClipboardPlus}/bin/dms-plugin-patch || true
    run ${patchScreenshotPlus}/bin/dms-screenshot-plus-patch || true
  '';
}
