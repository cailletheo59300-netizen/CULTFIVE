// Carrousels TikTok / Instagram de Brainlix (1080 × 1920) : accroche, 3 questions avec leur réponse, appel final.
// Fonds « peinture ancienne » générés (aucun droit d'image). Lancer : NODE_PATH=$(npm root -g) node generer.js [dossier]
// Pour mettre un vrai tableau du domaine public en fond : ajouter "bg": "chemin/vers/image.jpg" à une question.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const out = path.resolve(process.argv[2] || 'sortie');
const here = __dirname;
// FICHIER=faits.json : carrousels « tu savais ? » (un fait par image, appli recommandée à la fin) ; sinon les quiz.
const data = JSON.parse(fs.readFileSync(path.join(here, process.env.FICHIER || 'carrousels.json'), 'utf8'));
const asset = (p) => 'data:' + (p.endsWith('.ttf') ? 'font/ttf' : p.endsWith('.png') ? 'image/png' : 'image/jpeg') +
  ';base64,' + fs.readFileSync(path.resolve(here, p)).toString('base64');
const nunito = asset('../../android/app/src/main/res/font/nunito.ttf');
const playfair = asset('polices/playfair-italic-800.ttf');
const garamond = asset('polices/ebgaramond-500.ttf');
const garamondBold = asset('polices/ebgaramond-700.ttf');
const montserrat = asset('polices/montserrat-800.ttf');
// Style de la 1re image : "elegant" (italique, ornement doré) ou "tiktok" (gros texte blanc, comme les mèmes).
const hookStyle = process.env.ACCROCHE || 'elegant';
const icon = asset('../../ios/CultFive/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png');
// Typographie française : espace insécable avant ? ! : ; et dans « », pour ne jamais laisser un signe seul en début de ligne.
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/ ([?!:;»%])/g, '\u00a0$1').replace(/« /g, '«\u00a0');

// Fond peint : ciel et terre (paysage) ou clair-obscur (bougie), grain de toile, coups de pinceau, vignette.
function painting(kind, seed, glow) {
  const sky = kind === 'paysage'
    ? `<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
         <stop offset="0" stop-color="#3a3d44"/><stop offset=".33" stop-color="#5d6068"/><stop offset=".40" stop-color="#4a4f5c"/>
         <stop offset=".44" stop-color="#6b5a40"/><stop offset=".7" stop-color="#4a3a24"/><stop offset="1" stop-color="#241a10"/></linearGradient>`
    : `<radialGradient id="g" cx=".5" cy=".42" r=".75">
         <stop offset="0" stop-color="${glow}" stop-opacity=".55"/><stop offset=".35" stop-color="#3a2614"/><stop offset="1" stop-color="#0c0805"/></radialGradient>`;
  return `<svg class="bg" viewBox="0 0 1080 1920" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
    <defs>${sky}
      <filter id="brush"><feTurbulence type="fractalNoise" baseFrequency="0.0025 0.018" numOctaves="4" seed="${seed}"/>
        <feColorMatrix values="0 0 0 0 .5  0 0 0 0 .4  0 0 0 0 .3  0 0 0 1.1 -.35"/></filter>
      <filter id="blot"><feTurbulence type="fractalNoise" baseFrequency="0.006" numOctaves="3" seed="${seed + 7}"/>
        <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1.4 -.55"/></filter>
      <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="${seed + 3}"/>
        <feColorMatrix values="0 0 0 0 .5  0 0 0 0 .45  0 0 0 0 .35  0 0 0 .22 0"/></filter>
      <radialGradient id="v" cx=".5" cy=".45" r=".8"><stop offset=".45" stop-color="#000" stop-opacity="0"/>
        <stop offset="1" stop-color="#000" stop-opacity=".78"/></radialGradient>
    </defs>
    <rect width="1080" height="1920" fill="url(#g)"/>
    <rect width="1080" height="1920" filter="url(#blot)" opacity=".7"/>
    <rect width="1080" height="1920" filter="url(#brush)" opacity=".55" style="mix-blend-mode:overlay"/>
    <rect width="1080" height="1920" filter="url(#grain)"/>
    <rect width="1080" height="1920" fill="url(#v)"/>
  </svg>`;
}

