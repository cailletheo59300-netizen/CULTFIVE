// Contrôle des textes de toutes les cartes (coupés ou trop petits), sur ordinateur et téléphone.
// python3 scripts/album/planche.py . $(ls content/album/*.json | xargs -n1 basename | sed 's/.json//') /tmp/toutes.html
// node scripts/album/controle-textes.mjs /tmp/toutes.html   (nécessite playwright)
import { chromium } from 'playwright';
const b = await chromium.launch(); const errs=[]; const bad=[];
for (const vw of [1000,390]) {
  const p = await b.newPage({viewport:{width:vw,height:900}}); p.on('pageerror', e=>errs.push(e.message));
  await p.goto('file://'+(await import('node:path')).resolve(process.argv[2])); await p.waitForTimeout(1000);
  const n = await p.locator('#pages button').count();
  for (let i=0;i<n;i++){ await p.click(`#pages button[data-i="${i}"]`); await p.waitForTimeout(150);
    const r = await p.evaluate(()=>[...document.querySelectorAll('#deck .card')].filter(c=>c.dataset.overflow==='1'||c.dataset.small==='1').map(c=>(c.dataset.overflow==='1'?'COUPÉ ':'petit ')+c.getAttribute('aria-label').split(',')[0]));
    const t = await p.evaluate(()=>document.querySelector('#pages button[aria-pressed="true"]').textContent);
    if (r.length) bad.push(vw+' '+t+' : '+r.join(' | '));
  }
}
console.log(bad.join('\n')||'aucun texte coupé', '\nerreurs', errs); await b.close();
