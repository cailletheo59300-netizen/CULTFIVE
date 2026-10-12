// Icônes 3D des récompenses du pass, dans le style des icônes de l'app (scripts/icons/icons.html).
// Chargé par-dessus icons.html (qui fournit THREE, phys, metal, extrude, rbox, canvasTex, ticket, ribbonMesh, flameShape, snap)
// et dos.js (cardBack). Lancé par scripts/album/pass-icons.mjs.
const C=(hex)=>new THREE.Color(hex);
function imgTex(svg,w,h){return new Promise(res=>{const im=new Image();im.onload=()=>{const c=document.createElement('canvas');c.width=w;c.height=h;c.getContext('2d').drawImage(im,0,0,w,h);
  const t=new THREE.CanvasTexture(c);t.encoding=THREE.sRGBEncoding;t.anisotropy=4;res(t);};im.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg.replace('<svg ','<svg xmlns="http://www.w3.org/2000/svg" '));});}
const rr=(c,x,y,w,h,r)=>{c.beginPath();c.moveTo(x+r,y);c.arcTo(x+w,y,x+w,y+h,r);c.arcTo(x+w,y+h,x,y+h,r);c.arcTo(x,y+h,x,y,r);c.arcTo(x,y,x+w,y,r);c.closePath();};
/* une petite carte de l'album (face) dessinée à plat */
function cardFace(c,W,H,opt={}){const p=W*.07;
  c.fillStyle=opt.paper||'#FBF4E8';rr(c,0,0,W,H,W*.06);c.fill();
  c.fillStyle=opt.art||'#F1E4CC';rr(c,p,p*1.6,W-2*p,H*.42,W*.04);c.fill();
  c.fillStyle=opt.medal||'#FFF8EA';c.beginPath();c.arc(W/2,p*1.6+H*.21,H*.15,0,Math.PI*2);c.fill();
  c.strokeStyle=opt.ink||'#7B5CFF';c.lineWidth=W*.025;c.lineCap='round';c.lineJoin='round';
  c.beginPath();c.moveTo(W*.38,p*1.6+H*.28);c.lineTo(W*.5,p*1.6+H*.12);c.lineTo(W*.62,p*1.6+H*.28);c.stroke();
  c.fillStyle=opt.ink||'#7B5CFF';rr(c,p,H*.58,W*.5,H*.07,H*.02);c.fill();
  c.fillStyle='#C8BFA8';rr(c,p,H*.7,W-2*p,H*.035,H*.017);c.fill();rr(c,p,H*.77,W*.62,H*.035,H*.017);c.fill();
  c.fillStyle=opt.gem||'#B9AC98';c.beginPath();c.arc(W-p*1.6,H-p*1.6,W*.035,0,Math.PI*2);c.fill();}
/* carte en volume : cadre (matière) + face (texture) */
function card3d(frameMat,faceTex,o={}){const g=new THREE.Group();const w=1.26,h=1.76;
  g.add(new THREE.Mesh(rbox(w,h,.08,.1),frameMat));
  const face=new THREE.Mesh(new THREE.PlaneGeometry(w-(o.border??.14),h-(o.border??.14)),new THREE.MeshStandardMaterial({map:faceTex,roughness:.5,transparent:true}));face.position.z=.046;g.add(face);
  if(o.back){const b=new THREE.Mesh(new THREE.PlaneGeometry(w-.14,h-.14),new THREE.MeshStandardMaterial({map:o.back,roughness:.5}));b.position.z=-.046;b.rotation.y=Math.PI;g.add(b);}
  return g;}
const faceTex=(opt)=>canvasTex(256,356,(c,W,H)=>cardFace(c,W,H,opt));
const spark=(s,col)=>{const sh=new THREE.Shape();const r=s,q=s*.28;sh.moveTo(0,r);sh.quadraticCurveTo(q*.3,q*.3,r,0);sh.quadraticCurveTo(q*.3,-q*.3,0,-r);sh.quadraticCurveTo(-q*.3,-q*.3,-r,0);sh.quadraticCurveTo(-q*.3,q*.3,0,r);
  return new THREE.Mesh(extrude(sh,.04,.015),phys(col,{emissive:col,emissiveIntensity:.35,roughness:.2}));};
const star5=(R,r)=>{const s=new THREE.Shape();for(let i=0;i<=10;i++){const a=Math.PI/2+i/10*Math.PI*2,rad=i%2?r:R;i?s.lineTo(Math.cos(a)*rad,Math.sin(a)*rad):s.moveTo(Math.cos(a)*rad,Math.sin(a)*rad);}return s;};
const VIOLET=0x7B5CFF,DEEP=0x3A1FB8,SUN=0xFFD23F,GOLD=0xFFC933;

