/* --- Dos des cartes et emblème Brainlix (identité : dégradé violet, jaune soleil, trait de cinq, couleurs des domaines) --- */
const BX={violet:'#7B5CFF',violet2:'#3A1FB8',sun:'#FFD23F',ink:'#1A1830',
  doms:['#2F6BFF','#F0588F','#0CA678','#F76707','#1098AD','#845EF7','#D6336C','#E5383B','#5F3DC4','#FCC419','#1C7ED6','#37B24D']};
/* le trait de cinq : quatre bâtons et une diagonale, centré en (x,y), hauteur h */
function tally(x,y,h,col,diag,w){w=w||h*.13;const g=h*.22;let s='';
  for(let i=0;i<4;i++){const xx=x-1.5*g+i*g;s+=`<line x1="${xx.toFixed(1)}" y1="${(y-h/2).toFixed(1)}" x2="${xx.toFixed(1)}" y2="${(y+h/2).toFixed(1)}" stroke="${col}" stroke-width="${w.toFixed(1)}" stroke-linecap="round"/>`;}
  return s+`<line x1="${(x-2.2*g).toFixed(1)}" y1="${(y+h*.32).toFixed(1)}" x2="${(x+2.2*g).toFixed(1)}" y2="${(y-h*.32).toFixed(1)}" stroke="${diag}" stroke-width="${(w*1.05).toFixed(1)}" stroke-linecap="round"/>`;}
const wordmark=(x,y,size,col,ls=.18)=>`<text x="${x}" y="${y}" text-anchor="middle" font-family="Nunito, 'SF Pro Rounded', system-ui, sans-serif" font-weight="900" font-size="${size}" letter-spacing="${size*ls}" fill="${col}">BRAINLIX</text>`;
const domRing=(cx,cy,r,dot,o=1)=>BX.doms.map((c,i)=>{const a=-Math.PI/2+i/12*Math.PI*2;return `<circle cx="${(cx+r*Math.cos(a)).toFixed(1)}" cy="${(cy+r*Math.sin(a)).toFixed(1)}" r="${dot}" fill="${c}" opacity="${o}"/>`;}).join('');
let DOSN=0;
const DOS={
 classique:{name:'Classique',src:'Offert'},
 soleil:{name:'Soleil',src:'Pass gratuit · palier 10'},
 nuit:{name:'Nuit étoilée',src:'Pass gratuit · palier 30'},
 domaines:{name:'Les 12 domaines',src:'Pass payant · palier 5'},
 or:{name:'Feuille d\'or',src:'Pass payant · palier 40'},
 citrouille:{name:'Citrouille',src:'Événement d\'Halloween'}};
