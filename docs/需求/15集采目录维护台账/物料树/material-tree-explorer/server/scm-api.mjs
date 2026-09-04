import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

function findWorkspaceRoot() {
  let currentDirectory = dirname(fileURLToPath(import.meta.url));
  while (true) {
    if (
      existsSync(resolve(currentDirectory, 'scripts/api.sh')) &&
      existsSync(resolve(currentDirectory, 'scripts/auth.sh'))
    ) {
      return currentDirectory;
    }
    const parentDirectory = dirname(currentDirectory);
    if (parentDirectory === currentDirectory) {
      throw new Error('找不到工作区 scripts/api.sh 和 scripts/auth.sh');
    }
    currentDirectory = parentDirectory;
  }
}

const WORKSPACE_ROOT = findWorkspaceRoot();
const API_SCRIPT = resolve(WORKSPACE_ROOT, 'scripts/api.sh');
const AUTH_SCRIPT = resolve(WORKSPACE_ROOT, 'scripts/auth.sh');
const ALLOWED_ENVIRONMENTS = new Set(['test', 'uat']);
const TREE_CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_REQUEST_BYTES = 32 * 1024;
const MAX_CHILD_OUTPUT_BYTES = 32 * 1024 * 1024;
const treeCache = new Map();
const organizationCache = new Map();

class PublicError extends Error {
  constructor(message, statusCode = 400) {
    super(message);
    this.statusCode = statusCode;
  }
}

function environmentOf(value) {
  const environment = String(value ?? 'test').toLowerCase();
  if (!ALLOWED_ENVIRONMENTS.has(environment)) {
    throw new PublicError('环境只能是 test 或 uat');
  }
  return environment;
}

function boundedText(value, name, maxLength = 200) {
  const text = String(value ?? '').trim();
  if (text.length > maxLength) {
    throw new PublicError(`${name}不能超过 ${maxLength} 个字符`);
  }
  return text;
}

function positiveInteger(value, fallback, minimum, maximum, name) {
  const number = Number(value ?? fallback);
  if (!Number.isInteger(number) || number < minimum || number > maximum) {
    throw new PublicError(`${name}必须是 ${minimum} 到 ${maximum} 的整数`);
  }
  return number;
}

function runScript(scriptPath, args, timeoutMs = 90_000) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [scriptPath, ...args], {
      cwd: WORKSPACE_ROOT,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const stdout = [];
    const stderr = [];
    let outputBytes = 0;
    let settled = false;

    const finish = (callback) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      callback();
    };

    const collect = (target) => (chunk) => {
      outputBytes += chunk.length;
      if (outputBytes > MAX_CHILD_OUTPUT_BYTES) {
        child.kill('SIGTERM');
        finish(() => reject(new PublicError('接口返回数据过大，已停止读取', 502)));
        return;
      }
      target.push(chunk);
    };

    child.stdout.on('data', collect(stdout));
    child.stderr.on('data', collect(stderr));
    child.on('error', () => finish(() => reject(new PublicError('无法启动工作区登录脚本', 502))));
    child.on('close', (code) => {
      finish(() => {
        const output = Buffer.concat(stdout).toString('utf8').trim();
        const errorOutput = Buffer.concat(stderr).toString('utf8').trim();
        if (code !== 0) {
          reject(new PublicError(errorOutput || `工作区脚本执行失败（exit ${code}）`, 502));
          return;
        }
        resolve({ output, notice: errorOutput });
      });
    });

    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      finish(() => reject(new PublicError('查询超时，请检查内网连接后重试', 504)));
    }, timeoutMs);
  });
}

async function callScmApi(environment, path, body) {
  const { output, notice } = await runScript(API_SCRIPT, [
    '--env',
    environment,
    '--platform',
    'procurement',
    '--account',
    'admin',
    'POST',
    path,
    JSON.stringify(body),
  ]);

  let result;
  try {
    result = JSON.parse(output);
  } catch {
    throw new PublicError('公司接口没有返回有效 JSON', 502);
  }
  if (!result?.status) {
    throw new PublicError(result?.msg || result?.message || '公司接口返回失败', 502);
  }
  return { result, notice };
}