/* ---------- les récompenses ---------- */
const TPACK=()=>ticket(0x7B5CFF,'#C9BCFF','#24127A',(c,x,y)=>{ // ticket de pochette : un petit sachet
  c.fillStyle='#fff';rr(c,x-46,y-70,92,140,12);c.fill();c.fillStyle='#7B5CFF';rr(c,x-38,y-58,76,116,8);c.fill();
  c.fillStyle='#FFD23F';c.beginPath();for(let i=0;i<9;i++){c.rect(x-40+i*10,y-74,6,8);c.rect(x-40+i*10,y+66,6,8);}c.fill();
  c.strokeStyle='#fff';c.lineWidth=7;c.lineCap='round';for(let i=0;i<4;i++){c.beginPath();c.moveTo(x-18+i*12,y-20);c.lineTo(x-18+i*12,y+22);c.stroke();}
  c.strokeStyle='#FFD23F';c.beginPath();c.moveTo(x-26,y+14);c.lineTo(x+26,y-12);c.stroke();});
function JETON(){const g=new THREE.Group();
  const tex=canvasTex(512,512,(c,W,H)=>{const gr=c.createConicGradient?c.createConicGradient(0,W/2,H/2):null;
    if(gr){['#FF6A88','#F6C744','#3FD0A0','#4A9BFF','#B66BFF','#FF6A88'].forEach((col,i)=>gr.addColorStop(i/5,col));c.fillStyle=gr;}else c.fillStyle='#B66BFF';
    c.beginPath();c.arc(W/2,H/2,W/2,0,Math.PI*2);c.fill();
    c.fillStyle='rgba(18,14,34,.82)';c.beginPath();c.arc(W/2,H/2,W*.36,0,Math.PI*2);c.fill();
    c.fillStyle='#FFE9A6';c.beginPath();for(let i=0;i<=10;i++){const a=-Math.PI/2+i/10*Math.PI*2,r=i%2?W*.11:W*.26;i?c.lineTo(W/2+Math.cos(a)*r,H/2+Math.sin(a)*r):c.moveTo(W/2+Math.cos(a)*r,H/2+Math.sin(a)*r);}c.fill();});
  const coin=new THREE.Mesh(new THREE.CylinderGeometry(.9,.9,.16,64),metal(GOLD,.22));coin.rotation.x=Math.PI/2;g.add(coin);
  const face=new THREE.Mesh(new THREE.CircleGeometry(.8,64),new THREE.MeshStandardMaterial({map:tex,roughness:.25,metalness:.3,emissive:0xffffff,emissiveMap:tex,emissiveIntensity:.18}));face.position.z=.082;g.add(face);
  const rim=new THREE.Mesh(new THREE.TorusGeometry(.86,.05,12,64),metal(0xFFE27A,.15));rim.position.z=.08;g.add(rim);
  [[.95,.75,.14],[-.95,-.55,.11],[.8,-.85,.08]].forEach(([x,y,s])=>{const sp=spark(s,0xFFFFFF);sp.position.set(x,y,.2);g.add(sp);});
  g.rotation.set(-.12,-.4,0);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
async function PDOS(kind){const tex=await imgTex(cardBack(kind),300,420);const g=card3d(phys(0xffffff,{roughness:.4}),tex,{border:.04});
  g.rotation.set(-.08,-.42,.1);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
const PFRAMES={
  citrouille:{mat:()=>phys(0xF76707,{roughness:.4}),deco:g=>{const p=new THREE.Mesh(new THREE.SphereGeometry(.22,32,16),phys(0xFF8A1F,{roughness:.35}));p.scale.set(1.15,.9,1);p.position.set(-.6,.9,.12);g.add(p);
      const st=new THREE.Mesh(new THREE.CylinderGeometry(.03,.04,.14,12),phys(0x2F7D55));st.position.set(-.6,1.1,.12);g.add(st);}},
  vitrail:{mat:()=>new THREE.MeshStandardMaterial({map:canvasTex(256,356,(c,W,H)=>{const cols=['#E8443A','#3C6FF0','#FFD23F','#12B76A','#8B5CF6','#F28C3A'];let k=0;for(let y=0;y<H;y+=34)for(let x=0;x<W;x+=34){c.fillStyle=cols[(k++*7)%6];c.fillRect(x,y,34,34);}
      c.strokeStyle='#1A1830';c.lineWidth=4;for(let y=0;y<=H;y+=34){c.beginPath();c.moveTo(0,y);c.lineTo(W,y);c.stroke();}for(let x=0;x<=W;x+=34){c.beginPath();c.moveTo(x,0);c.lineTo(x,H);c.stroke();}}),roughness:.25})},
  nuit:{mat:()=>new THREE.MeshStandardMaterial({map:canvasTex(256,356,(c,W,H)=>{c.fillStyle='#1B1A4A';c.fillRect(0,0,W,H);const r=mulberry(3);for(let i=0;i<60;i++){c.fillStyle=i%6?'#fff':'#FFD23F';c.beginPath();c.arc(r()*W,r()*H,.8+r()*2,0,Math.PI*2);c.fill();}}),roughness:.3})},
  marbre:{mat:()=>new THREE.MeshStandardMaterial({map:canvasTex(256,356,(c,W,H)=>{c.fillStyle='#F4F1EA';c.fillRect(0,0,W,H);const r=mulberry(9);c.fillStyle='#E6E1D8';c.fillRect(0,0,W,H);c.strokeStyle='#8F887C';for(let i=0;i<12;i++){c.globalAlpha=.35+r()*.45;c.lineWidth=1+r()*3;c.beginPath();let x=r()*W,y=0;c.moveTo(x,y);while(y<H){x+=(r()-.5)*40;y+=20+r()*30;c.lineTo(x,y);}c.stroke();}}),roughness:.18})},
  toile:{mat:()=>new THREE.MeshStandardMaterial({map:canvasTex(256,356,(c,W,H)=>{c.fillStyle='#4A4A5C';c.fillRect(0,0,W,H);c.strokeStyle='#DADAE6';c.lineWidth=2;const cx=0,cy=0;for(let i=0;i<8;i++){const a=i/16*Math.PI;c.beginPath();c.moveTo(cx,cy);c.lineTo(Math.cos(a)*600,Math.sin(a)*600);c.stroke();}
      for(let r=40;r<500;r+=44){c.beginPath();for(let i=0;i<=8;i++){const a=i/16*Math.PI;const x=Math.cos(a)*r,y=Math.sin(a)*r;i?c.quadraticCurveTo(Math.cos(a-Math.PI/32)*r*.9,Math.sin(a-Math.PI/32)*r*.9,x,y):c.moveTo(x,y);}c.stroke();}}),roughness:.4})}};
function CADRE(kind){const f=PFRAMES[kind];const g=card3d(f.mat(),faceTex({}),{border:.26});if(f.deco)f.deco(g);g.rotation.set(-.08,-.42,.08);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
const PFINS={givre:{paper:'#EAF6FF',art:'#CFE9FA',ink:'#3C8FD0',spark:0xBFE6FF},or:{paper:'#FFF4D2',art:'#F6DA8C',ink:'#9C6412',spark:0xFFD23F},holo:{paper:'#F6EEFF',art:'#E4D6FF',ink:'#8B5CF6',spark:0xFF8FB1}};
function FINITION(kind){const f=PFINS[kind];const tex=canvasTex(256,356,(c,W,H)=>{cardFace(c,W,H,f);
    if(kind==='holo'){const gr=c.createLinearGradient(0,0,W,H);['#FF6A88','#F6C744','#3FD0A0','#4A9BFF','#B66BFF'].forEach((col,i)=>gr.addColorStop(i/4,col));c.globalAlpha=.35;c.fillStyle=gr;c.fillRect(0,0,W,H);c.globalAlpha=1;}
    if(kind==='givre'){c.strokeStyle='rgba(255,255,255,.95)';c.lineWidth=2;[[0,0,.8],[W,0,2.35],[0,H,-.8],[W,H,-2.35]].forEach(([x,y,a])=>{for(let k=-1;k<=1;k++){const b=a+k*.4;c.beginPath();c.moveTo(x,y);c.lineTo(x+Math.cos(b)*60,y+Math.sin(b)*60);c.stroke();}});}
    if(kind==='or'){const r=mulberry(4);c.fillStyle='#FFD23F';for(let i=0;i<70;i++){c.globalAlpha=.5+r()*.5;c.beginPath();c.arc(r()*W,r()*H,1+r()*2.5,0,Math.PI*2);c.fill();}c.globalAlpha=1;}});
  const g=card3d(kind==='or'?metal(GOLD,.25):phys(kind==='givre'?0xBFE6FF:0xD9C8FF,{roughness:.2}),tex);
  [[.62,.82,.16],[-.66,.35,.12],[.5,-.75,.1],[-.4,-.9,.08]].forEach(([x,y,s])=>{const sp=spark(s,f.spark);sp.position.set(x,y,.14);g.add(sp);});
  g.rotation.set(-.08,-.42,.08);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function splitTitle(t){if(t.length<=12)return [t];const sp=[...t.matchAll(/ /g)].map(m=>m.index);let best=sp[0];sp.forEach(i=>{if(Math.abs(i-t.length/2)<Math.abs(best-t.length/2))best=i;});return [t.slice(0,best),t.slice(best+1)];}
const ribW=t=>{const L=splitTitle(t);return Math.max(2.1,Math.max(...L.map(x=>x.length))*.15+.7);};
function ribbon2(text,color){const L=splitTitle(text),w=ribW(text),h=L.length>1?1.02:.62;const g=new THREE.Group();
  const sh=new THREE.Shape();sh.moveTo(-w/2,-h/2);sh.lineTo(w/2,-h/2);sh.lineTo(w/2-.18,0);sh.lineTo(w/2,h/2);sh.lineTo(-w/2,h/2);sh.lineTo(-w/2+.18,0);sh.lineTo(-w/2,-h/2);
  g.add(new THREE.Mesh(extrude(sh,.07,.03),phys(color,{roughness:.4})));
  const H=Math.round(280*h/.62),W=Math.round(1024*w/2.3);
  const tex=canvasTex(W,H,(c)=>{c.textAlign='center';c.textBaseline='middle';const ft=n=>`900 ${n}px Nunito, Arial Black, sans-serif`;let size=200;c.font=ft(size);
    while(L.some(x=>c.measureText(x).width>W*.84)&&size>40){size-=4;c.font=ft(size);}
    L.forEach((x,i)=>{const y=L.length>1?H*(i?.72:.3):H/2;c.fillStyle='rgba(0,0,0,.22)';c.fillText(x,W/2,y+10);c.fillStyle='#fff';c.fillText(x,W/2,y+4);});});
  const lab=new THREE.Mesh(new THREE.PlaneGeometry(w*.86,h*.92),new THREE.MeshBasicMaterial({map:tex,transparent:true}));lab.position.z=.07;g.add(lab);return g;}
function TITRE(text,color){const g=new THREE.Group();const w0=ribW(text);const rb=ribbon2(text,color);g.add(rb);
  const tail=(s)=>{const sh=new THREE.Shape();sh.moveTo(0,0);sh.lineTo(.42*s,0);sh.lineTo(.32*s,-.16);sh.lineTo(.42*s,-.32);sh.lineTo(0,-.32);sh.lineTo(0,0);const m=new THREE.Mesh(extrude(sh,.04,.015),phys(new THREE.Color(color).multiplyScalar(.7).getHex(),{roughness:.5}));m.position.set(s*(w0/2-.07),-.08,-.06);m.scale.set(1,1.5,1);return m;};
  g.add(tail(1));g.add(tail(-1));g.rotation.set(-.1,-.28,.05);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function TITREJ(text){const g=new THREE.Group();const rb=ribbon2(text,DEEP);rb.position.y=-.38;g.add(rb);
  const av=new THREE.Mesh(new THREE.CylinderGeometry(.42,.42,.14,48),phys(VIOLET,{roughness:.25}));av.rotation.x=Math.PI/2;av.position.y=.45;g.add(av);
  const ring=new THREE.Mesh(new THREE.TorusGeometry(.42,.06,12,48),metal(GOLD,.2));ring.position.set(0,.45,.02);g.add(ring);
  const st=new THREE.Mesh(extrude(star5(.24,.1),.08,.03),metal(0xFFE27A,.15));st.position.set(0,.45,.1);g.add(st);
  g.rotation.set(-.08,-.3,0);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
const PSTICK={s1:(c,W)=>{c.fillStyle='#fff';c.font='900 150px Nunito, Arial Black, sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('S1',W/2,W/2+8);},
  star:(c,W)=>{c.fillStyle='#FFD23F';c.beginPath();for(let i=0;i<=10;i++){const a=-Math.PI/2+i/10*Math.PI*2,r=i%2?W*.13:W*.3;i?c.lineTo(W/2+Math.cos(a)*r,W/2+Math.sin(a)*r):c.moveTo(W/2+Math.cos(a)*r,W/2+Math.sin(a)*r);}c.fill();},
  pumpkin:(c,W)=>{c.fillStyle='#FFB020';c.beginPath();c.ellipse(W/2,W*.55,W*.27,W*.22,0,0,Math.PI*2);c.fill();c.strokeStyle='#C25A00';c.lineWidth=8;[-.1,0,.1].forEach(d=>{c.beginPath();c.ellipse(W/2+d*W,W*.55,W*.08,W*.21,0,0,Math.PI*2);c.stroke();});c.fillStyle='#2F7D55';c.fillRect(W*.48,W*.24,W*.05,W*.1);
    c.fillStyle='#3A1A00';c.beginPath();c.moveTo(W*.4,W*.5);c.lineTo(W*.45,W*.44);c.lineTo(W*.47,W*.52);c.fill();c.beginPath();c.moveTo(W*.6,W*.5);c.lineTo(W*.55,W*.44);c.lineTo(W*.53,W*.52);c.fill();c.fillRect(W*.42,W*.6,W*.16,W*.04);},
  bat:(c,W)=>{c.fillStyle='#fff';c.save();c.translate(W/2,W/2);c.scale(W/40,W/40);c.beginPath();c.moveTo(0,0);c.bezierCurveTo(-2,-3,-5,-3,-7,-1);c.bezierCurveTo(-9,-4,-13,-4,-15,0);c.bezierCurveTo(-12,0,-10,2,-10,4);c.bezierCurveTo(-8,2,-5,3,-4,5);c.bezierCurveTo(-3,3,-1,3,0,5);c.bezierCurveTo(1,3,3,3,4,5);c.bezierCurveTo(5,3,8,2,10,4);c.bezierCurveTo(10,2,12,0,15,0);c.bezierCurveTo(13,-4,9,-4,7,-1);c.bezierCurveTo(5,-3,2,-3,0,0);c.fill();c.restore();}};
function AUTOC(kind,color){const g=new THREE.Group();
  const tex=canvasTex(512,512,(c,W)=>{c.fillStyle='#fff';c.beginPath();c.arc(W/2,W/2,W/2,0,Math.PI*2);c.fill();c.fillStyle=color;c.beginPath();c.arc(W/2,W/2,W*.43,0,Math.PI*2);c.fill();
    c.fillStyle='rgba(255,255,255,.18)';c.beginPath();c.ellipse(W*.38,W*.3,W*.2,W*.1,-.6,0,Math.PI*2);c.fill();PSTICK[kind](c,W);});
  const d=new THREE.Mesh(new THREE.CylinderGeometry(.9,.9,.06,64),phys(0xffffff,{roughness:.35}));d.rotation.x=Math.PI/2;g.add(d);
  const f=new THREE.Mesh(new THREE.CircleGeometry(.88,64),new THREE.MeshStandardMaterial({map:tex,roughness:.3}));f.position.z=.032;g.add(f);
  // coin décollé
  g.rotation.set(-.15,-.35,-.18);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function SOCLE(kind){const g=new THREE.Group();
  const M={marbre:()=>new THREE.MeshStandardMaterial({map:PFRAMES.marbre.mat().map,roughness:.15}),or:()=>metal(GOLD,.2),neon:()=>phys(0x120E22,{roughness:.3})}[kind]();
  const base=new THREE.Mesh(new THREE.CylinderGeometry(1.0,1.08,.3,64),M);base.position.y=-.9;g.add(base);
  const top=new THREE.Mesh(new THREE.CylinderGeometry(.92,1.0,.12,64),M);top.position.y=-.7;g.add(top);
  if(kind==='neon'){[-.74,-1.05].forEach(y=>{const r=new THREE.Mesh(new THREE.TorusGeometry(y>-.8?.97:1.09,.025,8,64),new THREE.MeshStandardMaterial({color:0x5BF0FF,emissive:0x5BF0FF,emissiveIntensity:2.2}));r.rotation.x=Math.PI/2;r.position.y=y;g.add(r);});}
  const cd=card3d(phys(0xffffff,{roughness:.4}),faceTex({ink:'#7B5CFF'}));cd.scale.setScalar(.82);cd.position.y=.08;g.add(cd);
  g.rotation.set(.12,-.45,0);return {obj:g,cam:[0,.6,4.6,0,-.2,0]};}
const PCOVERS={automne:['#C2661F','#FFB020','leaf'],grimoire:['#3B1F5A','#E9C566','eye'],or:['#D9A441','#FFF1C2','tally']};
function COUV(kind){const [base,acc,motif]=PCOVERS[kind];const g=new THREE.Group();
  const tex=canvasTex(320,400,(c,W,H)=>{c.fillStyle=base;c.fillRect(0,0,W,H);c.fillStyle='rgba(0,0,0,.22)';c.fillRect(0,0,W*.12,H);c.strokeStyle=acc;c.lineWidth=6;rr(c,W*.2,H*.06,W*.72,H*.88,18);c.stroke();
    c.save();c.translate(W*.56,H*.45);c.fillStyle=acc;c.strokeStyle=acc;
    if(motif==='leaf'){for(let i=0;i<3;i++){c.save();c.rotate(-.8+i*.8);c.beginPath();c.ellipse(0,-46,22,48,0,0,Math.PI*2);c.fill();c.restore();}}
    if(motif==='eye'){c.lineWidth=8;c.beginPath();c.ellipse(0,0,70,38,0,0,Math.PI*2);c.stroke();c.beginPath();c.arc(0,0,22,0,Math.PI*2);c.fill();}
    if(motif==='tally'){c.lineWidth=12;c.lineCap='round';for(let i=0;i<4;i++){c.beginPath();c.moveTo(-36+i*24,-50);c.lineTo(-36+i*24,50);c.stroke();}c.beginPath();c.moveTo(-60,34);c.lineTo(60,-34);c.stroke();}
    c.restore();});
  const book=new THREE.Mesh(rbox(1.5,1.9,.34,.08),phys(new THREE.Color(base).multiplyScalar(.8).getHex(),{roughness:.5}));g.add(book);
  const pages=new THREE.Mesh(new THREE.BoxGeometry(1.4,1.8,.26),phys(0xFBF4E8,{roughness:.8}));pages.position.set(.06,0,0);g.add(pages);
  const cov=new THREE.Mesh(rbox(1.5,1.9,.06,.08),new THREE.MeshStandardMaterial({map:tex,roughness:kind==='or'?.25:.5,metalness:kind==='or'?.6:0}));cov.position.z=.19;g.add(cov);
  g.rotation.set(-.08,-.45,.06);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function COFFRET(){const g=new THREE.Group();
  [[-.42,.45,.28,0xCFE9FA],[0,.62,0,0xFBF4E8],[.42,.45,-.28,0xF6C2D8]].forEach(([x,y,a,col],i)=>{const cd=card3d(phys(col,{roughness:.4}),faceTex({ink:['#3C8FD0','#7B5CFF','#C2449A'][i]}));cd.scale.setScalar(.6);cd.position.set(x,y,-.05+i*.02);cd.rotation.z=a;g.add(cd);});
  const box=new THREE.Mesh(rbox(1.9,1.0,.7,.12),phys(0xC2449A,{roughness:.35}));box.position.y=-.35;g.add(box);
  const band=new THREE.Mesh(rbox(1.96,.22,.76,.06),metal(GOLD,.2));band.position.y=0;g.add(band);
  const lbl=new THREE.Mesh(new THREE.PlaneGeometry(1.2,.4),new THREE.MeshBasicMaterial({map:canvasTex(512,170,(c,W,H)=>{c.fillStyle='#fff';c.font='900 96px Nunito, Arial Black, sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('3 CARTES',W/2,H/2+6);}),transparent:true}));lbl.position.set(0,-.45,.36);g.add(lbl);
  g.rotation.set(.05,-.38,0);return {obj:g,cam:[0,.4,4.8,0,0,0]};}
function DOREE(){const g=new THREE.Group();
  const tex=canvasTex(300,450,(c,W,H)=>{const gr=c.createLinearGradient(0,0,W,H);gr.addColorStop(0,'#FFF1C2');gr.addColorStop(.45,'#D9A441');gr.addColorStop(.7,'#9C6412');gr.addColorStop(1,'#F6D98A');c.fillStyle=gr;c.fillRect(0,0,W,H);
    c.fillStyle='rgba(0,0,0,.12)';for(let x=0;x<W;x+=10){c.fillRect(x,6,2,40);c.fillRect(x,H-46,2,40);}
    c.strokeStyle='#fff';c.lineWidth=3;c.setLineDash([10,8]);c.beginPath();c.moveTo(14,52);c.lineTo(W-14,52);c.stroke();c.setLineDash([]);
    c.fillStyle='#FFF8EA';c.beginPath();c.arc(W/2,H*.43,74,0,Math.PI*2);c.fill();c.strokeStyle='#7A4A08';c.lineWidth=5;c.stroke();
    c.fillStyle='#F2C14E';c.beginPath();for(let i=0;i<=10;i++){const a=-Math.PI/2+i/10*Math.PI*2,r=i%2?22:52;i?c.lineTo(W/2+Math.cos(a)*r,H*.43+Math.sin(a)*r):c.moveTo(W/2+Math.cos(a)*r,H*.43+Math.sin(a)*r);}c.fill();c.strokeStyle='#9C6412';c.lineWidth=3;c.stroke();
    c.fillStyle='#3A2408';c.font='900 34px Nunito, Arial Black, sans-serif';c.textAlign='center';c.fillText('1 LÉGENDAIRE',W/2,H*.78);});
  const body=new THREE.Mesh(rbox(1.36,2.04,.22,.1),metal(0xE9B949,.3));g.add(body);
  const face=new THREE.Mesh(new THREE.PlaneGeometry(1.32,2.0),new THREE.MeshStandardMaterial({map:tex,roughness:.3,metalness:.35}));face.position.z=.112;g.add(face);
  [[.8,.9,.14],[-.82,.3,.1],[.7,-.95,.09]].forEach(([x,y,s])=>{const sp=spark(s,0xFFF1C2);sp.position.set(x,y,.2);g.add(sp);});
  g.rotation.set(-.06,-.4,.06);return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function ONGLETS(){const g=COUV('grimoire').obj;g.children.forEach(()=>0);
  ['#F76707','#1098AD','#0CA678','#D6336C'].forEach((col,i)=>{const t=new THREE.Mesh(rbox(.3,.3,.08,.06),phys(new THREE.Color(col).getHex(),{roughness:.35}));t.position.set(.82,.6-i*.36,.05);g.add(t);});
  return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function MARQUE(){const g=COUV('automne').obj;
  const sh=new THREE.Shape();sh.moveTo(-.12,1.25);sh.lineTo(.12,1.25);sh.lineTo(.12,.2);sh.lineTo(0,.32);sh.lineTo(-.12,.2);sh.lineTo(-.12,1.25);
  const m=new THREE.Mesh(extrude(sh,.03,.01),phys(VIOLET,{roughness:.4}));m.position.set(.35,-.1,.24);g.add(m);
  const tas=new THREE.Mesh(new THREE.SphereGeometry(.09,16,12),metal(GOLD,.2));tas.position.set(.35,1.18,.24);g.add(tas);
  return {obj:g,cam:[0,.2,4.6,0,0,0]};}
function VITRINE(){const g=new THREE.Group();
  [[-1.05,-.05,.7],[0,.12,.84],[1.05,-.05,.7]].forEach(([x,y,s],i)=>{const cd=card3d(phys(0xffffff,{roughness:.4}),faceTex({ink:['#3C8FD0','#7B5CFF','#C2449A'][i],art:['#CFE9FA','#E4D6FF','#F6C2D8'][i]}));cd.scale.setScalar(s);cd.position.set(x,y+.15,0);g.add(cd);
    const sc=new THREE.Mesh(new THREE.CylinderGeometry(.48*s/.62,.52*s/.62,.16,48),metal(GOLD,.22));sc.position.set(x,y-.52*s/.62+.02,0);g.add(sc);});
  const cone=new THREE.Mesh(new THREE.ConeGeometry(1.6,2.6,48,1,true),new THREE.MeshBasicMaterial({color:0xFFE27A,transparent:true,opacity:.12,side:THREE.DoubleSide,depthWrite:false}));cone.position.y=.65;g.add(cone);
  g.rotation.set(.08,-.25,0);return {obj:g,cam:[0,.4,5,0,0,0]};}
function FLAMME(){const g=new THREE.Group();
  const f1=new THREE.Mesh(extrude(flameShape(2.1),.36,.12),phys(0xFF922B,{emissive:0xFF4000,emissiveIntensity:.25}));g.add(f1);
  const f2=new THREE.Mesh(extrude(flameShape(1.1),.3,.1),phys(0xFFD43B,{emissive:0xFFC400,emissiveIntensity:.35}));f2.position.set(0,-.2,.16);g.add(f2);
  g.rotation.y=-.35;return {obj:g,cam:[0,.2,4.6,0,0,0]};}
async function COMBO(a,b,sb=.62,ob=[.62,-.55,.35]){const A=await a(),B=await b();const g=new THREE.Group();A.obj.position.x=-.25;g.add(A.obj);B.obj.scale.setScalar(sb);B.obj.position.set(...ob);g.add(B.obj);return {obj:g,cam:[0,.2,4.8,0,0,0]};}

/* le neurone, monnaie de l'album : un petit cerveau rose tout rond, en lobes, avec un éclat */
function NEURONE(){const g=new THREE.Group();const gyr=phys(0xF7579A,{roughness:.36}),deep=phys(0x9E1F55,{roughness:.55}),back=phys(0xE04A8A,{roughness:.4});
  let k=5;const rnd=()=>{k=(k*16807)%2147483647;return (k-1)/2147483646;};
  // cerveau de profil : un ovale sombre couvert de circonvolutions roses bien rondes (des boudins sinueux)
  const A=[1.1,.8,.7],O=new THREE.Vector3(0,.12,0);
  const core=new THREE.Mesh(new THREE.SphereGeometry(1,64,40),deep);core.scale.set(A[0]*.93,A[1]*.93,A[2]*.93);core.position.copy(O);g.add(core);
  const surf=(u,v)=>{const cu=Math.cos(u),su=Math.sin(u),cv=Math.cos(v),sv=Math.sin(v);return new THREE.Vector3(O.x+A[0]*cv*su*.9,O.y+A[1]*sv*.9,O.z+A[2]*cv*cu*.9);};
  for(let c=0;c<64;c++){let u=-Math.PI+rnd()*Math.PI*2,v=-1.2+rnd()*2.4,dir=rnd()*Math.PI*2;const pts=[];
    for(let t=0;t<16;t++){pts.push(surf(u,v));dir+=(rnd()-.5)*1.6;u+=Math.cos(dir)*.12;v+=Math.sin(dir)*.1;v=Math.max(-1.35,Math.min(1.35,v));}
    g.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts),80,.115,14,false),gyr));
    [pts[0],pts[pts.length-1]].forEach(p=>{const cap=new THREE.Mesh(new THREE.SphereGeometry(.115,16,12),gyr);cap.position.copy(p);g.add(cap);});}
  const cer=new THREE.Mesh(new THREE.SphereGeometry(1,48,32),back);cer.scale.set(.4,.27,.38);cer.position.set(.66,-.6,-.1);g.add(cer);
  const stem=new THREE.Mesh(new THREE.CylinderGeometry(.16,.11,.55,24),back);stem.position.set(.2,-.8,-.12);stem.rotation.z=.28;g.add(stem);
  [[1.32,.85,.15],[-1.35,-.55,.11]].forEach(([x,y,s])=>{const sp=spark(s,0xFFD23F);sp.position.set(x,y,.5);g.add(sp);});
  g.rotation.set(.1,-.2,0);return {obj:g,cam:[0,0,4.3,0,0,0]};}

window.PASS_ICONS={
  neurone:NEURONE,
  ticket_pochette:TPACK, jeton:JETON,
  dos_soleil:()=>PDOS('soleil'), dos_nuit:()=>PDOS('nuit'), dos_domaines:()=>PDOS('domaines'), dos_or:()=>PDOS('or'),
  cadre_citrouille:()=>CADRE('citrouille'), cadre_vitrail:()=>CADRE('vitrail'), cadre_nuit:()=>CADRE('nuit'), cadre_marbre:()=>CADRE('marbre'), cadre_toile:()=>CADRE('toile'),
  finition_givre:()=>FINITION('givre'), finition_or:()=>FINITION('or'), finition_holo:()=>FINITION('holo'),
  titre_curieux:()=>TITRE('Curieux',0xC2255C), titre_erudit:()=>TITRE('Érudit',0xC2255C), titre_grand_curieux:()=>TITRE('Grand curieux',0xC2255C), titre_chasseur:()=>TITRE('Chasseur de légendes',0xC2255C), titre_musee:()=>TITRE('Pièce de musée',0xC2255C),
  titrej_explorateur:()=>TITREJ('Explorateur'), titrej_batisseur:()=>TITREJ('Bâtisseur'), titrej_savant:()=>TITREJ('Savant'), titrej_legende:()=>TITREJ('Légende vivante'),
  autoc_s1:()=>AUTOC('s1','#C2449A'), autoc_halloween:()=>AUTOC('pumpkin','#3A1F5A'), autoc_fondateur:()=>AUTOC('star','#3A1FB8'), autoc_chauve:()=>AUTOC('bat','#2B1636'),
  socle_marbre:()=>SOCLE('marbre'), socle_or:()=>SOCLE('or'), socle_neon:()=>SOCLE('neon'),
  couv_automne:()=>COUV('automne'), couv_grimoire:()=>COUV('grimoire'), couv_or:()=>COUV('or'),
  coffret:COFFRET, doree:DOREE, onglets:ONGLETS, marque:MARQUE, vitrine:VITRINE, flamme:FLAMME,
  final_gratuit:()=>COMBO(()=>PDOS('nuit'),DOREE), final_payant:()=>COMBO(()=>PDOS('or'),FLAMME,.55,[.65,-.6,.4]),
};
window.renderPass=async(px,only)=>{const out={};for(const [k,b] of Object.entries(window.PASS_ICONS)){if(only&&k!==only)continue;const built=await b();out[k]=snap(()=>built,px);}return out;};
