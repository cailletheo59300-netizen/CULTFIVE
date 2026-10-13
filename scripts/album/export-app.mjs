// Exporte les cartes pour l'app iOS : ios/AlbumData/
//   faces/<page>_<n>.webp  la carte entière (rareté de la fiche), 600 × 838 px
//   art/<page>_<n>.webp    le dessin seul, sans médaillon, fond transparent (silhouettes, Prestige)
//   cards.json             pages et cartes (textes, rareté, domaine) lues par l'app
// Usage : python3 scripts/album/planche.py . <toutes les pages> /tmp/toutes.html && node scripts/album/export-app.mjs /tmp/toutes.html && python3 scripts/album/export-webp.py && node scripts/album/card-ids.mjs
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../ios/AlbumData');
for (const d of ['faces', 'art']) mkdirSync(join(out, d), { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 800, height: 1000 }, deviceScaleFactor: 2 });
p.on('pageerror', (e) => { console.error(e); process.exitCode = 1; });
await p.goto('file://' + resolve(process.argv[2]));
await p.waitForTimeout(1500);
await p.evaluate(async () => { for (let t = 0; t < 20 && !document.fonts.check('900 20px Fraunces'); t++) await new Promise(r => setTimeout(r, 300)); await document.fonts.ready; });
const pages = await p.evaluate(() => PAGES.map(pg => ({ key: pg.key, title: pg.title, dom: pg.dom, domLabel: DOMS[pg.dom].label, tone: DOMS[pg.dom].tone,
  cards: pg.cards.map(c => ({ n: c[0], name: c[1], figure: c[2], unit: c[3], phrase: c[4], rarity: c[5] })) })));
await p.evaluate(() => { document.body.style.cssText = 'display:block;margin:0;padding:0;width:auto'; document.body.innerHTML = '<div id="stage" style="padding:20px;background:#fff;flex:none"></div><div id="art" style="width:300px;height:240px;position:relative;flex:none"></div>'; });
let n = 0;
for (const [pi, pg] of pages.entries()) {
  for (const c of pg.cards) {
    const id = `${pg.key}_${c.n}`;
    await p.evaluate(([pi, ci]) => { NOMED = false; const pg = PAGES[pi], c = pg.cards[ci]; const s = document.getElementById('stage');
      s.innerHTML = cardHTML(pg, c, {}); const card = s.firstElementChild; card.style.setProperty('--w', '300px'); card.style.boxShadow = 'none'; fit(s);
      s.querySelectorAll('.legend-glow').forEach(e => e.remove()); }, [pi, pg.cards.indexOf(c)]);
    await p.locator('#stage .card').screenshot({ path: join(out, 'faces', id + '.jpg'), type: 'jpeg', quality: 82 });
    await p.evaluate(([pi, ci]) => { NOMED = true; const pg = PAGES[pi], c = pg.cards[ci]; const a = document.getElementById('art');
      const tmp = document.createElement('div'); tmp.innerHTML = artSVG(pg, c[0], 'common'); const sv = tmp.querySelector('svg.subj'); sv.style.cssText = 'position:absolute;inset:0;width:300px;height:240px';
      a.innerHTML = ''; a.appendChild(sv); NOMED = false; }, [pi, pg.cards.indexOf(c)]);
    await p.locator('#art').screenshot({ path: join(out, 'art', id + '.png'), omitBackground: true });
    n++;
  }
}
writeFileSync(join(out, 'cards.json'), JSON.stringify({ version: 1, pages }, null, 0));
await b.close();
console.log(n, 'cartes exportées');
