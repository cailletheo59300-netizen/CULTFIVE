/* --- Technologie : objets génériques, aucun logo de marque --- */
const keycap=(x,y,w,h,t,size=14)=>R(x,y+4,w,h,'#9FA8B4',2,6)+R(x,y,w,h,'#F4F1EA',2,6)+R(x+5,y+4,w-10,h-12,'#fff',0,4)+T(x+w/2,y+h/2+size*.3,t,size,INK,'middle',700);
SUBJECTS['tech.brands']={
 1:id=>{ // garage des débuts (légendaire) : porte ouverte, établi et premier ordinateur
   let g=`<defs><linearGradient id="${id}sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F3B98A"/><stop offset="1" stop-color="#FBE6C8"/></linearGradient><radialGradient id="${id}in" cx=".5" cy=".6" r=".7"><stop offset="0" stop-color="#FFF3C0"/><stop offset="1" stop-color="#F2C46A"/></radialGradient></defs><rect x="0" y="0" width="200" height="160" fill="url(#${id}sk)"/>`;
   g+=C(160,40,12,'#F2B441',0)+S('M10,136 C60,130 140,130 190,136 L190,160 L10,160 Z','#9CB48A',1.4);
   g+=S('M150,136 C140,108 142,86 160,76 C178,86 180,110 170,136 Z','#5E8A4A',1.6)+L(160,136,160,146,3,WOOD);
   const house=S('M26,146 L26,78 L100,30 L174,78 L174,146 Z','#F4E9D6',2.6)+S('M14,84 L100,24 L186,84 L180,92 L100,36 L20,92 Z','#8A5A34',2.4)+R(150,40,12,22,'#B5302A',2,1)
     +R(34,96,26,22,'#9FD3DC',2,1)+L(47,96,47,118,1.4)+L(34,107,60,107,1.4)+L(30,146,170,146,2.6);
   const inside=R(66,82,96,64,`url(#${id}in)`,2.4,1)+S('M66,82 L162,82 L162,98 L66,98 Z','#D9CDB8',2.2)+[87,92].map(y=>L(66,y,162,y,1,INK,.4)).join('')
     +R(76,124,74,5,WOOD,1.8)+L(82,129,82,146,2.4)+L(144,129,144,146,2.4)
     +R(84,100,32,24,'#E8DCC0',2,3)+R(88,104,24,15,'#23331F',1.4,1)+SC('M91,108 L99,108 M91,112 L104,112 M91,116 L96,116','#8CF08C',1.4)
     +S('M80,122 L120,122 L118,124 L82,124 Z','#E8DCC0',1.4)+R(124,116,22,7,'#E8DCC0',1.6,1)+[128,133,138].map(x=>L(x,119,x+3,119,1)).join('')+C(136,106,5,'#F2D24A',1.2)+L(136,111,136,116,1.4);
   return inMedal(id+'ga',g)+medalRing()+`<g transform="translate(100 150) scale(.84) translate(-100 -150)">${house+inside}<path d="M66,146 L58,152 L170,152 L162,146 Z" fill="#FFF3B0" opacity=".5"/></g>`;},
 2:id=>{ // bulle de notification
   let p=S('M40,50 C40,38 50,30 62,30 L138,30 C150,30 160,38 160,50 L160,96 C160,108 150,116 138,116 L84,116 L58,140 L64,116 L62,116 C50,116 40,108 40,96 Z','#5B8FE8',2.6);
   p+=S('M100,98 C84,86 70,76 70,64 C70,54 80,50 88,54 C94,56 98,60 100,64 C102,60 106,56 112,54 C120,50 130,54 130,64 C130,76 116,86 100,98 Z','#fff',2);
   return p+C(156,36,15,'#E8443A',2.2)+T(156,42,'1',17,'#fff');},
 3:id=>{ // cartes à jouer hanafuda
   const card=(x,y,a,inner)=>rot(a,x+22,y+68,R(x,y,44,68,'#C9443A',2.2,3)+R(x+4,y+4,36,60,'#F8F2E6',1,2)+inner);
   const sun=C(0,0,0,'none',0);
   let p=card(28,44,-18,`<rect x="32" y="48" width="36" height="34" fill="#E8C060" opacity=".6"/>`+C(50,64,11,'#C9443A',1.4)+S('M32,96 C40,84 52,80 68,88 L68,108 L32,108 Z','#3B3A3A',1.2));
   p+=card(78,38,0,`<rect x="82" y="42" width="36" height="60" fill="#F2E6CC"/>`+SC('M100,100 C98,80 92,66 84,56',WOOD,2.4)+[[92,60],[100,72],[108,58],[86,78],[106,84]].map(([x,y])=>C(x,y,4.4,'#E8A0B8',1)+C(x,y,1.2,'#C9443A',0)).join(''));
   p+=card(128,44,18,`<rect x="132" y="48" width="36" height="60" fill="#E8E2D0"/>`+C(150,62,10,'#F4F1EA',1.4)+S('M132,108 L132,88 C140,78 160,78 168,88 L168,108 Z','#3B3A3A',1.2)+S('M132,90 C140,82 160,82 168,90','none',1));
   return p+sun;},
 4:id=>{ // brique de construction
   const top='M40,74 L100,50 L160,74 L100,98 Z';
   let p=S('M40,74 L100,98 L100,132 L40,108 Z','#B5302A',2.4)+S('M160,74 L100,98 L100,132 L160,108 Z','#9A2620',2.4)+S(top,'#D9433A',2.4);
   const st=[];for(let i=0;i<4;i++)for(let j=0;j<2;j++){const a=(i+.5)/4,b=(j+.5)/2;st.push([40+a*60+b*60,74-a*24+b*24]);}
   st.sort((m,n)=>m[1]-n[1]);
   for(const [cx,cy] of st)p+=S(`M${cx-8},${cy} L${cx-8},${cy-6} L${cx+8},${cy-6} L${cx+8},${cy} Z`,'#C9443A',1.2)+E(cx,cy,8,3.4,0,'#C9443A',1.2)+E(cx,cy-6,8,3.4,0,'#E8574A',1.4);
   return p+`<path d="M46,80 L46,104" stroke="#fff" stroke-width="2.4" opacity=".35"/>`;},
 5:id=>{ // moulin à café
   let p=R(64,84,72,58,'#8A5A34',2.4,3)+R(64,84,72,8,'#6B4426',2,2)+R(84,112,32,16,'#6B4426',1.8,2)+C(100,120,2.4,GOLD,1);
   p+=S('M70,84 C70,66 82,58 100,58 C118,58 130,66 130,84 Z','#C9B79C',2.4)+S('M76,84 C76,72 86,66 100,66 C114,66 124,72 124,84 Z','#3B2A1E',1.6)+[[88,74],[96,70],[106,72],[112,78],[92,80]].map(([x,y])=>E(x,y,2.6,1.8,30,'#6B4426',.8)).join('');
   p+=L(100,58,100,46,3)+SC('M100,46 L136,40',INK,3.4)+C(100,46,4,GOLD,1.4)+R(132,28,10,16,'#6B4426',1.8,4);
   return p+[70,130].map(x=>R(x-4,142,8,6,'#3B2A1E',1)).join('');},
 6:id=>{ // chaussure de sport
   let p=S('M30,110 C30,90 42,70 62,66 L82,64 C92,76 110,82 132,86 C152,90 168,96 170,110 L170,118 L30,118 Z','#F4F1EA',2.4);
   p+=S('M28,116 L172,116 C172,126 166,132 158,132 L40,132 C32,132 28,126 28,116 Z','#5B8FE8',2.2)+L(32,124,168,124,1,INK,.4);
   p+=S('M62,66 L82,64 C84,72 88,76 92,78 L76,96 C68,90 62,80 62,66 Z','#2F4E8C',1.6)+[0,1,2,3].map(i=>L(78+i*7,74+i*3,90+i*7,70+i*4,2.2,INK)).join('');
   return p+S('M130,88 C148,92 160,98 164,108 L140,108 Z','#2F4E8C',1.4)+S('M30,104 C40,100 50,100 56,106 L56,116 L30,116 Z','#2F4E8C',1.4);},
 7:id=>{ // bouteille de soda (verre générique)
   const b='M88,20 L112,20 L112,40 C112,50 124,56 124,72 L124,140 C124,148 118,152 110,152 L90,152 C82,152 76,148 76,140 L76,72 C76,56 88,50 88,40 Z';
   let p=S(b,'#5A2A1A',2.4)+clipTo(id+'so',b,`<rect x="70" y="18" width="60" height="44" fill="#E8E2D8" opacity=".7"/>`+R(70,92,60,26,'#C9443A',0)+SC('M76,104 C90,98 110,110 124,104','#fff',2.4)+[[90,130,2],[106,140,1.6],[98,120,1.4],[110,126,1.2],[86,144,1.4]].map(([x,y,r])=>C(x,y,r,'#fff',.6)).join(''))+S(b,'none',2.4);
   return p+R(86,12,28,10,'#C9443A',2,2)+[90,96,102,108].map(x=>L(x,12,x,22,1,INK,.4)).join('')+`<path d="M82,66 L82,140" stroke="#fff" stroke-width="3" opacity=".4"/>`;},
 8:id=>{ // meuble en kit : planches, vis et clé
   let p=rot(-8,100,80,R(36,40,110,20,'#E8C99A',2.2,2)+R(46,66,110,20,'#E2BE8A',2.2,2)+R(40,92,110,20,'#E8C99A',2.2,2)+[[52,50],[130,50],[62,76],[140,76],[56,102],[134,102]].map(([x,y])=>C(x,y,3,'#fff',1.2)).join(''));
   p+=SC('M48,132 L118,132 L118,118',INK,7)+SC('M48,132 L118,132 L118,118',SILVER,4.4);
   return p+[[140,128],[156,120],[150,140]].map(([x,y],i)=>rot(i*40,x,y,R(x-2,y-8,4,14,SILVER,1.2,1)+R(x-4,y-10,8,3,SILVER,1.2,1))).join('');},
 9:id=>{ // carte Vitale (carte à puce verte et jaune)
   let p=rot(-6,100,86,R(32,40,136,88,'#5EA86A',2.4,8)+`<path d="M32,98 C70,86 120,110 168,92 L168,120 C168,124 164,128 160,128 L40,128 C36,128 32,124 32,120 Z" fill="#F2D24A"/>`+R(32,40,136,88,'none',2.4,8)
     +R(48,62,26,20,'#E9C060',1.6,3)+SC('M48,72 L74,72 M61,62 L61,82 M48,67 L56,67 M66,77 L74,77',INK,1,'opacity=".6"')+R(118,54,36,44,'#F4F1EA',1.6,2)+C(136,70,8,'#9FA8B4',0)+S('M122,98 C124,84 148,84 150,98 Z','#9FA8B4',0)
     +[0,1,2].map(i=>R(48,92+i*0,0,0,'none',0)).join('')+R(48,104,56,4,'#2B3E2B',0,2)+R(48,112,40,4,'#2B3E2B',0,2));
   return p;},
};
SUBJECTS['tech.computing']={
 1:id=>{ // suite de 0 et de 1 : un octet
   const bits='01000010';
   let p='';
   p+=[...bits].map((b,i)=>R(28+i*18,70,16,28,b==='1'?'#2F4E8C':'#F4F1EA',2,3)+`<text x="${36+i*18}" y="${90}" font-family="Menlo, Consolas, monospace" font-weight="700" font-size="17" fill="${b==='1'?'#fff':INK}" text-anchor="middle">${b}</text>`).join('');
   return p+SC('M28,106 L28,112 L172,112 L172,106',INK,1.6)+T(100,130,'8',16,INK,'middle',800);},
 2:id=>{ // ordinateur ENIAC : armoires, cadrans et câbles
   let p=R(18,34,164,104,'#3B3A3A',2.4,2)+[0,1,2,3].map(i=>R(24+i*40,40,36,92,'#5C5C5C',1.6,1)).join('');
   p+=[0,1,2,3].map(i=>[0,1,2].map(k=>C(36+i*40,52+k*12,3.4,'#E8E8E8',1)+C(48+i*40,52+k*12,3.4,'#E8E8E8',1)).join('')).join('');
   p+=[0,1,2,3].map(i=>[...Array(10)].map((_,k)=>C(30+i*40+(k%5)*6,94+Math.floor(k/5)*8,1.6,k%3?'#F2D24A':'#C9443A',0)).join('')).join('');
   p+=SC('M42,112 C52,150 92,150 98,112 M80,116 C100,146 130,140 138,114 M120,118 C130,142 160,140 162,116',`#C9443A`,2.2)+SC('M56,118 C70,140 108,136 116,118','#2F4E8C',2.2);
   return p+R(18,138,164,8,'#2B2B2B',2,1);},
 3:id=>{ // pixels rouge, vert, bleu
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#1E1E22');
   for(let r=0;r<7;r++)for(let c=0;c<8;c++){const x=30+c*19,y=20+r*20;g+=['#E8443A','#4FC05A','#3C6FF0'].map((col,k)=>R(x+k*5.6,y,4.6,16,col,0,1.4)).join('');}
   g+=`<circle cx="100" cy="84" r="34" fill="#fff" opacity=".12"/>`;
   return inMedal(id+'px',g)+medalRing();},
 4:id=>{ // touches Ctrl et Z
   let p=keycap(28,72,64,52,'Ctrl',18)+T(108,106,'+',24,INK)+keycap(122,72,52,52,'Z',24);
   return p+SC('M144,58 C140,30 70,24 62,54',INK,3.4)+S('M54,46 L62,60 L72,48 Z',INK,1.6);},
 5:id=>{ // accolades de code
   let p=R(26,30,148,108,'#1E2433',2.4,8)+R(26,30,148,14,'#2E3550',2,8)+[38,46,54].map((x,i)=>C(x,37,2.6,['#E8574A','#F2D24A','#4FC05A'][i],0)).join('');
   p+=T(44,102,'{',44,'#F2D24A','middle',700)+T(156,102,'}',44,'#F2D24A','middle',700);
   return p+[[62,62,40,'#9CC2F0'],[70,74,52,'#F28C3A'],[70,86,30,'#7FD87F'],[70,98,46,'#9CC2F0'],[62,110,24,'#E8A0B8'],[70,122,36,'#7FD87F']].map(([x,y,w,c])=>R(x,y,w,5,c,0,2.5)).join('');},
 6:id=>{ // globe en réseau (légendaire) : le premier site web est né à Genève
   const c=MAPS.globeAtlanticCities,hub=c['Genève'];
   let p=`<defs><radialGradient id="${id}oc" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="#5BA8E0"/><stop offset="1" stop-color="#1E3E6E"/></radialGradient></defs><circle cx="100" cy="84" r="66" fill="#5BC0F0" opacity=".15"/>`;
   p+=C(100,84,54,`url(#${id}oc)`,2.4)+clipCircle(id+'wb',100,84,54,`<path d="${MAPS.globeAtlantic}" fill="#7FB86A" stroke="${INK}" stroke-width=".8"/>`+[-36,-18,0,18,36].map(y=>`<ellipse cx="100" cy="${84+y}" rx="54" ry="5" fill="none" stroke="#fff" stroke-width=".6" opacity=".3"/>`).join('')+[-36,0,36].map(x=>`<ellipse cx="${100+x*.0}" cy="84" rx="${Math.abs(x)*.9+6}" ry="54" fill="none" stroke="#fff" stroke-width=".6" opacity=".3"/>`).join(''))+C(100,84,54,'none',2.4);
   const arc=([x1,y1],[x2,y2])=>{const mx=(x1+x2)/2,my=(y1+y2)/2,d=Math.hypot(x2-x1,y2-y1),dx=mx-100,dy=my-84,n=Math.hypot(dx,dy)||1;return `<path d="M${x1},${y1} Q${(mx+dx/n*d*.3).toFixed(1)},${(my+dy/n*d*.3).toFixed(1)} ${x2},${y2}" fill="none" stroke="#F2D24A" stroke-width="1.8" opacity=".95"/>`;};
   for(const k of ['New York','Rio','Dakar','Montréal','Lagos','Mexico','Buenos Aires','Madrid','Londres'])p+=arc(hub,c[k]);
   p+=SC(`M${c['New York'][0]},${c['New York'][1]} Q70,96 ${c.Rio[0]},${c.Rio[1]} M${c.Mexico[0]},${c.Mexico[1]} Q96,104 ${c.Dakar[0]},${c.Dakar[1]}`,'#9FE0FF',1.2,'opacity=".8"');
   p+=Object.entries(c).filter(([k])=>!['Paris','Genève'].includes(k)).map(([k,[x,y]])=>C(x,y,2.6,'#F2D24A',1.2)).join('')+`<circle cx="${hub[0]}" cy="${hub[1]}" r="9" fill="#FFF3B0" opacity=".5"/>`+C(hub[0],hub[1],4,'#fff',1.6);
   return p+[[36,30],[166,34],[30,136],[172,132]].map(([x,y])=>star4(x,y,4,'#9FE0FF')).join('');},
 7:id=>{ // arobase
   return `<text x="100" y="124" font-family="Fraunces, Georgia, serif" font-weight="800" font-size="118" fill="#2F4E8C" stroke="${INK}" stroke-width="2" text-anchor="middle">@</text>`;},
 8:id=>{ // lecteur vidéo : bouton de lecture et barre de progression
   let p=R(26,32,148,104,'#1E1E22',2.4,8)+R(32,38,136,76,'#3E5A8A',1.6,4)+S('M32,100 C70,84 100,104 168,88 L168,114 L32,114 Z','#5E8A6A',0);
   p+=C(100,76,22,'#fff',2.4)+S('M93,64 L93,88 L114,76 Z','#E8443A',1.6);
   return p+R(34,122,132,5,'#5C5C5C',0,2.5)+R(34,122,72,5,'#E8443A',0,2.5)+C(106,124.5,5,'#fff',1.4);},
 9:id=>{ // smartphone et SMS
   let p=R(62,20,76,128,'#1E1E22',2.6,12)+R(68,30,64,104,'#EAF2F8',1.4,3)+R(90,24,20,3,'#3B3A3A',0,1.5)+C(100,141,3.4,'#3B3A3A',1);
   p+=S('M74,40 L112,40 C116,40 118,42 118,46 L118,56 C118,60 116,62 112,62 L80,62 L74,68 Z','#D8DDE4',1.4)+S('M88,72 L122,72 C126,72 128,74 128,78 L128,90 C128,94 126,96 122,96 L94,96 C90,96 88,94 88,90 Z','#4FC05A',1.4)+S('M74,104 L106,104 C110,104 112,106 112,110 L112,118 C112,122 110,124 106,124 L80,124 L74,128 Z','#D8DDE4',1.4);
   return p+[[80,48,28],[80,54,20],[94,80,26],[94,86,18],[80,112,24]].map(([x,y,w])=>R(x,y,w,3,'#3B3A3A',0,1.5)).join('');},
 10:id=>{ // cadenas
   let p=SC('M70,76 L70,58 C70,36 84,26 100,26 C116,26 130,36 130,58 L130,76',INK,13)+SC('M70,76 L70,58 C70,36 84,26 100,26 C116,26 130,36 130,58 L130,76',SILVER,8);
   p+=R(56,74,88,70,GOLD,2.6,8)+`<path d="M64,82 L64,134" stroke="#fff" stroke-width="3" opacity=".45"/>`+C(100,102,9,'#3B3A3A',1.6)+S('M96,106 L104,106 L106,124 L94,124 Z','#3B3A3A',1.4);
   return p+[64,72,80].map(x=>C(x+60,84,0,'none',0)).join('');},
 11:id=>{ // cerveau en circuits
   const br='M100,40 C88,30 66,32 60,46 C46,46 38,58 42,70 C32,78 34,96 46,102 C44,116 56,128 72,124 C80,134 94,134 100,126 C106,134 120,134 128,124 C144,128 156,116 154,102 C166,96 168,78 158,70 C162,58 154,46 140,46 C134,32 112,30 100,40 Z';
   let p=S(br,'#E8A0B8',2.6)+clipTo(id+'br',br,SC('M64,62 C74,58 82,66 78,76 M56,86 C66,82 74,90 68,100 M82,110 C88,102 96,104 96,112 M126,58 C136,58 140,68 134,74 M140,88 C146,94 142,104 134,104 M112,108 C118,100 128,104 126,112',INK,1.4,'opacity=".45"'))+L(100,40,100,126,1.8,INK,.7);
   p+=SC('M116,52 L132,52 L140,60 M118,76 L148,76 M116,92 L128,92 L136,100 M112,116 L124,116','#2F4E8C',2.2);
   return p+[[140,60],[148,76],[136,100],[124,116],[116,52],[118,76],[116,92],[112,116]].map(([x,y])=>C(x,y,3,'#5BC0F0',1.4)).join('')+SC('M154,76 L176,76 M150,100 L172,108 M150,56 L170,44','#2F4E8C',2)+[[176,76],[172,108],[170,44]].map(([x,y])=>C(x,y,3.4,'#F2D24A',1.4)).join('');},
};
SUBJECTS['tech.inventions']={
 1:id=>{ // lettre en braille : une cellule de six points
   let p=R(30,40,140,92,'#F8F2E6',2.2,6)+`<path d="M30,52 L170,52" stroke="${INK}" stroke-width=".6" opacity=".2"/>`;
   const cell=(x,on)=>[0,1,2,3,4,5].map(k=>{const cx=x+(k>2?12:0),cy=64+(k%3)*18;return on[k]?C(cx,cy,5,'#2F4E8C',1.4)+C(cx-1.4,cy-1.6,1.4,'#fff',0):C(cx,cy,2,'#C9C2B6',0);}).join('');
   p+=cell(50,[1,1,1,1,1,1])+cell(92,[1,0,0,0,0,0])+cell(134,[1,1,0,0,0,0]);
   return p+R(42,52,32,64,'none',1.6,4).replace(INK,'#F2B441');},
 2:id=>{ // ampoule à filament (légendaire)
   let p=`<defs><radialGradient id="${id}gl" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFF6C8"/><stop offset=".55" stop-color="#F2D24A" stop-opacity=".45"/><stop offset="1" stop-color="#F2D24A" stop-opacity="0"/></radialGradient></defs><circle cx="100" cy="64" r="64" fill="url(#${id}gl)"/>`;
   p+=[...Array(10)].map((_,i)=>{const a=(-170+i*17.8)*Math.PI/180;return L((100+52*Math.cos(a)).toFixed(1),(62+52*Math.sin(a)).toFixed(1),(100+64*Math.cos(a)).toFixed(1),(62+64*Math.sin(a)).toFixed(1),2.4,'#E9A030');}).join('');
   const g='M100,22 C124,22 140,40 140,62 C140,80 128,90 122,102 L118,112 L82,112 L78,102 C72,90 60,80 60,62 C60,40 76,22 100,22 Z';
   p+=S(g,'#FFFBEA',2.6)+`<path d="M74,46 C78,36 88,30 98,30" fill="none" stroke="#fff" stroke-width="5" opacity=".9"/>`;
   p+=SC('M92,110 L92,74 M108,110 L108,74',INK,1.6)+SC('M92,74 C92,64 96,64 96,70 C96,62 100,62 100,70 C100,62 104,62 104,70 C104,64 108,64 108,74','#F28C3A',2.4)+`<path d="M92,74 C92,64 96,64 96,70 C96,62 100,62 100,70 C100,62 104,62 104,70 C104,64 108,64 108,74" fill="none" stroke="#FFF3B0" stroke-width="1"/>`;
   p+=R(82,112,36,8,SILVER,2,2)+R(84,120,32,7,'#C9CED4',2,2)+R(84,127,32,7,SILVER,2,2)+S('M88,134 L112,134 L106,144 L94,144 Z','#3B3A3A',2);
   return p+[124,130].map(y=>L(84,y,116,y+3,1,INK,.4)).join('');},
 3:id=>{ // téléphone à cadran
   let p=S('M40,140 C40,110 56,84 100,84 C144,84 160,110 160,140 Z','#1E1E22',2.6)+`<path d="M58,118 C64,100 78,92 96,90" fill="none" stroke="#fff" stroke-width="3" opacity=".25"/>`;
   p+=C(100,118,22,'#F4F1EA',2)+[...Array(10)].map((_,i)=>{const a=(-60-i*28)*Math.PI/180;return C((100+15*Math.cos(a)).toFixed(1),(118+15*Math.sin(a)).toFixed(1),3.6,'#fff',1.2);}).join('')+C(100,118,7,'#C9443A',1.4);
   p+=S('M36,74 C34,58 46,52 58,58 L66,64 L134,64 L142,58 C154,52 166,58 164,74 C162,82 150,82 146,76 L140,72 L60,72 L54,76 C50,82 38,82 36,74 Z','#1E1E22',2.4);
   return p+SC('M160,128 C176,128 182,110 172,98',INK,2.4,'stroke-dasharray="4 2"')+R(92,64,16,20,'#1E1E22',2);},
 4:id=>{ // appareil photo ancien à soufflet
   let p=L(100,118,72,154,3,WOOD)+L(100,118,128,154,3,WOOD)+L(100,118,100,156,3,WOOD);
   p+=R(44,52,48,64,'#6B4426',2.4,2)+S('M92,58 L130,66 L130,104 L92,110 Z','#2B2B2B',2.2)+[100,108,116,124].map(x=>L(x,60+(x-92)*.2,x,108-(x-92)*.16,1,'#fff',.35)).join('');
   p+=R(130,70,14,30,'#8A5A34',2,2)+C(152,85,13,GOLD,2.2)+C(152,85,8,'#3B5A7A',1.6)+C(149,82,2.4,'#fff',0);
   return p+R(56,44,24,8,'#3B3A3A',1.6,2)+R(50,60,14,10,'#9FD3DC',1.2,1);},
 5:id=>{ // TGV
   let p=S('M16,112 L16,72 L120,72 C150,72 172,86 186,104 C188,108 186,112 182,112 Z','#E8ECF0',2.4)+S('M120,72 C138,72 154,80 166,90 L136,90 Z','#2B3E6E',1.6);
   p+=R(16,98,166,8,'#2F4E8C',0)+[24,44,64,84,104].map(x=>R(x,80,14,10,'#2B3E6E',1.2,2)).join('')+L(16,112,184,112,2.4)+[30,58,100,128].map(x=>C(x,116,5,'#3B3A3A',1.4)).join('');
   p+=L(8,124,192,124,2.4)+SC('M60,58 L60,72 M50,58 L80,58',INK,1.6)+SC('M4,80 L12,80 M2,92 L12,92',INK,1.6,'opacity=".5"');
   return p+[...Array(9)].map((_,i)=>L(10+i*21,126,16+i*21,132,2,WOOD)).join('');},
 6:id=>{ // draisienne
   let p=C(52,112,24,'none',3)+C(148,112,24,'none',3)+[0,1,2,3,4,5].map(i=>{const a=i*Math.PI/6;return L((52+22*Math.cos(a)).toFixed(1),(112+22*Math.sin(a)).toFixed(1),(52-22*Math.cos(a)).toFixed(1),(112-22*Math.sin(a)).toFixed(1),1,INK,.6)+L((148+22*Math.cos(a)).toFixed(1),(112+22*Math.sin(a)).toFixed(1),(148-22*Math.cos(a)).toFixed(1),(112-22*Math.sin(a)).toFixed(1),1,INK,.6);}).join('');
   p+=S('M46,82 L156,78 L156,88 L46,92 Z',WOOD,2.2)+L(52,112,56,90,4,WOOD)+L(148,112,142,86,4,WOOD)+S('M84,74 C86,66 116,66 118,74 L118,80 L84,82 Z','#8E1B1B',1.8);
   return p+SC('M142,86 L136,58 M124,56 L148,60',INK,3)+C(52,112,4,GOLD,1.2)+C(148,112,4,GOLD,1.2);},
 7:id=>{ // avion des frères Wright au-dessus des dunes
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#CFE3F2')+S('M10,128 C50,112 90,126 120,116 C150,108 170,120 190,116 L190,160 L10,160 Z','#E8D2A0',1.6)+E(150,40,16,5,0,'#fff',0)+E(56,54,12,4,0,'#fff',0);
   const plane=R(46,64,108,6,'#F4EAD8',2,1)+R(46,88,108,6,'#F4EAD8',2,1)+[52,72,92,108,128,148].map(x=>L(x,70,x,88,1.4)).join('')+SC('M52,70 L72,88 M128,70 L148,88',INK,.8)
     +R(160,72,16,5,'#F4EAD8',1.6,1)+R(160,82,16,5,'#F4EAD8',1.6,1)+L(154,80,160,80,1.2)+R(24,70,6,22,'#F4EAD8',1.6,1)+L(30,80,46,80,1.2)+E(88,80,8,3,90,'#8A5A34',1.2)+E(112,80,8,3,90,'#8A5A34',1.2)+R(96,82,8,6,'#3B3A3A',1)+R(99,74,6,8,'#5A5A5A',1);
   return inMedal(id+'wr',g)+medalRing()+`<g transform="translate(0 -6)">${plane}</g>`;},
 8:id=>{ // fusée Saturn V
   let p=`<path d="M92,140 C88,150 92,160 100,164 C108,160 112,150 108,140 Z" fill="#F28C3A"/>`+`<path d="M95,140 C94,148 96,154 100,158 C104,154 106,148 105,140 Z" fill="#FFF3B0"/>`;
   p+=S('M100,8 L104,18 L104,30 L96,30 L96,18 Z',SILVER,1.6)+S('M94,30 L106,30 L108,46 L92,46 Z','#F4F1EA',2)+R(90,46,20,22,'#F4F1EA',2)+R(88,68,24,28,'#F4F1EA',2)+R(86,96,28,40,'#F4F1EA',2.2);
   p+=R(90,58,20,4,'#1E1E22',0)+R(88,82,24,6,'#1E1E22',0)+[0,1,2,3].map(i=>R(86+i*7,104,3.5,24,i%2?'#1E1E22':'#F4F1EA',0)).join('')+R(86,96,28,40,'none',2.2)+T(100,94,'',1);
   p+=S('M86,124 L74,140 L86,138 Z M114,124 L126,140 L114,138 Z','#1E1E22',1.6)+S('M88,136 L112,136 L110,142 L90,142 Z','#3B3A3A',1.4);
   return p+[[46,40],[154,56],[40,110],[160,120]].map(([x,y])=>star4(x,y,4,'#F2D24A')).join('');},
 9:id=>{ // four à micro-ondes
   let p=R(28,46,144,88,'#E8ECF0',2.6,6)+R(38,56,90,68,'#3B3A3A',2,4)+R(44,62,78,56,'#5A6A7A',1.2,3)+`<ellipse cx="83" cy="108" rx="26" ry="5" fill="#fff" opacity=".2"/>`+S('M70,104 C70,94 96,94 96,104 Z','#F2D24A',1.4);
   p+=`<path d="M48,66 L60,66" stroke="#fff" stroke-width="2" opacity=".4"/>`+R(136,58,28,12,'#2B3E2B',1.4,2)+T(150,67,'1:30',8,'#7FD87F','middle',700);
   return p+[0,1,2].map(r=>[0,1].map(c=>R(138+c*14,76+r*12,10,8,'#F4F1EA',1.2,2)).join('')).join('')+R(138,112,24,8,'#4FC05A',1.2,2)+L(36,134,36,140,3)+L(164,134,164,140,3);},
 10:id=>{ // Pascaline : boîte de laiton à roues
   let p=R(22,56,156,70,'#C9A86A',2.6,4)+R(22,56,156,14,'#B8955A',2,4)+[...Array(6)].map((_,i)=>R(32+i*24,60,14,7,'#F4F1EA',1.2,1)+T(39+i*24,66.4,'1964'.padStart(6,'0')[i],6.4,INK,'middle',700)).join('');
   p+=[...Array(6)].map((_,i)=>{const x=39+i*24;return C(x,98,10,'#E8C97A',1.8)+[...Array(10)].map((_,k)=>{const a=k*Math.PI/5;return C((x+7*Math.cos(a)).toFixed(1),(98+7*Math.sin(a)).toFixed(1),1,INK,0)}).join('')+C(x,98,2.4,'#6B4426',1)+L(x,98,x+6,92,1.2);}).join('');
   return p+R(22,126,156,8,'#8A6A3A',2,2);},
 11:id=>{ // stéthoscope
   let p=SC('M68,30 C60,60 66,86 100,92 C134,86 140,60 132,30',INK,6)+SC('M68,30 C60,60 66,86 100,92 C134,86 140,60 132,30','#5C5C5C',3.6)+C(68,26,5,SILVER,1.6)+C(132,26,5,SILVER,1.6);
   p+=SC('M100,92 L100,104 C100,124 128,130 138,118',INK,6)+SC('M100,92 L100,104 C100,124 128,130 138,118','#5C5C5C',3.6);
   return p+C(146,118,16,SILVER,2.4)+C(146,118,10,'#E8ECF0',1.6)+`<path d="M138,110 A10,10 0 0 1 148,106" fill="none" stroke="#fff" stroke-width="2" opacity=".8"/>`+E(100,92,6,3,0,SILVER,1.4);},
 12:id=>{ // cube à facettes de couleur
   const cols={t:['#F4F1EA','#F2D24A','#F4F1EA','#E8443A','#F4F1EA','#4FC05A','#F2D24A','#F4F1EA','#3C6FF0'],l:['#E8443A','#E8443A','#3C6FF0','#4FC05A','#E8443A','#F28C3A','#E8443A','#F2D24A','#E8443A'],r:['#3C6FF0','#4FC05A','#3C6FF0','#3C6FF0','#F28C3A','#3C6FF0','#F4F1EA','#3C6FF0','#4FC05A']};
   const O={x:100,y:84},u=[22,-12],v=[-22,-12],w=[0,26];
   const quad=(o,a,b,col)=>S(`M${o[0]},${o[1]} L${o[0]+a[0]},${o[1]+a[1]} L${o[0]+a[0]+b[0]},${o[1]+a[1]+b[1]} L${o[0]+b[0]},${o[1]+b[1]} Z`,col,1.8);
   let p='';const s=1/3;
   for(let i=0;i<3;i++)for(let j=0;j<3;j++){const o=[O.x+(u[0]*i+v[0]*j)*s*1.6,O.y-10+(u[1]*i+v[1]*j)*s*1.6];p+=quad(o,[u[0]*s*1.6,u[1]*s*1.6],[v[0]*s*1.6,v[1]*s*1.6],cols.t[i*3+j]);}
   for(let i=0;i<3;i++)for(let j=0;j<3;j++){const o=[O.x+v[0]*1.6*i*s,O.y-10+v[1]*1.6*i*s+w[1]*1.6*j*s];p+=quad(o,[v[0]*s*1.6,v[1]*s*1.6],[0,w[1]*s*1.6],cols.l[i*3+j]);}
   for(let i=0;i<3;i++)for(let j=0;j<3;j++){const o=[O.x+u[0]*1.6*i*s,O.y-10+u[1]*1.6*i*s+w[1]*1.6*j*s];p+=quad(o,[u[0]*s*1.6,u[1]*s*1.6],[0,w[1]*s*1.6],cols.r[i*3+j]);}
   return p;},
 13:id=>{ // brevet et son sceau
   let p=S('M48,24 L142,24 L152,34 L152,144 L48,144 Z','#F8F2E6',2.4)+S('M142,24 L142,34 L152,34 Z','#E8E2D4',1.6);
   p+=R(64,36,72,6,'#3B3A3A',0,2)+[52,62,72,82,92].map((y,i)=>R(62,y,i%2?64:76,3,'#9A9A9A',0,1.5)).join('')+SC('M70,104 C76,112 84,110 90,102 C94,98 98,106 104,104',INK,1.6);
   p+=S('M118,112 L112,148 L120,142 L126,150 L130,114 Z M134,112 L140,148 L132,142 L126,150 L122,114 Z','#C9443A',1.6);
   return p+C(126,112,17,'#B5302A',2.2)+C(126,112,11,'#C9443A',1.4)+star5(126,112,6,'#E8574A',.8);},
};
