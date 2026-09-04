import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApiHandler } from './scm-api.mjs';

const PROJECT_ROOT = fileURLToPath(new URL('../', import.meta.url));
const DIST_ROOT = resolve(PROJECT_ROOT, 'dist');
const PORT = Number(process.env.MATERIAL_TREE_PORT || 4317);
const handleApi = createApiHandler();
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
};

if (!existsSync(resolve(DIST_ROOT, 'index.html'))) {
  console.error('找不到 dist/index.html，请先运行 npm run build');
  process.exit(1);
}

createServer((request, response) => {
  if (request.url?.startsWith('/api/')) {
    void handleApi(request, response);
    return;
  }

  const url = new URL(request.url ?? '/', 'http://127.0.0.1');
  const requestedPath = decodeURIComponent(url.pathname);
  const candidate = resolve(DIST_ROOT, `.${requestedPath}`);
  const safeCandidate = candidate === DIST_ROOT || candidate.startsWith(`${DIST_ROOT}${sep}`);
  let filePath = safeCandidate && existsSync(candidate) && statSync(candidate).isFile()
    ? candidate
    : resolve(DIST_ROOT, 'index.html');

  response.statusCode = 200;
  response.setHeader('Content-Type', contentTypes[extname(filePath)] || 'application/octet-stream');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  createReadStream(filePath).pipe(response);
}).listen(PORT, '127.0.0.1', () => {
  console.log(`物料全景树已启动：http://127.0.0.1:${PORT}`);
});
