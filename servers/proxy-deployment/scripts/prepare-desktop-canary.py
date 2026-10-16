#!/usr/bin/env python3
"""将受限交付配置安装到独立 Mihomo 测试目录。"""

import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
SECRET = ROOT / "secrets/conduit.yaml"
DEFAULT_STATE = Path.home() / ".local/state/mihomo-v2-canary"


def load_runtime(profile):
    result = subprocess.run(
        ["sops", "-d", "--extract", '["proxy"]["delivery_runtime"]', str(SECRET)],
        capture_output=True, check=False,
    )
    if result.returncode:
        raise ValueError("无法解密交付运行时")
    try:
        runtime = json.loads(result.stdout)
        accounts = runtime["runtimeByAccount"]
        if len(accounts) != 1:
            raise ValueError("canary 账户数量不符")
        account = next(iter(accounts.values()))
        origin = account["deliveryBaseUrl"].rstrip("/")
        token = account["deliveryToken"]
        if not origin.startswith("https://") or not token:
            raise ValueError("交付入口无效")
        return f"{origin}/u/{token}/{profile}/mihomo.yaml"
    except (KeyError, TypeError, json.JSONDecodeError):
        raise ValueError("交付运行时结构无效") from None


def fetch(url):
    try:
        with urlopen(Request(url, headers={"Accept": "application/yaml", "User-Agent": "curl/8.22.0"}), timeout=20) as response:
            if response.status != 200:
                raise ValueError("交付接口未返回 200")
            content = response.read(2 * 1024 * 1024 + 1)
            if len(content) > 2 * 1024 * 1024:
                raise ValueError("配置超过大小上限")
            return json.loads(content)
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
        raise ValueError("交付配置读取失败") from None


def isolated(profile, kind):
    if not isinstance(profile, dict) or not isinstance(profile.get("proxy-providers"), dict):
        raise ValueError("交付配置缺少 provider")
    if set(profile["proxy-providers"]) != {"la-cf", "sg-cf"}:
        raise ValueError("provider 名称不符")
    profile.update({
        "mixed-port": 17890 if kind == "desktop" else 17891,
        "allow-lan": False,
        "external-controller": "127.0.0.1:19090" if kind == "desktop" else "127.0.0.1:19091",
        "geodata-mode": True,
    })
    profile.pop("port", None)
    profile.pop("socks-port", None)
    profile.pop("redir-port", None)
    profile.pop("tproxy-port", None)
    profile.pop("secret", None)
    profile.pop("external-ui", None)
    profile["tun"] = {"enable": False}
    profile["dns"] = {"enable": False}
    for provider in profile["proxy-providers"].values():
        if provider.get("type") != "http" or provider.get("interval", 0) > 300:
            raise ValueError("provider 更新设置无效")
        if not provider.get("url", "").startswith("https://"):
            raise ValueError("provider 入口不是 HTTPS")
    return profile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("desktop", "router"), default="desktop")
    parser.add_argument("--state", type=Path)
    args = parser.parse_args()
    state = (args.state or DEFAULT_STATE.with_name(DEFAULT_STATE.name + ("-router" if args.profile == "router" else ""))).expanduser().resolve()
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(state, 0o700)
    for geodata in ("GeoIP.dat", "GeoSite.dat"):
        source = Path.home() / ".config/mihomo" / geodata
        destination = state / geodata
        if not destination.exists() and source.is_file():
            shutil.copyfile(source, destination)
            os.chmod(destination, 0o600)
    profile = isolated(fetch(load_runtime(args.profile)), args.profile)
    check_profile = copy.deepcopy(profile)
    provider_files = []
    temporary = None
    try:
        for name, provider in check_profile["proxy-providers"].items():
            document = fetch(provider["url"])
            if not isinstance(document.get("proxies"), list) or not document["proxies"]:
                raise ValueError("provider 内容无效")
            provider_file = state / f"{name}.check.yaml"
            provider_files.append(provider_file)
            provider_file.write_text(json.dumps(document, ensure_ascii=False) + "\n")
            os.chmod(provider_file, 0o600)
            check_profile["proxy-providers"][name] = {"type": "file", "path": str(provider_file)}
        with tempfile.NamedTemporaryFile(mode="w", dir=state, prefix="config.", delete=False) as stream:
            temporary = Path(stream.name)
            os.chmod(temporary, 0o600)
            json.dump(check_profile, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        check = subprocess.run(["mihomo", "-t", "-d", str(state), "-f", str(temporary)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
                               timeout=30)
        if check.returncode:
            raise ValueError("Mihomo 静态检查失败")
        temporary.write_text(json.dumps(profile, ensure_ascii=False, indent=2) + "\n")
        os.chmod(temporary, 0o600)
        temporary.replace(state / "config.yaml")
    except subprocess.TimeoutExpired:
        raise ValueError("Mihomo 静态检查超时") from None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        for provider_file in provider_files:
            provider_file.unlink(missing_ok=True)
    print(f"{args.profile} canary 配置已更新，Mihomo 静态检查通过")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Warden canary 准备失败：{error}", file=sys.stderr)
        sys.exit(1)
