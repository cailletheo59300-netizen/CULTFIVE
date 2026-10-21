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

// Compte 2, style « carnet » : page de cahier (papier crème, lignes, marge rouge), titre manuscrit, texte machine à écrire,
// mots clés au surligneur. Un fait par page, puis l'appli conseillée, scotchée sur la dernière page.
const caveat = asset('polices/caveat.ttf');
const courier = asset('polices/courierprime-400.ttf');
const courierBold = asset('polices/courierprime-700.ttf');
const notebookCss = `
  @font-face { font-family: Caveat; src: url(${caveat}); font-weight: 400 700; }
  @font-face { font-family: Courier; src: url(${courier}); font-weight: 400; }
  @font-face { font-family: Courier; src: url(${courierBold}); font-weight: 700; }
  .paper { position: absolute; inset: 0; background-color: #f5eedc;
           background-image: linear-gradient(90deg, transparent 118px, rgba(214,72,72,.55) 118px, rgba(214,72,72,.55) 121px, transparent 121px),
                             repeating-linear-gradient(180deg, transparent 0 70px, rgba(70,110,170,.22) 70px 72px); }
  .paper::after { content: ''; position: absolute; inset: 0; box-shadow: inset 0 0 160px rgba(120,90,40,.28); }
  .page { position: absolute; inset: 0; padding: 230px 96px 0 170px; color: #1f2430; }
  .page.mid { display: flex; flex-direction: column; justify-content: center; padding-top: 0; }
  .pnum { position: absolute; top: 96px; right: 100px; font: 700 60px Caveat, cursive; color: #2b4a8b; transform: rotate(-4deg); }
  .hand { font: 700 132px/1.02 Caveat, cursive; color: #1d2f5e; }
  .hand.big { font-size: 150px; }
  .typed { margin-top: 64px; font: 400 47px/1.55 Courier, monospace; }
  .typed b, .hand b { font-weight: 700; background: linear-gradient(transparent 52%, rgba(255,222,60,.85) 52%, rgba(255,222,60,.85) 92%, transparent 92%);
                      padding: 0 6px; margin: 0 -6px; }
  .scribble { display: block; margin-top: 18px; }
  .note { position: absolute; bottom: 210px; right: 110px; font: 700 64px Caveat, cursive; color: #2b4a8b; transform: rotate(-3deg); }
  .grain { position: absolute; inset: 0; pointer-events: none; }
  .taped { position: relative; display: inline-block; margin: 70px 0 30px 40px; transform: rotate(-4deg); }
  .taped img { width: 300px; height: 300px; border-radius: 66px; box-shadow: 0 14px 30px rgba(60,40,10,.35); display: block; }
  .tape { position: absolute; width: 170px; height: 52px; background: rgba(240,228,180,.75); box-shadow: 0 2px 4px rgba(0,0,0,.08); }
  .store { font: 700 50px Courier, monospace; margin-top: 30px; }
`;
const grain = (seed) => `<svg class="grain" width="1080" height="1920" xmlns="http://www.w3.org/2000/svg">
  <filter id="pg${seed}"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="${seed}"/>
  <feColorMatrix values="0 0 0 0 .45  0 0 0 0 .38  0 0 0 0 .25  0 0 0 .13 0"/></filter>
  <rect width="1080" height="1920" filter="url(#pg${seed})"/></svg>`;
// Trait à main levée sous un titre (vague légère, deux passages de stylo).
const underline = (w) => `<svg class="scribble" width="${w}" height="40" viewBox="0 0 ${w} 40" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 22 C ${w * .25} 8, ${w * .5} 34, ${w * .75} 16 S ${w - 20} 20, ${w - 6} 14" fill="none" stroke="#d64848" stroke-width="7" stroke-linecap="round"/>
  <path d="M30 30 C ${w * .3} 20, ${w * .6} 36, ${w - 40} 26" fill="none" stroke="#d64848" stroke-width="4" stroke-linecap="round" opacity=".7"/></svg>`;
const marks = (t) => esc(t).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
const sheet = (seed, inner) => `<style>${notebookCss}</style><div class="slide"><div class="paper"></div>${grain(seed)}${inner}</div>`;

function factSlides(c, ci) {
  const s = [];
  const seed = (n) => ci * 40 + n;
  s.push(sheet(seed(1), `<div class="page mid"><div class="hand big">${marks(c.hook)}</div>${underline(620)}</div>
    <div class="note">swipe →</div>`));
  c.facts.forEach((f, i) => {
    s.push(sheet(seed(10 + i), `<div class="pnum">${i + 1}/${c.facts.length}</div><div class="page mid">
      <div class="hand">${marks(f.title)}</div>${underline(Math.min(860, 120 + f.title.length * 38))}
      <div class="typed">${marks(f.text)}</div></div>`));
  });
  s.push(sheet(seed(30), `<div class="page mid"><div class="hand">${marks(c.plug)}</div>
    <div class="taped"><img src="${icon}"><div class="tape" style="top:-22px;left:-40px;transform:rotate(-28deg)"></div>
    <div class="tape" style="bottom:-20px;right:-46px;transform:rotate(-24deg)"></div></div>
    <div class="store">Brainlix<br>gratuit sur l'App Store</div></div>`));
  return s;
}

// Photo de profil (1080 × 1080) du compte 2 : une ampoule dessinée au stylo sur une page de cahier, sans marque.
function avatar() {
  return `<style>${notebookCss}</style><div class="slide" style="width:1080px;height:1080px"><div class="paper"></div>${grain(5)}
    <svg style="position:absolute;inset:0" width="1080" height="1080" viewBox="0 0 1080 1080" xmlns="http://www.w3.org/2000/svg">
      <filter id="ink"><feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="3"/><feDisplacementMap in="SourceGraphic" scale="7"/></filter>
      <ellipse cx="560" cy="470" rx="200" ry="70" fill="rgba(255,222,60,.8)" transform="rotate(-6 560 470)"/>
      <g filter="url(#ink)" fill="none" stroke="#1d2f5e" stroke-width="16" stroke-linecap="round" stroke-linejoin="round">
        <path d="M540 230 C 410 230 340 330 360 440 C 375 520 450 560 460 640 L 620 640 C 630 560 705 520 720 440 C 740 330 670 230 540 230 Z"/>
        <path d="M470 690 L 610 690 M 480 740 L 600 740 M 505 790 L 575 790"/>
        <path d="M500 640 L 520 470 L 560 520 L 580 470 L 580 640" stroke-width="10"/>
        <path d="M540 130 L 540 175 M 360 190 L 390 225 M 720 190 L 690 225 M 250 360 L 295 375 M 830 360 L 785 375"/>
      </g>
    </svg></div>`;
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
