// Rend les icônes 3D du pass (pass-icons.js, même moteur que scripts/icons/icons.html) dans scripts/album/pass-icons/.
// Usage : node scripts/album/pass-icons.mjs [chemin/vers/three.min.js] [une seule icône]   (Playwright + Chromium)
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync, copyFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, 'pass-icons'); mkdirSync(out, { recursive: true });
const localThree = process.argv[2] && resolve(process.argv[2]);
const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await b.newPage();
p.on('pageerror', (e) => { console.error(e); process.exitCode = 1; });
if (localThree) await p.route('**/three.min.js', (r) => r.fulfill({ path: localThree }));
await p.goto('file://' + resolve(here, '../icons/icons.html'));
await p.waitForFunction(() => typeof window.renderIcons === 'function' && window.THREE);
await p.addScriptTag({ path: join(here, 'dos.js') });
await p.addScriptTag({ path: join(here, 'pass-icons.js') });
// Nunito : Google Fonts, sinon la copie locale (scripts/app-store/fonts).
await p.addStyleTag({ url: 'https://fonts.googleapis.com/css2?family=Nunito:wght@800;900&display=swap' }).catch(() =>
  p.addStyleTag({ content: `@font-face{font-family:Nunito;font-weight:200 1000;src:url(file://${resolve(here, '../app-store/fonts/nunito-latin.woff2')}) format('woff2');}` }));
await p.evaluate(async () => { try { await document.fonts.load('900 100px Nunito'); } catch (e) {} await document.fonts.ready; });
const only = process.argv[3];
const size = Number(process.env.SIZE || 256);  // SIZE=600 : icônes en haute définition pour l'app
const icons = await p.evaluate(([only, size]) => window.renderPass(size, only), [only, size]);
for (const [k, url] of Object.entries(icons)) writeFileSync(join(out, k + '.png'), Buffer.from(url.split(',')[1], 'base64'));
if (!only) for (const c of ['chest_wood', 'chest_silver', 'chest_gold', 'chest_savant'])
  copyFileSync(resolve(here, `../../ios/CultFive/Resources/Assets.xcassets/Icons/${c}.imageset/${c}.png`), join(out, c + '.png'));
await b.close();
console.log(Object.keys(icons).length, 'icônes');
