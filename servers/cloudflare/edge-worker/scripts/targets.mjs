// 部署参数按账号隔离；legacy 是默认目标，迁移期间不得删除。
export const targets = {
  legacy: {
    accountKey: "proxy",
    publicHost: "edge-next.dotdot.ggff.net",
    preferredControlHost: null,
    workerName: "edge-proxy-next-recovery",
    preferredControlWorkerName: "edge-preferred-control",
    namespaceTitle: "edge-proxy-next-state",
  },
  bdot: {
    // 仅为 SOPS 键名占位，执行部署前必须由维护者确认。
    accountKey: "qq",
    publicHost: "edge-next.bdot.in",
    preferredControlHost: "preferred-control.bdot.in",
    workerName: "edge-proxy-next-recovery",
    preferredControlWorkerName: "edge-preferred-control",
    namespaceTitle: "edge-proxy-next-state",
  },
};

const preferredPools = ["la", "sg"];
const preferredPoolVars = {
  PREFERRED_POOLS: JSON.stringify(preferredPools),
  DEFAULT_PREFERRED_POOL: "la",
};

export function parseTarget(argv = [], env = process.env) {
  let name = env.EDGE_DEPLOY_TARGET ?? "legacy";
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--target") {
      if (!argv[index + 1] || argv[index + 1].startsWith("--")) {
        throw new Error("--target requires legacy or bdot");
      }
      name = argv[++index];
    } else if (argument.startsWith("--target=")) {
      name = argument.slice("--target=".length);
    }
  }
  if (!Object.hasOwn(targets, name)) {
    throw new Error(`unknown deploy target "${name}"; expected legacy or bdot`);
  }
  return { name, ...targets[name] };
}

export function buildMainConfig({ target, accountId, namespaceId, sourceDirectory }) {
  return {
    account_id: accountId,
    name: target.workerName,
    main: `${sourceDirectory}/src/index.ts`,
    compatibility_date: "2026-09-01",
    workers_dev: false,
    preview_urls: false,
    routes: [{ pattern: target.publicHost, custom_domain: true }],
    kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
    vars: {
      PUBLIC_HOST: target.publicHost,
      SITE_NAME: "CF-Next",
      DOH_URL: "https://dns.google/dns-query",
      ...preferredPoolVars,
    },
  };
}

export function buildPreferredControlConfig({
  target,
  accountId,
  namespaceId,
  sourceDirectory,
}) {
  return {
    account_id: accountId,
    name: target.preferredControlWorkerName,
    main: `${sourceDirectory}/src/preferred-control.ts`,
    compatibility_date: "2026-09-01",
    workers_dev: true,
    ...(target.preferredControlHost
      ? { routes: [{ pattern: target.preferredControlHost, custom_domain: true }] }
      : {}),
    kv_namespaces: [{ binding: "EDGE_STATE", id: namespaceId }],
    vars: preferredPoolVars,
  };
}
