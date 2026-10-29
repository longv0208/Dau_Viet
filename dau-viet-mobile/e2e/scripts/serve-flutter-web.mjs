import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mobileRoot = path.resolve(__dirname, '../..');
const buildWebDir = path.join(mobileRoot, 'build', 'web');
const port = Number(process.env.MOBILE_WEB_PORT || 4300);
const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8080';

if (!fs.existsSync(path.join(buildWebDir, 'index.html'))) {
  console.log('[serve-flutter-web] Building Flutter web bundle (USE_MOCK=false)...');
  execSync(
    `flutter build web --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=${apiBaseUrl}`,
    { cwd: mobileRoot, stdio: 'inherit' },
  );
}

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.riv': 'application/octet-stream',
  '.frag': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
  const reqUrl = new URL(req.url || '/', `http://localhost:${port}`);
  let relPath = decodeURIComponent(reqUrl.pathname);
  if (relPath === '/' || relPath === '') {
    relPath = '/index.html';
  }
  const safePath = path.normalize(path.join(buildWebDir, relPath));
  if (!safePath.startsWith(buildWebDir)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  let filePath = safePath;
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(buildWebDir, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';
  res.writeHead(200, {
    'Content-Type': contentType,
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`[serve-flutter-web] Serving ${buildWebDir} on http://localhost:${port}`);
});