const css = `
  @font-face { font-family: Nunito; src: url(${nunito}); font-weight: 200 1000; }
  @font-face { font-family: Playfair; src: url(${playfair}); font-style: italic; font-weight: 800; }
  @font-face { font-family: Garamond; src: url(${garamond}); font-weight: 400 500; }
  @font-face { font-family: Garamond; src: url(${garamondBold}); font-weight: 600 800; }
  @font-face { font-family: Montserrat; src: url(${montserrat}); font-weight: 800; }
  * { margin: 0; box-sizing: border-box; }
  body { width: 1080px; height: 1920px; overflow: hidden; background: #000; }
  .slide { position: relative; width: 1080px; height: 1920px; overflow: hidden; color: #f4ecdf; }
  .bg, .photo { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .photo + .shade { position: absolute; inset: 0; background: radial-gradient(circle at 50% 45%, rgba(0,0,0,.15), rgba(0,0,0,.7)); }
  .center { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 0 90px; text-align: center; }
  .hook-tiktok { font: 800 80px/1.18 Montserrat, sans-serif; color: #fff; letter-spacing: -1px;
                 text-shadow: 0 0 2px #000, 0 3px 6px rgba(0,0,0,.9), 0 8px 30px rgba(0,0,0,.7); }
  .kicker { font: 800 28px Nunito, sans-serif; letter-spacing: 8px; text-transform: uppercase; color: #e9c27a; }
  .hook { margin-top: 46px; font: italic 800 98px/1.1 Playfair, serif; color: #fbf3e4; text-shadow: 0 4px 24px rgba(0,0,0,.85); }
  .orn { display: flex; align-items: center; gap: 22px; width: 520px; color: #e9c27a; }
  .orn i { flex: 1; height: 1.5px; background: linear-gradient(90deg, transparent, #e9c27a, transparent); }
  .orn b { font: 30px serif; }
  .orn.top { margin-bottom: 46px; } .orn.bottom { margin-top: 56px; }
  .tag { font: 800 30px Nunito, sans-serif; letter-spacing: 6px; text-transform: uppercase; color: #e9c27a; margin-bottom: 40px; }
  .q { font: 700 74px/1.18 Garamond, serif; text-shadow: 0 3px 16px rgba(0,0,0,.8); }
  .choices { margin-top: 70px; display: grid; gap: 22px; width: 100%; }
  .choice { font: 400 46px Garamond, serif; padding: 22px 34px; border: 1.5px solid rgba(244,236,223,.45);
            border-radius: 18px; background: rgba(12,8,5,.35); text-align: left; display: flex; gap: 26px; }
  .choice b { font-family: Nunito, sans-serif; font-weight: 900; color: #e9c27a; }
  .swipe { position: absolute; bottom: 230px; left: 0; right: 0; text-align: center; font: 800 36px Nunito, sans-serif; color: rgba(244,236,223,.8); }
  .answer { font: 700 112px/1.05 Garamond, serif; text-shadow: 0 4px 20px rgba(0,0,0,.85); }
  .why { margin-top: 44px; font: 400 52px/1.35 Garamond, serif; text-shadow: 0 2px 12px rgba(0,0,0,.9); }
  .pct { margin-top: 70px; font: 800 36px Nunito, sans-serif; color: #1c1206; background: #e9c27a; padding: 16px 32px; border-radius: 999px; }
  .num { position: absolute; top: 170px; left: 0; right: 0; text-align: center; font: 700 40px Garamond, serif; color: rgba(244,236,223,.7); letter-spacing: 4px; }
  .icon { width: 300px; height: 300px; border-radius: 68px; box-shadow: 0 18px 60px rgba(0,0,0,.6); margin: 60px 0 26px; }
  .name { font: 900 64px Nunito, sans-serif; letter-spacing: 10px; }
  .cta { font: 900 86px/1.1 Nunito, sans-serif; text-shadow: 0 4px 18px rgba(0,0,0,.8); }
  .sub { margin-top: 26px; font: 400 46px/1.3 Garamond, serif; color: rgba(244,236,223,.85); }
  .badge { margin-top: 70px; background: #000; border: 2px solid #8a8a8a; border-radius: 26px; padding: 22px 54px; text-align: left; }
  .badge small { display: block; font: 600 30px Nunito, sans-serif; color: #ddd; }
  .badge span { font: 800 64px Nunito, sans-serif; color: #fff; }
  .count { font: 700 34px Garamond, serif; letter-spacing: 6px; color: #e9c27a; margin-bottom: 44px; }
  .fact { font: italic 800 92px/1.08 Playfair, serif; color: #fbf3e4; text-shadow: 0 4px 24px rgba(0,0,0,.85); }
  .fact-text { margin-top: 56px; font: 400 54px/1.38 Garamond, serif; text-shadow: 0 2px 12px rgba(0,0,0,.9); }
  .fact-text b { font-weight: 700; color: #f3d28f; }
  .plug { font: 500 60px/1.32 Garamond, serif; text-shadow: 0 2px 12px rgba(0,0,0,.9); }
  .plug b { font-weight: 700; color: #f3d28f; }
  .avatar { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; }
`;

