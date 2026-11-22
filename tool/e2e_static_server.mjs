// Servidor estático mínimo para o build web E2E (somente emuladores locais).
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';

const raiz = process.argv[2] ?? 'build/web_e2e';
const porta = Number(process.argv[3] ?? 7358);
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.txt': 'text/plain; charset=utf-8',
};

createServer((req, res) => {
  const url = decodeURIComponent((req.url ?? '/').split('?')[0]);
  const relativo = normalize(url).replace(/^(\.\.[/\\])+/, '').replace(/^[/\\]+/, '');
  let arquivo = join(raiz, relativo);
  if (!existsSync(arquivo) || statSync(arquivo).isDirectory()) {
    arquivo = join(raiz, 'index.html');
  }
  res.writeHead(200, {
    'Content-Type': mime[extname(arquivo)] ?? 'application/octet-stream',
    'Cache-Control': 'no-store',
  });
  createReadStream(arquivo).pipe(res);
}).listen(porta, '127.0.0.1', () => {
  console.log(`E2E web: http://127.0.0.1:${porta}/ (${raiz})`);
});