function normalizeCategory(row) {
  return {
    classId: row.classId ?? '',
    classCode: row.classCode ?? '',
    className: row.className ?? '',
    parentClassCode: row.parentClassCode ?? '0',
    parentClassName: row.parentClassName ?? '',
    state: String(row.state ?? ''),
    upperTime: row.upperTime ?? null,
    updateTime: row.updateTime ?? null,
    unit: row.unit ?? '',
    unitCode: row.unitCode ?? '',
    purchaseType: row.purchaseType ?? '',
    purchaseTypeDesc: row.purchaseTypeDesc ?? '',
    description: row.orgName ?? '',
    dataSource: row.dataSource ?? '',
  };
}

async function fetchAllCategories(environment, bypassCache = false) {
  const cached = treeCache.get(environment);
  if (!bypassCache && cached && Date.now() - cached.cachedAt < TREE_CACHE_TTL_MS) {
    return { ...cached.value, cached: true };
  }

  const pageSize = 5000;
  const first = await callScmApi(
    environment,
    '/c/business/mdm/productClassQuery/queryProductClassPage',
    { currentPage: 1, limit: pageSize, model: {} },
  );
  const data = first.result.data ?? {};
  const rows = Array.isArray(data.root) ? [...data.root] : [];
  const totalCount = Number(data.totalCount ?? rows.length);
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));

  for (let currentPage = 2; currentPage <= totalPages; currentPage += 1) {
    const next = await callScmApi(
      environment,
      '/c/business/mdm/productClassQuery/queryProductClassPage',
      { currentPage, limit: pageSize, model: {} },
    );
    rows.push(...(next.result.data?.root ?? []));
  }

  const value = {
    environment,
    fetchedAt: new Date().toISOString(),
    totalCount,
    nodes: rows.map(normalizeCategory),
    source: {
      endpoint: '/c/business/mdm/productClassQuery/queryProductClassPage',
      authentication: 'scripts/api.sh',
    },
    notice: first.notice || '',
  };
  treeCache.set(environment, { cachedAt: Date.now(), value });
  return { ...value, cached: false };
}

function normalizeOrganization(row) {
  return {
    orgId: row.orgId ?? '',
    orgCode: row.orgCode ?? '',
    orgName: row.orgName ?? '',
    shortName: row.shortName ?? '',
    shortFullName: row.shortFullName ?? '',
    state: String(row.state ?? ''),
    stateDesc: row.stateDesc ?? '',
    organizationLevel: row.organizationLevel ?? '',
    authLevel: row.authLevel ?? '',
    orgType: row.orgType ?? '',
    orgTypeDesc: row.orgTypeDesc ?? '',
    businessType: row.businessType ?? '',
    businessTypeDesc: row.businessTypeDesc ?? '',
    belongBuCode: row.belongBuCode ?? '',
    belongBuName: row.belongBuName ?? '',
    belongPlateCode: row.belongPlateCode ?? '',
    belongPlateName: row.belongPlateName ?? '',
    belongCompanyOrgCode: row.belongCompanyOrgCode ?? '',
    belongCompanyOrgName: row.belongCompanyOrgName ?? '',
    areaPurchase: row.areaPurchase ?? null,
    areaPurchaseDesc: row.areaPurchaseDesc ?? '',
    isOffice: row.isOffice ?? '',
    belongOfficeCode: row.belongOfficeCode ?? '',
    belongOfficeName: row.belongOfficeName ?? '',
    companyAddress: row.companyAddress ?? '',
    updateTime: row.updateTime ?? null,
  };
}

async function fetchAllOrganizations(environment, bypassCache = false) {
  const cached = organizationCache.get(environment);
  if (!bypassCache && cached && Date.now() - cached.cachedAt < TREE_CACHE_TTL_MS) {
    return { ...cached.value, cached: true };
  }

  const { result, notice } = await callScmApi(
    environment,
    '/c/business/ubm/org/queryList',
    {},
  );
  const rows = Array.isArray(result.data) ? result.data : [];
  const value = {
    environment,
    fetchedAt: new Date().toISOString(),
    totalCount: rows.length,
    organizations: rows.map(normalizeOrganization),
    source: {
      endpoint: '/c/business/ubm/org/queryList',
      authentication: 'scripts/api.sh',
    },
    notice: notice || '',
  };
  organizationCache.set(environment, { cachedAt: Date.now(), value });
  return { ...value, cached: false };
}