const page = (inner) => `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${inner}</body></html>`;
const bg = (q, kind, seed, glow) => q && q.bg
  ? `<img class="photo" src="${asset(q.bg)}"><div class="shade"></div>`
  : painting(kind, seed, glow);

function slides(c, ci) {
  const s = [];
  const seed = (n) => ci * 40 + n;
  const hook = hookStyle === 'tiktok'
    ? `<div class="hook-tiktok">${esc(c.hook)}</div>`
    : `<div class="kicker">Brainlix · Culture G</div><div class="hook">${esc(c.hook)}</div><div class="orn bottom"><i></i><b>◆</b><i></i></div>`;
  s.push(`<div class="slide">${painting('bougie', seed(1), c.glow)}<div class="center">${hook}</div></div>`);
  c.questions.forEach((q, i) => {
    const kind = i % 2 ? 'bougie' : 'paysage';
    s.push(`<div class="slide">${bg(q, kind, seed(10 + i), c.glow)}<div class="num">${i + 1} / 3</div><div class="center">
      <div class="tag">Tu trouves ?</div><div class="q">${esc(q.q)}</div>
      <div class="choices">${q.choices.map((t, k) => `<div class="choice"><b>${'ABCD'[k]}</b>${esc(t)}</div>`).join('')}</div></div>
      <div class="swipe">La réponse →</div></div>`);
    s.push(`<div class="slide">${bg(q, kind, seed(10 + i), c.glow)}<div class="num">${i + 1} / 3</div><div class="center">
      <div class="tag">Réponse</div><div class="answer">${esc(q.a)}</div><div class="why">${esc(q.why)}</div>
      <div class="pct">Seulement ${q.pct} % des joueurs ont trouvé</div></div></div>`);
  });
  s.push(`<div class="slide">${painting('bougie', seed(30), c.glow)}<div class="center">
    <div class="cta">${esc("Combien tu en as eu ?")}</div><div class="sub">Dis-le en commentaire, puis teste-toi chaque jour</div>
    <img class="icon" src="${icon}"><div class="name">BRAINLIX</div>
    <div class="badge"><small>Gratuit sur</small><span>l'App Store</span></div></div></div>`);
  return s;
}

