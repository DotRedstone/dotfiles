// ---
// Script: Claude Desktop Linux Auth Patch
// Description: 让 Linux 版登录回退到系统浏览器并可靠接收 claude:// 回调
// Scope: Script
// ---
//
// Notes:
// - 目标是上游 0.14.10 的压缩 .vite/build/index.js；任一锚点缺失时构建失败，
//   以免升级后静默失效。
// - Linux 上 claude-native 为 patchy-cnb 桩模块，没有 AuthRequest。这里不模拟
//   macOS ASWebAuth，而是走上游已有的分支：shell.openExternal 打开系统浏览器，
//   登录完成后由浏览器经 xdg-desktop-portal 唤起 claude://login/...，
//   second-instance 将其转交给主实例处理。

const fs = require("fs");

const targetFile = process.argv[2];
if (!targetFile) {
  console.error("Usage: node patch-auth.js <path-to-index.js>");
  process.exit(1);
}

let code = fs.readFileSync(targetFile, "utf8");

function replaceOnce(from, to, label) {
  const count = code.split(from).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected 1 match, found ${count}`);
  }
  code = code.replace(from, () => to);
}

// 1. 桩模块缺少 AuthRequest 时，原判断会抛出 TypeError；改为回退到系统浏览器分支。
replaceOnce(
  "if(a&&a.AuthRequest.isAvailable()&&t&&fae(i))",
  "if(a&&a.AuthRequest&&a.AuthRequest.isAvailable()&&t&&fae(i))",
  "doAuthInBrowser guard",
);

// 2. second-instance 默认取 argv 最后一项；显式查找 claude:// 或扩展文件参数，
//    避免 Chromium/包装脚本附加的参数排在 URL 之后。
replaceOnce(
  "const i=r.pop();i&&oT(i)",
  'const i=r.find(x=>typeof x==="string"&&x.startsWith(jg))||r.find(x=>typeof x==="string"&&(x.endsWith(".dxt")||x.endsWith(".mcpb")))||r.pop();i&&oT(i)',
  "second-instance argv",
);

// 3. 将 deep link 日志从 silly 提升为 info，便于在 main.log 中确认回调是否送达。
replaceOnce(
  'ie.silly("claudeURLHandler handling",t);',
  'ie.info("claudeURLHandler handling %o",t);',
  "claudeURLHandler log",
);

// 4. 上游只接受 claude://login/google-auth；网页端回调路径可能不同，
//    因此接受 login 下任意带 code 的路径。
replaceOnce(
  'case Nv.Login:{switch(r.pathname){case Rq.GoogleAuth:{const i=r.searchParams.get("code");i&&e.webContents.send(_A.googleAuthCode,{code:i});return}}return}',
  'case Nv.Login:{const i=r.searchParams.get("code");i?e.webContents.send(_A.googleAuthCode,{code:i}):ie.warn("claudeURLHandler: login link without code %o",r.pathname);return}',
  "login deep link",
);

new Function(code);
fs.writeFileSync(targetFile, code, "utf8");
console.log("Patched " + targetFile);
