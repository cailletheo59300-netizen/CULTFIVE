// Fabrique les icônes 3D de l'app et les range dans Assets.xcassets (un PNG @3x par icône).
// Usage : node scripts/icons/render.mjs [chemin/vers/three.min.js]
// Sans argument, three.js r128 est chargé depuis cdnjs. Demande Playwright et Chromium (WebGL logiciel suffit).
import { chromium } from 'playwright';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const assets = resolve(here, '../../ios/CultFive/Resources/Assets.xcassets/Icons');
const localThree = process.argv[2] && resolve(process.argv[2]);

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage();
page.on('pageerror', (e) => { console.error(e); process.exitCode = 1; });
if (localThree) await page.route('**/three.min.js', (route) => route.fulfill({ path: localThree }));
await page.goto('file://' + join(here, 'icons.html'));
await page.waitForFunction(() => typeof window.renderIcons === 'function' && window.THREE);
const icons = await page.evaluate(() => window.renderIcons());
await browser.close();

rmSync(assets, { recursive: true, force: true });
mkdirSync(assets, { recursive: true });
writeFileSync(join(assets, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 }, properties: { 'provides-namespace': false } }, null, 2) + '\n');
for (const [name, url] of Object.entries(icons)) {
  const dir = join(assets, `${name}.imageset`);
  mkdirSync(dir);
  writeFileSync(join(dir, `${name}.png`), Buffer.from(url.split(',')[1], 'base64'));
  writeFileSync(join(dir, 'Contents.json'), JSON.stringify({
    images: [{ idiom: 'universal', filename: `${name}.png`, scale: '3x' }],
    info: { author: 'xcode', version: 1 },
  }, null, 2) + '\n');
  console.log(name);
}
