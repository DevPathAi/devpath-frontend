// 정적 SPA 서버. 릴리스 빌드(build/web)를 127.0.0.1 루프백으로만 서빙하고,
// 미존재 경로는 index.html 로(딥링크·새로고침), 홈 공지 피드는 빈 stub 으로 응답한다.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.symbols': 'text/plain; charset=utf-8',
};

export async function serve(distDir) {
  const dist = resolve(distDir);
  const index = join(dist, 'index.html');
  const server = createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', 'http://127.0.0.1');
    if (url.pathname === '/updates/feed.json') {
      res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      res.end('{"items":[]}');
      return;
    }
    let file = join(dist, decodeURIComponent(url.pathname));
    if (!file.startsWith(dist + sep) && file !== dist) file = index;
    try {
      const info = await stat(file);
      if (info.isDirectory()) file = join(file, 'index.html');
      await stat(file);
    } catch {
      file = index; // SPA fallback
    }
    try {
      const body = await readFile(file);
      res.writeHead(200, {
        'content-type': contentTypes[extname(file)] ?? 'application/octet-stream',
        'cache-control': 'no-store',
      });
      res.end(body);
    } catch {
      res.writeHead(404);
      res.end();
    }
  });
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  const { port } = server.address();
  return {
    base: `http://127.0.0.1:${port}`,
    port,
    close: () => new Promise((done) => server.close(() => done())),
  };
}