function buildMaterialModel(input) {
  const model = {};
  const stringFields = [
    ['searchWord', '综合关键词'],
    ['productCode', '物料编码'],
    ['productName', '物料名称'],
    ['productDesc', '物料长描述'],
    ['productShortDesc', '物料短描述'],
  ];
  for (const [field, label] of stringFields) {
    const value = boundedText(input[field], label);
    if (value) model[field] = value;
  }

  const categoryCode = boundedText(input.categoryCode, '类目编码', 16);
  if (categoryCode) {
    if (!/^\d{2}(?:\d{2}){0,3}$/.test(categoryCode)) {
      throw new PublicError('类目编码必须是 2、4、6 或 8 位数字');
    }
    const fieldByLength = {
      2: 'bigClassCode',
      4: 'midClassCode',
      6: 'smallClassCode',
      8: 'smallLbCode',
    };
    model[fieldByLength[categoryCode.length]] = categoryCode;
  }
  return model;
}

async function fetchMaterials(input) {
  const environment = environmentOf(input.environment);
  const currentPage = positiveInteger(input.currentPage, 1, 1, 100_000, '页码');
  const limit = positiveInteger(input.limit, 20, 10, 100, '每页条数');
  const model = buildMaterialModel(input);
  const { result, notice } = await callScmApi(
    environment,
    '/c/business/mdm/productQuery/queryProductPageList',
    { currentPage, limit, model },
  );
  const data = result.data ?? {};
  return {
    environment,
    currentPage: Number(data.currentPage ?? currentPage),
    limit: Number(data.limit ?? limit),
    totalCount: Number(data.totalCount ?? 0),
    totalPage: Number(data.totalPage ?? 0),
    rows: Array.isArray(data.root) ? data.root : [],
    fetchedAt: new Date().toISOString(),
    notice: notice || '',
  };
}

async function readJsonBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_REQUEST_BYTES) {
      throw new PublicError('请求体过大', 413);
    }
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new PublicError('请求体必须是 JSON');
  }
}

function sendJson(response, statusCode, payload) {
  response.statusCode = statusCode;
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.end(JSON.stringify(payload));
}

export function createApiHandler() {
  return async function handleApi(request, response) {
    try {
      const url = new URL(request.url ?? '/', 'http://127.0.0.1');
      if (request.method === 'GET' && url.pathname === '/api/categories') {
        const environment = environmentOf(url.searchParams.get('environment'));
        const refresh = url.searchParams.get('refresh') === '1';
        sendJson(response, 200, await fetchAllCategories(environment, refresh));
        return;
      }
      if (request.method === 'GET' && url.pathname === '/api/organizations') {
        const environment = environmentOf(url.searchParams.get('environment'));
        const refresh = url.searchParams.get('refresh') === '1';
        sendJson(response, 200, await fetchAllOrganizations(environment, refresh));
        return;
      }
      if (request.method === 'POST' && url.pathname === '/api/materials') {
        sendJson(response, 200, await fetchMaterials(await readJsonBody(request)));
        return;
      }
      if (request.method === 'GET' && url.pathname === '/api/auth/status') {
        const environment = environmentOf(url.searchParams.get('environment'));
        const { output } = await runScript(AUTH_SCRIPT, ['status', environment, 'admin'], 30_000);
        sendJson(response, 200, { environment, status: output });
        return;
      }
      if (request.method === 'POST' && url.pathname === '/api/auth/login') {
        const body = await readJsonBody(request);
        const environment = environmentOf(body.environment);
        await runScript(AUTH_SCRIPT, ['login', environment, 'admin'], 45_000);
        sendJson(response, 200, { environment, status: '登录成功，token 已写入工作区受控缓存' });
        return;
      }
      sendJson(response, 404, { error: '没有这个本地接口' });
    } catch (error) {
      const statusCode = error instanceof PublicError ? error.statusCode : 500;
      const message = error instanceof PublicError ? error.message : '本地服务发生未知错误';
      sendJson(response, statusCode, { error: message });
    }
  };
}
