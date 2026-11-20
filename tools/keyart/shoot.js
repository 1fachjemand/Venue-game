// Renders tools/keyart/keyart.html to a PNG. The files are served from disk through Playwright
// (no web server needed): node tools/keyart/shoot.js <dir> "<query>" out.png [w h]
// <dir> holds keyart.html, the exported keyart_*.json, a "three" folder (npm package three@0.160.0)
// and InterDisplay-Black.otf.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.otf': 'font/otf' };
(async () => {
  const dir = path.resolve(process.argv[2]);
  const w = +(process.argv[5] || 1920), h = +(process.argv[6] || 1080);
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  await p.route('http://keyart.local/**', route => {
    const rel = decodeURIComponent(new URL(route.request().url()).pathname).replace(/^\/+/, '');
    const file = path.join(dir, rel);
    if (!file.startsWith(dir) || !fs.existsSync(file)) return route.fulfill({ status: 404, body: 'not found' });
    route.fulfill({ status: 200, body: fs.readFileSync(file), contentType: TYPES[path.extname(file)] || 'application/octet-stream' });
  });
  p.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  p.on('pageerror', e => console.log('pageerror:', e.message));
  await p.goto('http://keyart.local/keyart.html?' + process.argv[3]);
  await p.waitForFunction(() => document.title === 'done', null, { timeout: 600000 });
  await p.screenshot({ path: process.argv[4] });
  await b.close();
})();