function cardBack(kind){const id='dos'+(++DOSN);kind=DOS[kind]?kind:'classique';
  const frame=(c1,c2)=>`<rect x="1" y="1" width="98" height="138" rx="9" fill="url(#${id}g)"/><linearGradient id="${id}g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>`;
  const border=(c,o=.55)=>`<rect x="5" y="5" width="90" height="130" rx="6.5" fill="none" stroke="${c}" stroke-width="1.2" opacity="${o}"/>`;
  const minis=(c,o)=>{let s='';for(let r=0;r<9;r++)for(let k=0;k<6;k++)s+=`<g opacity="${o}">${tally(10+k*16+(r%2)*8,12+r*15.5,6,c,c,.9)}</g>`;return s;};
  let b='';
  if(kind==='classique')b=frame(BX.violet,BX.violet2)+minis('#fff',.07)+border('#fff',.5)+`<circle cx="50" cy="64" r="27" fill="#fff" opacity=".1"/>`+domRing(50,64,31,2.4)+`<circle cx="50" cy="64" r="22" fill="${BX.violet2}" stroke="${BX.sun}" stroke-width="1.6"/>`+tally(50,64,22,'#fff',BX.sun,2.7)+wordmark(50,113,8.4,'#fff')+`<rect x="34" y="118" width="32" height="3" rx="1.5" fill="${BX.sun}"/>`;
  if(kind==='soleil')b=frame('#FFE680','#FFB915')+minis(BX.violet2,.08)+border(BX.violet2,.35)+[...Array(16)].map((_,i)=>{const a=i/16*Math.PI*2;return `<line x1="${(50+30*Math.cos(a)).toFixed(1)}" y1="${(64+30*Math.sin(a)).toFixed(1)}" x2="${(50+38*Math.cos(a)).toFixed(1)}" y2="${(64+38*Math.sin(a)).toFixed(1)}" stroke="#fff" stroke-width="2.4" stroke-linecap="round" opacity=".75"/>`;}).join('')+`<circle cx="50" cy="64" r="23" fill="#fff" stroke="${BX.violet2}" stroke-width="1.4"/>`+tally(50,64,22,BX.violet,BX.violet2,2.7)+wordmark(50,116,8.4,BX.violet2);
  if(kind==='nuit'){let r=7,st='';for(let i=0;i<46;i++){r=(r*9301+49297)%233280;const x=6+r/233280*88;r=(r*9301+49297)%233280;const y=6+r/233280*128;st+=`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(.4+(r%3)*.35).toFixed(2)}" fill="${i%5?'#fff':BX.sun}" opacity=".85"/>`;}
    b=frame('#1B1A4A','#07061A')+st+border('#E9C566',.6)+`<path d="M62,40 C50,42 44,54 46,64 C48,76 60,84 72,82 C62,80 56,72 56,62 C56,52 60,44 62,40 Z" fill="#F6E7B8" opacity=".15"/>`+`<circle cx="50" cy="64" r="22" fill="none" stroke="#E9C566" stroke-width="1.4"/>`+tally(50,64,22,'#F6E7B8','#E9C566',2.7)+wordmark(50,113,8.4,'#E9C566');}
  if(kind==='domaines')b=frame('#fff','#fff')+`<clipPath id="${id}c"><rect x="1" y="1" width="98" height="138" rx="9"/></clipPath><g clip-path="url(#${id}c)">${BX.doms.map((c,i)=>`<path d="M${-60+i*14},140 L${10+i*14},0 L${24+i*14},0 L${-46+i*14},140 Z" fill="${c}"/>`).join('')}</g>`+border('#fff',.8)+`<circle cx="50" cy="64" r="25" fill="#fff"/><circle cx="50" cy="64" r="25" fill="none" stroke="${BX.ink}" stroke-width="1"/>`+tally(50,64,22,BX.violet,BX.sun,2.7)+`<rect x="22" y="104" width="56" height="15" rx="7.5" fill="#fff"/>`+wordmark(50,115,7.6,BX.ink);
  if(kind==='or')b=frame('#FFF1C2','#B8862A')+`<path d="M0,0 L40,0 L-30,140 L-70,140 Z" fill="#fff" opacity=".25"/>`+[...Array(8)].map((_,i)=>`<circle cx="50" cy="64" r="${10+i*6}" fill="none" stroke="#7A4A08" stroke-width=".5" opacity=".35"/>`).join('')+border('#7A4A08',.6)+`<circle cx="50" cy="64" r="22" fill="#F6D98A" stroke="#7A4A08" stroke-width="1.4"/>`+tally(50,64,22,'#7A4A08','#3A2408',2.7)+wordmark(50,113,8.4,'#5A3408');
  if(kind==='citrouille'){const bat=(x,y,s)=>`<path transform="translate(${x} ${y}) scale(${s})" d="M0,0 C-2,-3 -5,-3 -7,-1 C-9,-4 -13,-4 -15,0 C-12,0 -10,2 -10,4 C-8,2 -5,3 -4,5 C-3,3 -1,3 0,5 C1,3 3,3 4,5 C5,3 8,2 10,4 C10,2 12,0 15,0 C13,-4 9,-4 7,-1 C5,-3 2,-3 0,0 Z" fill="#2B1636"/>`;
    b=frame('#FF9A3C','#B8460A')+border('#2B1636',.5)+bat(22,22,.8)+bat(80,30,.6)+bat(72,118,.7)+`<path d="M50,44 C36,42 26,52 26,64 C26,78 36,86 50,85 C64,86 74,78 74,64 C74,52 64,42 50,44 Z" fill="#F76707" stroke="#2B1636" stroke-width="1.4"/>`+`<path d="M49,44 C49,39 51,37 54,36" fill="none" stroke="#2F7D55" stroke-width="2.4" stroke-linecap="round"/>`+tally(50,66,16,'#2B1636','#FFD23F',2.4)+wordmark(50,113,8.4,'#2B1636');}
  return `<svg viewBox="0 0 100 140" aria-hidden="true">${b}</svg>`;}
/* emblème rond (couverture d'album) */
function emblem(size){return `<svg viewBox="0 0 120 120" width="${size}" aria-hidden="true"><defs><linearGradient id="emb" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${BX.violet}"/><stop offset="1" stop-color="${BX.violet2}"/></linearGradient></defs>
  ${domRing(60,60,54,4.4)}<rect x="22" y="22" width="76" height="76" rx="22" fill="url(#emb)" stroke="#fff" stroke-width="2.4"/>${tally(60,60,38,'#fff',BX.sun,4.6)}</svg>`;}
