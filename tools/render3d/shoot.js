// Usage: node shoot.js <dir with sceneN.js + three.min.js> <scenes e.g. 1,2,3> <cams e.g. 0,3,5>
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const dir = path.resolve(process.argv[2]);
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  for (const s of process.argv[3].split(',')) for (const c of process.argv[4].split(',')) {
    await p.goto('file://' + dir + '/view.html?s=' + s + '&c=' + c + (process.env.NOPANEL ? '&np=1' : ''));
    await p.waitForFunction(() => document.title === 'done', null, { timeout: 120000 });
    await p.screenshot({ path: dir + `/shot_${s}_${c}.png` });
  }
  await b.close();
})();
