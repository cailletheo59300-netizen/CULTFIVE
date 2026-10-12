// Exporte pour l'app iOS (ios/AlbumData) les pochettes et les dos de carte, en PNG à convertir ensuite en WebP :
//   packs/<série>.png      une pochette par série (encyclo + 12 domaines) et la pochette dorée (gold.png), 400 × 600 px
//   backs/<dos>.png        les six dos de carte (dos.js), 600 × 840 px
// Usage : python3 scripts/album/pochettes.py . /tmp/poch.html && node scripts/album/export-app-extras.mjs /tmp/poch.html && python3 scripts/album/export-webp.py
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../ios/AlbumData');
for (const d of ['packs', 'backs']) mkdirSync(join(out, d), { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 800, height: 1000 }, deviceScaleFactor: 2 });
p.on('pageerror', (e) => { console.error(e); process.exitCode = 1; });
await p.goto('file://' + resolve(process.argv[2]));
await p.waitForTimeout(1500);
await p.evaluate(async () => { await document.fonts.ready; document.body.style.cssText = 'display:block;margin:0;padding:0;background:transparent';
  document.body.innerHTML = '<div id="x" style="position:relative;flex:none"></div>'; });
const shots = await p.evaluate(() => SERIES.map(s => s.id).concat(['gold']));
for (const id of shots) {
  await p.evaluate((id) => { const s = id === 'gold' ? { ...SERIES[0], gold: true, pill: '1 LÉGENDAIRE' } : SERIES.find(x => x.id === id);
    const x = document.getElementById('x'); x.style.cssText = 'position:relative;width:200px;height:300px'; x.innerHTML = packSVG(s);
    x.firstElementChild.style.cssText = 'width:200px;height:300px;display:block'; }, id);
  await p.locator('#x').screenshot({ path: join(out, 'packs', id + '.png'), omitBackground: true });
}
for (const k of await p.evaluate(() => Object.keys(DOS))) {
  await p.evaluate((k) => { const x = document.getElementById('x'); x.style.cssText = 'position:relative;width:300px;height:420px'; x.innerHTML = cardBack(k);
    x.firstElementChild.style.cssText = 'width:300px;height:420px;display:block'; }, k);
  await p.locator('#x').screenshot({ path: join(out, 'backs', k + '.png'), omitBackground: true });
}
await b.close();
console.log(shots.length, 'pochettes et les dos exportés');
