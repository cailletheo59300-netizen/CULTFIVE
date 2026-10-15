// Habillage des captures de la fiche App Store en panoramique.
// Une grande image (10 × 1320 px de large, 2868 de haut) avec un décor continu (dégradé, ruban, cartes, coffres) qui
// passe d'une capture à l'autre, puis découpée en 10 images 1320 × 2868 (iPhone 6,9 pouces). Le téléphone et la phrase
// de chaque capture restent entiers dans leur image : chacune se comprend seule.
// Entrée : docs/screenshots/app-store/NN-<écran>.png (workflow « Captures d'écran », option App Store).
// Sortie : docs/screenshots/app-store-fiche/01.png … 10.png, et apercu.png (planche réduite).
// Usage : node scripts/app-store/frames.mjs [nombre d'images, 10 par défaut]
import { readdirSync, mkdirSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = createRequire('/opt/node22/lib/node_modules/')('playwright'); }

const W = 1320, H = 2868;
const RAW = join(root, 'docs/screenshots/app-store');
const OUT = join(root, 'docs/screenshots/app-store-fiche');
const ios = join(root, 'ios');
const icon = (name) => pathToFileURL(join(ios, `CultFive/Resources/Assets.xcassets/Icons/${name}.imageset/${name}.png`)).href;
const album = (path) => pathToFileURL(join(ios, 'AlbumData', path)).href;

// Ordre de la fiche : les 3 premières (vues ensemble dans la recherche) racontent l'app.
const TILES = [
  { screen: 'home',    title: '5 questions.<br>Chaque jour.',             sub: 'Le même défi pour tout le monde, à minuit.', tilt: 0 },
  { screen: 'album',   title: 'Plus de 500 cartes<br>à collectionner',    sub: 'Gagne-les en jouant, complète ton album.', tilt: 3 },
  { screen: 'play',    title: 'Grimpe jusqu’à<br>Encyclopédie',          sub: 'Un Elo dans chacun des 12 domaines.', tilt: -3 },
  { screen: 'typed',   title: 'Des questions<br>qui changent',            sub: 'QCM, frises, jauges, mots à remettre…', tilt: 0 },
  { screen: 'reveal',  title: 'Apprends à chaque<br>réponse',             sub: 'Une explication courte, à retenir.', tilt: 2 },
  { screen: 'result',  title: 'Fais mieux<br>que tes amis',               sub: 'Ton score, ta série, ton classement.', tilt: -2 },
  { screen: 'card',    title: 'Décroche<br>les légendaires',              sub: 'Brillantes, Prestige, Chefs-d’œuvre.', tilt: 0 },
  { screen: 'pass',    title: 'Un pass de saison<br>gratuit',             sub: '30 paliers de récompenses.', tilt: 3 },
  { screen: 'league',  title: 'Crée ta ligue<br>entre amis',              sub: 'Un quiz par jour, un podium par semaine.', tilt: -3 },
  { screen: 'profile', title: 'Toute ta culture<br>d’un coup d’œil',      sub: 'Ce que tu sais… et ce qu’il te reste.', tilt: 0 },
];

// Décor posé à cheval sur les limites entre captures (x en multiples de W), derrière les téléphones.
const DECOR = [
  { src: album('faces/history.antiquity_1.webp'), x: 1.0, y: 1900, w: 400, rot: -12, card: true, front: true },
  { src: album('faces/arts.painting_1.webp'),      x: 0.94, y: 2330, w: 330, rot: 9, card: true },
  { src: album('packs/history.webp'),              x: 2.04, y: 2120, w: 340, rot: 10 },
  { src: icon('rank_encyclopedia'),                x: 2.5, y: 2240, w: 600, rot: 0, glow: true, front: true },
  { src: icon('chest_gold'),                       x: 4.0, y: 2230, w: 440, rot: -6, front: true },
  { src: album('faces/science.space_1.webp'),      x: 5.0, y: 1150, w: 340, rot: 11, card: true },
  { src: album('faces/music.classical_1.webp'),    x: 6.0, y: 2120, w: 380, rot: -9, card: true, front: true },
  { src: album('packs/gold.webp'),                 x: 7.0, y: 1250, w: 360, rot: 8 },
  { src: icon('chest_savant'),                     x: 8.0, y: 2230, w: 450, rot: 6, front: true },
  { src: album('pass/neurone.webp'),               x: 9.0, y: 1300, w: 300, rot: -8 },
];

function rawShot(screen) {
  if (!existsSync(RAW)) return null;
  const file = readdirSync(RAW).find((f) => f.replace(/^\d+-/, '').replace(/\.png$/, '') === screen);
  return file ? pathToFileURL(join(RAW, file)).href : null;
}

