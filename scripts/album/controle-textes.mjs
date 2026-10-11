// Contrôle de toutes les cartes avec les vraies polices : textes coupés ou trop petits, chiffre qui touche l'image ou le texte, dessin qui touche l'en-tête.
// python3 scripts/album/planche.py . $(ls content/album/*.json | xargs -n1 basename | sed 's/.json//') /tmp/toutes.html
// node scripts/album/controle-textes.mjs /tmp/toutes.html   (nécessite playwright)
import { chromium } from 'playwright';
const b = await chromium.launch(); const errs=[]; const bad=[];
for (const vw of [1000,390]) {
  const ctx = await b.newContext({viewport:{width:vw,height:900}}); const p=await ctx.newPage(); p.on('pageerror', e=>errs.push(e.message));
  let okF=false;for(let t=0;t<4&&!okF;t++){await p.goto('file://'+(await import('node:path')).resolve(process.argv[2])); await p.waitForTimeout(1500); await p.evaluate(()=>document.fonts.ready);
    okF=await p.evaluate(()=>['900 20px "Big Shoulders Display"','800 20px "Nunito"','800 20px "Fraunces"'].every(f=>document.fonts.check(f)));}
  if(!okF) errs.push('polices non chargées');
  const n = await p.locator('#pages button').count();
  for (let i=0;i<n;i++){ await p.click(`#pages button[data-i="${i}"]`); await p.waitForTimeout(150);
    const r = await p.evaluate(()=>[...document.querySelectorAll('#deck .card')].map(c=>{
      const q=s=>c.querySelector(s), R=e=>e.getBoundingClientRect();
      const fig=q('.fig'),unit=q('.unit'),art=q('.art'),band=q('.band'),fs=parseFloat(getComputedStyle(fig).fontSize);
      const pb=parseFloat(getComputedStyle(fig).paddingTop), fb=R(fig), top=fb.top+pb, inner=fb.bottom-parseFloat(getComputedStyle(fig).paddingBottom);
      const pbs=[];
      if(c.dataset.overflow==='1')pbs.push('COUPÉ');else if(c.dataset.small==='1')pbs.push('petit');
      if(top-fs*.04<R(art).bottom)pbs.push('chiffre touche l\'image');
      if(fb.right-parseFloat(getComputedStyle(fig).paddingRight)>R(band).right+1)pbs.push('chiffre trop large');
      if(band.classList.contains('stack')&&R(unit).top<inner+fs*.12)pbs.push('chiffre touche l\'unité');
      if(c.classList.contains('r-legend')){const g=c.querySelector('.subj g[transform]');if(g&&R(g).top<R(q('.hd')).bottom-1)pbs.push('image touche l\'en-tête');}
      const nmB=R(q('.nm'));if(R(art).bottom>nmB.top&&R(art).top<nmB.bottom)pbs.push('image sur le nom');
      return pbs.length?pbs.join('+')+' '+c.getAttribute('aria-label').split(',')[0]:'';}).filter(Boolean));
    const t = await p.evaluate(()=>document.querySelector('#pages button[aria-pressed="true"]').textContent);
    if (r.length) bad.push(vw+' '+t+' : '+r.join(' | '));
  }
  await ctx.close();
}
console.log(bad.join('\n')||'aucun défaut de texte', '\nerreurs', errs); await b.close();