// Carrousel « fait » : accroche, un fait par image (titre + explication), puis l'appli conseillée comme par un abonné.
function factSlides(c, ci) {
  const s = [];
  const seed = (n) => ci * 40 + n;
  s.push(`<div class="slide">${painting('bougie', seed(1), c.glow)}<div class="center">
    <div class="hook">${esc(c.hook)}</div><div class="orn bottom"><i></i><b>◆</b><i></i></div></div></div>`);
  c.facts.forEach((f, i) => {
    s.push(`<div class="slide">${bg(f, i % 2 ? 'bougie' : 'paysage', seed(10 + i), c.glow)}<div class="center">
      <div class="count">${i + 1} / ${c.facts.length}</div><div class="fact">${esc(f.title)}</div>
      <div class="fact-text">${esc(f.text).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')}</div></div></div>`);
  });
  s.push(`<div class="slide">${painting('bougie', seed(30), c.glow)}<div class="center">
    <div class="plug">${esc(c.plug).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')}</div>
    <img class="icon" src="${icon}"><div class="name">BRAINLIX</div>
    <div class="badge"><small>Gratuit sur</small><span>l'App Store</span></div></div></div>`);
  return s;
}

// Photo de profil (1080 × 1080) du compte « faits » : une bougie dans le clair-obscur, sans marque.
function avatar() {
  return `<div class="slide" style="width:1080px;height:1080px">${painting('bougie', 5, '#e0a24a')}
    <div class="avatar"><svg width="1080" height="1080" viewBox="0 0 1080 1080" xmlns="http://www.w3.org/2000/svg">
      <defs><radialGradient id="halo" cx=".5" cy=".38" r=".42"><stop offset="0" stop-color="#ffd27a" stop-opacity=".55"/>
        <stop offset=".5" stop-color="#d08a2e" stop-opacity=".18"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
        <linearGradient id="wax" x1="0" x2="1"><stop offset="0" stop-color="#8a7356"/><stop offset=".45" stop-color="#efe2c6"/>
        <stop offset="1" stop-color="#6b5840"/></linearGradient>
        <radialGradient id="flame" cx=".5" cy=".7" r=".6"><stop offset="0" stop-color="#fffbe8"/><stop offset=".45" stop-color="#ffd36b"/>
        <stop offset="1" stop-color="#e2731f" stop-opacity="0"/></radialGradient>
        <filter id="soft"><feGaussianBlur stdDeviation="3"/></filter></defs>
      <rect width="1080" height="1080" fill="url(#halo)"/>
      <path d="M540 245 C 590 330 585 395 540 425 C 495 395 490 330 540 245 Z" fill="url(#flame)" filter="url(#soft)"/>
      <path d="M540 300 C 562 350 560 390 540 405 C 520 390 518 350 540 300 Z" fill="#fffdf2" opacity=".9"/>
      <line x1="540" y1="400" x2="540" y2="440" stroke="#2a1a0c" stroke-width="6"/>
      <rect x="485" y="438" width="110" height="380" rx="10" fill="url(#wax)"/>
      <path d="M485 448 q 20 40 8 90 q 10 -40 22 -70 z" fill="#f6ecd6" opacity=".7"/>
      <ellipse cx="540" cy="830" rx="190" ry="34" fill="#3b2a18"/>
      <ellipse cx="540" cy="822" rx="170" ry="24" fill="#8a6a3e"/>
      <ellipse cx="540" cy="816" rx="120" ry="14" fill="#b38b52" opacity=".8"/>
    </svg></div></div>`;
}

(async () => {
  const browser = await chromium.launch();
  const tab = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
  for (const [ci, c] of data.entries()) {
    const dir = path.join(out, c.id);
    fs.mkdirSync(dir, { recursive: true });
    for (const [i, html] of (c.facts ? factSlides : slides)(c, ci).entries()) {
      await tab.setContent(page(html), { waitUntil: 'load' });
      await tab.evaluate(() => document.fonts.ready);
      await tab.screenshot({ path: path.join(dir, `${String(i + 1).padStart(2, '0')}.png`) });
    }
    console.log(c.id, 'ok');
  }
  if (process.env.FICHIER === 'faits.json') {
    await tab.setViewportSize({ width: 1080, height: 1080 });
    await tab.setContent(page(avatar()), { waitUntil: 'load' });
    await tab.screenshot({ path: path.join(out, 'photo-de-profil.png') });
    console.log('photo-de-profil ok');
  }
  await browser.close();
})();