function html(count) {
  const width = W * count;
  // Ruban jaune qui serpente sur toute la largeur.
  const points = [];
  for (let i = 0; i <= count * 4; i++) {
    const x = (i * W) / 4;
    points.push([x, 1750 + Math.sin(i * 1.15) * 520 + Math.cos(i * 0.55) * 160]);
  }
  const path = points.map(([x, y], i) => {
    if (i === 0) return `M ${x} ${y}`;
    const [px, py] = points[i - 1];
    const cx = (px + x) / 2;
    return `C ${cx} ${py}, ${cx} ${y}, ${x} ${y}`;
  }).join(' ');
  const tiles = TILES.slice(0, count).map((t, i) => {
    const shot = rawShot(t.screen);
    return `<section class="tile" style="left:${i * W}px">
      <h1>${t.title}</h1><p>${t.sub}</p>
      <div class="phone" style="transform: translateX(-50%) rotate(${t.tilt}deg)">
        ${shot ? `<img src="${shot}">` : `<div class="missing">${t.screen}</div>`}
      </div></section>`;
  }).join('');
  const decor = DECOR.filter((d) => d.x < count).map((d) => `<img class="decor${d.card ? ' card' : ''}${d.glow ? ' glow' : ''}${d.front ? ' front' : ''}" src="${d.src}"
      style="left:${d.x * W - d.w / 2}px; top:${d.y}px; width:${d.w}px; transform: rotate(${d.rot}deg)">`).join('');
  const font = pathToFileURL(join(root, 'scripts/app-store/fonts/nunito-latin.woff2')).href;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face { font-family: Nunito; src: url("${font}") format("woff2"); font-weight: 200 1000; }
    * { margin: 0; box-sizing: border-box; }
    body { width: ${width}px; height: ${H}px; position: relative; overflow: hidden; font-family: Nunito, sans-serif;
      background: linear-gradient(115deg, #2A1490 0%, #4B2BE0 22%, #6A4CFF 45%, #4B2BE0 68%, #2A1490 100%); }
    .glow-bg { position: absolute; inset: 0; background:
      radial-gradient(900px 900px at 8% 18%, rgba(255,210,63,.18), transparent 70%),
      radial-gradient(1100px 1100px at 35% 85%, rgba(240,88,143,.20), transparent 70%),
      radial-gradient(1000px 1000px at 62% 12%, rgba(255,255,255,.12), transparent 70%),
      radial-gradient(1200px 1200px at 88% 80%, rgba(255,210,63,.16), transparent 70%); }
    svg.ribbon { position: absolute; left: 0; top: 0; }
    .tile { position: absolute; top: 0; width: ${W}px; height: ${H}px; }
    h1 { position: absolute; top: 170px; left: 90px; right: 90px; text-align: center; color: #fff; font-weight: 900;
      font-size: 122px; line-height: 1.04; letter-spacing: -1.5px; text-shadow: 0 6px 30px rgba(20,8,80,.35); z-index: 3; }
    p { position: absolute; top: 455px; left: 110px; right: 110px; text-align: center; color: rgba(255,255,255,.86);
      font-weight: 800; font-size: 50px; line-height: 1.25; z-index: 3; }
    .phone { position: absolute; left: 50%; top: 640px; width: 920px; height: 1999px; border-radius: 132px; padding: 22px;
      background: #15112E; box-shadow: 0 60px 120px rgba(10,4,50,.55), inset 0 0 0 4px #2D2752; z-index: 2; }
    .phone img, .phone .missing { width: 100%; height: 100%; border-radius: 110px; display: block; object-fit: cover; background: #F6F5FB; }
    .missing { display: flex; align-items: center; justify-content: center; font-size: 80px; color: #6E6B85; }
    .decor { position: absolute; z-index: 1; filter: drop-shadow(0 30px 40px rgba(10,4,50,.45)); }
    .decor.card { border-radius: 26px; }
    .decor.front { z-index: 4; }
    .decor.glow { filter: drop-shadow(0 0 60px rgba(255,210,63,.65)) drop-shadow(0 30px 40px rgba(10,4,50,.4)); }
  </style></head><body>
    <div class="glow-bg"></div>
    <svg class="ribbon" width="${width}" height="${H}">
      <path d="${path}" fill="none" stroke="rgba(255,255,255,.10)" stroke-width="260" stroke-linecap="round"/>
      <path d="${path}" fill="none" stroke="#FFD23F" stroke-width="70" stroke-linecap="round"/>
    </svg>
    ${decor}${tiles}
  </body></html>`;
}

async function main() {
  const count = Math.min(Number(process.argv[2]) || TILES.length, TILES.length);
  mkdirSync(OUT, { recursive: true });
  const browser = await playwright.chromium.launch(existsSync('/opt/pw-browsers/chromium-1194/chrome-linux/chrome')
    ? { executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' } : {});
  const page = await browser.newPage({ viewport: { width: W * count, height: H } });
  const tmp = join(OUT, '_panorama.html');
  writeFileSync(tmp, html(count));
  await page.goto(pathToFileURL(tmp).href);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(500);
  for (let i = 0; i < count; i++) {
    await page.screenshot({ path: join(OUT, `${String(i + 1).padStart(2, '0')}.png`), clip: { x: i * W, y: 0, width: W, height: H } });
  }
  // Planche réduite, telle qu'on la voit en faisant défiler la fiche (petit espace entre les images).
  const gap = 60, scale = 0.2;
  await page.setViewportSize({ width: Math.round((W * count + gap * (count - 1)) * scale), height: Math.round(H * scale) });
  const sheet = join(OUT, '_apercu.html');
  writeFileSync(sheet, `<body style="margin:0;background:#fff;display:flex;gap:${gap * scale}px">${
    Array.from({ length: count }, (_, i) => `<img style="width:${W * scale}px;height:${H * scale}px" src="${String(i + 1).padStart(2, '0')}.png">`).join('')}</body>`);
  await page.goto(pathToFileURL(sheet).href);
  await page.waitForTimeout(300);
  await page.screenshot({ path: join(OUT, 'apercu.png') });
  await browser.close();
  rmSync(tmp); rmSync(sheet);
  console.log(`${count} images dans ${OUT}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
