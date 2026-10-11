/* --- Logique : énigmes, raisonnements et suites --- */
const ltile=(x,y,w,h,t,size,fill='#F8F2E6',col=INK)=>R(x+2,y+4,w,h,'#9A8F7E',0,5)+R(x,y,w,h,fill,2.2,5)+T(x+w/2,y+h/2+size*.34,t,size,col,'middle',800);
const match=(x1,y1,x2,y2)=>L(x1,y1,x2,y2,5.4,INK)+L(x1,y1,x2,y2,3.4,'#E8C99A')+(()=>{const dx=x2-x1,dy=y2-y1,n=Math.hypot(dx,dy);return E((x2-dx/n*3).toFixed(1),(y2-dy/n*3).toFixed(1),5,3.6,Math.atan2(dy,dx)*180/Math.PI,'#C9443A',1.4);})();
const die=(x,y,s,n,fill='#F8F6F0',dot=INK)=>{const P={1:[[0,0]],2:[[-1,-1],[1,1]],3:[[-1,-1],[0,0],[1,1]],4:[[-1,-1],[1,-1],[-1,1],[1,1]],5:[[-1,-1],[1,-1],[0,0],[-1,1],[1,1]],6:[[-1,-1],[1,-1],[-1,0],[1,0],[-1,1],[1,1]]};
  return R(x-s/2+2,y-s/2+4,s,s,'#9A8F7E',0,s*.18)+R(x-s/2,y-s/2,s,s,fill,2.2,s*.18)+P[n].map(([a,b])=>C(x+a*s*.27,y+b*s*.27,s*.08,dot,0)).join('');};
SUBJECTS['logic.puzzles']={
 1:id=>{ // point d'interrogation
   let p=`<circle cx="100" cy="80" r="56" fill="#F2D24A" opacity=".15"/>`;
   p+=`<text x="104" y="132" font-family="Fraunces, Georgia, serif" font-weight="800" font-size="120" fill="#B8892A" text-anchor="middle">?</text><text x="100" y="128" font-family="Fraunces, Georgia, serif" font-weight="800" font-size="120" fill="#F2D24A" stroke="${INK}" stroke-width="2.4" text-anchor="middle">?</text>`;
   return p+[[44,40],[156,46],[150,128],[46,124]].map(([x,y],i)=>star4(x,y,5-i%2,'#F2D24A')).join('');},
 2:id=>{ // allumettes : quatre triangles avec six allumettes
   let p=match(58,124,100,52)+match(142,124,58,124)+match(100,52,142,124)+match(100,52,100,100)+match(58,124,100,100)+match(142,124,100,100);
   return p+`<circle cx="160" cy="44" r="16" fill="#F28C3A" opacity=".2"/>`+L(150,70,166,40,4,'#E8C99A')+S('M166,40 C160,32 164,24 170,20 C172,28 176,32 170,40 Z','#F28C3A',1.4)+E(166,40,4,3,-60,'#3B3A3A',1);},
 3:id=>{ // réveil : les aiguilles se rejoignent
   let p=[60,140].map((x,i)=>rot(i?30:-30,x,40,S(`M${x-18},48 C${x-18},30 ${x+18},30 ${x+18},48 Z`,'#E8B030',2.2))).join('')+R(94,26,12,10,'#E8B030',1.6,2);
   p+=L(64,134,56,148,4)+L(136,134,144,148,4)+C(100,92,48,'#E8443A',2.6)+C(100,92,40,'#fff',2);
   for(let i=0;i<12;i++){const a=i*30*Math.PI/180;p+=L((100+33*Math.sin(a)).toFixed(1),(92-33*Math.cos(a)).toFixed(1),(100+38*Math.sin(a)).toFixed(1),(92-38*Math.cos(a)).toFixed(1),i%3?1:2.2);}
   return p+SC('M100,96 L100,58',INK,2.2)+SC('M100,96 L100,68',INK,4)+C(100,92,3.4,GOLD,1.2);},
 4:id=>{ // gâteau d'anniversaire
   let p=E(100,134,62,10,0,'#E8ECF0',2.2)+R(46,96,108,38,'#F4C6D0',2.4,6)+R(56,64,88,34,'#FBE6EC',2.4,6);
   p+=S('M56,72 C64,80 70,74 78,80 C86,86 92,76 100,80 C108,86 116,76 122,82 C130,86 136,76 144,72 L144,70 C144,66 140,64 136,64 L64,64 C60,64 56,66 56,70 Z','#fff',1.6)+S('M46,104 C56,112 66,102 76,110 C88,118 96,104 108,110 C120,118 130,104 140,110 C146,112 150,108 154,104 L154,102 C154,98 150,96 146,96 L54,96 C50,96 46,98 46,102 Z','#fff',1.6);
   p+=[[66,118],[86,122],[112,120],[134,118]].map(([x,y],i)=>C(x,y,3,['#E8443A','#3C6FD0','#F2D24A','#4FC05A'][i],1)).join('');
   return p+[72,90,108,126].map((x,i)=>R(x-3,38,6,26,['#9FD3F0','#F2D24A','#E8838A','#9CC27A'][i],1.4,2)+S(`M${x},26 C${x+5},32 ${x+4},36 ${x},38 C${x-4},36 ${x-5},32 ${x},26 Z`,'#F28C3A',1.2)).join('');},
 5:id=>{ // échiquier et carrés cachés
   let p='';const s=13,x0=48,y0=32;
   for(let r=0;r<8;r++)for(let c=0;c<8;c++)p+=`<rect x="${x0+c*s}" y="${y0+r*s}" width="${s}" height="${s}" fill="${(r+c)%2?'#6B4426':'#F4E2C0'}"/>`;
   p+=R(x0,y0,8*s,8*s,'none',2.6,1);
   return p+R(x0+s-1,y0+s-1,2*s+2,2*s+2,'none',3,2).replace(INK,'#E8443A')+R(x0+4*s-1,y0+3*s-1,3*s+2,3*s+2,'none',3,2).replace(INK,'#3C9AF0')+R(x0+s*.5,y0+5.5*s,s*2,s*2,'none',3,2).replace(INK,'#F2D24A');},
 6:id=>{ // tableau de matchs : 6 équipes
   let p='';const s=16,x0=52,y0=32;const cols=['#E8443A','#F28C3A','#F2D24A','#4FC05A','#3C6FF0','#8B5CF6'];
   for(let r=0;r<6;r++){p+=C(x0-10,y0+r*s+s/2,5,cols[r],1.2)+C(x0+r*s+s/2,y0-10,5,cols[r],1.2);
     for(let c=0;c<6;c++){p+=`<rect x="${x0+c*s}" y="${y0+r*s}" width="${s}" height="${s}" fill="${r===c?'#C9C2B6':c>r?'#EAF4E8':'#fff'}" stroke="${INK}" stroke-width=".8"/>`;if(c>r)p+=SC(`M${x0+c*s+4},${y0+r*s+8} L${x0+c*s+7},${y0+r*s+12} L${x0+c*s+12},${y0+r*s+4}`,'#3E8A3A',1.8);}}
   return p+R(x0,y0,6*s,6*s,'none',2.2,1);},
 7:id=>{ // balance à plateaux
   let p=R(92,128,16,8,WOOD,1.8,1)+R(72,136,56,10,WOOD,2,3)+L(100,128,100,40,4)+C(100,36,5,GOLD,1.6);
   p+=rot(-10,100,44,L(36,44,164,44,3.4)+SC('M44,44 L30,92 M44,44 L58,92 M156,44 L142,92 M156,44 L170,92',INK,1.2)+S('M24,92 L64,92 C60,102 28,102 24,92 Z',GOLD,2)+S('M136,92 L176,92 C172,102 140,102 136,92 Z',GOLD,2)
     +[38,50].map(x=>C(x,86,6,'#E9B949',1.4)).join('')+C(44,76,6,'#E9B949',1.4)+[150,162].map(x=>C(x,86,6,'#E9B949',1.4)).join('')+C(156,76,6,'#C9CED4',1.4));
   return p+S('M94,44 L100,58 L106,44 Z','#C9443A',1);},
 8:id=>{ // deux trains face à face
   let p=L(10,120,190,120,2.4)+[...Array(9)].map((_,i)=>L(14+i*21,122,20+i*21,128,2,WOOD)).join('');
   const train=(x,f,c)=>`<g transform="translate(${x} 0) scale(${f} 1)">${S('M0,116 L0,82 L36,82 C50,82 58,94 62,116 Z',c,2.2)+R(6,88,16,12,'#DDF0F8',1.4,2)+S('M40,88 L50,88 C54,92 56,98 56,104 L40,104 Z','#DDF0F8',1.4)+C(14,118,5,'#3B3A3A',1.4)+C(46,118,5,'#3B3A3A',1.4)}</g>`;
   p+=train(16,1,'#E8443A')+train(184,-1,'#3C6FF0');
   return p+SC('M30,64 L74,64',INK,2.2)+S('M72,58 L82,64 L72,70 Z',INK,1)+SC('M170,64 L126,64',INK,2.2)+S('M128,58 L118,64 L128,70 Z',INK,1)+T(100,56,'?',22,'#C9443A','middle',800);},
 9:id=>{ // calendrier
   let p=R(46,30,108,112,'#fff',2.4,6)+R(46,30,108,30,'#E8443A',2.4,6)+R(46,52,108,8,'#E8443A',0)+[70,100,130].map(x=>R(x-3,22,6,16,SILVER,1.4,3)).join('');
   p+=T(100,52,'janvier',15,'#fff','middle',800)+T(100,112,'1',50,INK,'middle',800)+T(100,132,'vendredi',12,'#C9443A','middle',700);
   return p+S('M154,124 L154,142 L136,142 Z','#E8E2D4',1.6);},
 10:id=>{ // le loup, la chèvre et le chou (légendaire)
   let g=`<defs><linearGradient id="${id}sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F6D2A0"/><stop offset="1" stop-color="#FBEFD8"/></linearGradient></defs><rect x="20" y="10" width="160" height="150" fill="url(#${id}sk)"/>`;
   g+=C(146,40,11,'#F2B441',0)+S('M10,84 C34,78 56,80 74,88 L74,160 L10,160 Z','#8CB86A',1.6)+S('M190,84 C166,78 144,80 126,88 L126,160 L190,160 Z','#8CB86A',1.6);
   g+=S('M72,88 C88,92 112,92 128,88 L128,160 L72,160 Z','#5B9AD0',1.4)+waves(76,120,3,1,.35);
   const goat=`<g transform="translate(58 86) scale(1.35)">${E(0,0,13,7.4,0,'#2B2B2B',0)+R(-10,4,3,12,'#2B2B2B',0)+R(-4,4,3,12,'#2B2B2B',0)+R(4,4,3,12,'#2B2B2B',0)+R(9,4,3,12,'#2B2B2B',0)}<path fill="#2B2B2B" d="M8,-4 L14,-14 L22,-12 L20,-6 L14,-2 Z M14,-14 C12,-22 6,-24 2,-22 C8,-20 10,-18 12,-13 Z M16,-6 L16,0 L19,-6 Z M-13,-3 L-17,-8 L-12,-5 Z"/></g>`;
   const wolf=`<g transform="translate(140 82) scale(1.35)"><g fill="#2B2B2B">${E(0,0,15,8,0,'#2B2B2B',0)}<path d="M-11,4 L-13,16 L-10,16 L-8,5 Z M-4,5 L-5,16 L-2,16 L-1,6 Z M5,5 L6,16 L9,16 L8,4 Z M11,3 L13,16 L16,16 L14,1 Z M-10,-4 L-18,-12 L-20,-20 L-16,-16 L-14,-20 L-12,-14 L-6,-10 Z M-18,-12 L-28,-8 L-26,-5 L-16,-6 Z M14,-2 C24,-6 30,0 32,8 C26,4 20,4 14,4 Z"/></g></g>`;
   const boat=`<g transform="translate(100 120) scale(1.3) translate(-100 -120)">${S('M78,116 L122,116 L116,128 L84,128 Z','#8A5A34',2)+L(82,121,118,121,1,INK,.4)+SC('M114,116 L126,100',WOOD,2.2)+C(100,108,8,'#7FB86A',1.6)+SC('M95,104 C98,110 102,110 105,104 M96,112 C99,106 103,106 105,112',INK,1,'opacity=".5"')}</g>`;
   return inMedal(id+'rv',g+boat)+medalRing()+goat+wolf+[[24,26],[178,30]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
};
SUBJECTS['logic.reasoning']={
 1:id=>{ // trois cercles
   return `<g opacity=".7">${C(80,68,34,'#E8838A',0)+C(120,68,34,'#9FD3F0',0)+C(100,102,34,'#F2D24A',0)}</g>`+C(80,68,34,'none',2.4)+C(120,68,34,'none',2.4)+C(100,102,34,'none',2.4)+star5(100,80,6,'#fff',1.2);},
 2:id=>ltile(18,58,54,48,'A',30)+T(100,94,'⇒',36,'#C9443A','middle',800)+ltile(128,58,54,48,'B',30,'#FFF3D0'),
 3:id=>{ // deux portes : une seule question (légendaire)
   const wall='M18,30 L182,30 L182,148 L18,148 Z';
   let p=S(wall,'#C9B79C',2.4)+clipTo(id+'wl',wall,[...Array(7)].map((_,r)=>[...Array(9)].map((_,c)=>`<rect x="${8+c*21+(r%2?10:0)}" y="${30+r*17}" width="21" height="17" fill="none" stroke="${INK}" stroke-width=".8" opacity=".35"/>`).join('')).join(''))+S(wall,'none',2.4);
   const door=(x,c)=>S(`M${x},148 L${x},86 C${x},66 ${x+44},66 ${x+44},86 L${x+44},148 Z`,'#5A5A5A',2.4)+S(`M${x+5},148 L${x+5},88 C${x+5},72 ${x+39},72 ${x+39},88 L${x+39},148 Z`,c,2)+[0,1,2].map(i=>L(x+16+i*6,78,x+16+i*6,148,1,INK,.35)).join('')+C(x+33,116,2.4,GOLD,1);
   p+=door(36,'#B5302A')+door(120,'#2F4E8C');
   const torch=x=>R(x-3,70,6,22,WOOD,1.6,1)+S(`M${x},52 C${x+8},60 ${x+6},68 ${x},70 C${x-6},68 ${x-8},60 ${x},52 Z`,'#F28C3A',1.4)+`<circle cx="${x}" cy="62" r="14" fill="#FFE7A0" opacity=".35"/>`;
   p+=torch(100)+T(58,62,'?',24,'#F2D24A','middle',800)+T(142,62,'?',24,'#F2D24A','middle',800);
   return p+[[16,20],[184,22]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
 4:id=>{ // arbre généalogique
   const n=(x,y,c)=>C(x,y,12,c,2.2)+C(x,y-3,4,'#fff',0)+S(`M${x-7},${y+8} C${x-6},${y+2} ${x+6},${y+2} ${x+7},${y+8} Z`,'#fff',0);
   let p=SC('M70,44 L70,60 L130,60 L130,44 M100,60 L100,84 M60,100 L60,84 L140,84 L140,100 M140,112 L140,124',INK,2);
   return p+n(70,36,'#3C6FD0')+n(130,36,'#E8838A')+n(60,108,'#4FC05A')+n(100,108,'#F2B441')+n(140,108,'#8B5CF6')+L(100,84,100,96,2)+n(140,136,'#E8443A');},
 5:id=>{ // trouver l'intrus
   let p=[[48,58],[84,58],[120,58],[156,58],[64,104],[136,104]].map(([x,y])=>C(x,y,14,'#9FD3F0',2.2)).join('');
   return p+S('M100,86 L117,116 L83,116 Z','#E8443A',2.4)+C(100,105,25,'none',2).replace('stroke-width="2"','stroke-width="2" stroke-dasharray="4 3"');},
 6:id=>{ // cadenas à lettres
   let p=SC('M66,64 L66,48 C66,28 82,20 100,20 C118,20 134,28 134,48 L134,64',INK,12)+SC('M66,64 L66,48 C66,28 82,20 100,20 C118,20 134,28 134,48 L134,64',SILVER,7);
   p+=R(40,62,120,80,'#3B3A3A',2.6,8)+`<path d="M48,70 L48,134" stroke="#fff" stroke-width="2" opacity=".3"/>`;
   return p+['R','O','T'].map((t,i)=>{const x=54+i*32;return R(x,78,28,48,'#F4F1EA',2,3)+T(x+14,72+16,'QPS'[i],9,'#9A9A9A','middle',700)+T(x+14,110,t,20,INK,'middle',800)+L(x,96,x+28,96,.8,INK,.3)+L(x,114,x+28,114,.8,INK,.3);}).join('');},
 7:id=>{ // page d'agenda
   let p=R(40,24,120,124,'#fff',2.4,4)+R(40,24,120,22,'#3C6FD0',2.4,4)+T(100,40,'mars',13,'#fff','middle',800);
   const d=['L','M','M','J','V','S','D'];p+=d.map((t,i)=>T(52+i*16,60,t,9,INK,'middle',800)).join('');
   for(let k=0;k<31;k++){const c=k%7,r=Math.floor(k/7);p+=T(52+c*16,78+r*15,String(k+1),8,c===0?'#C9443A':'#5A5A5A','middle',700);}
   return p+[0,1,2,3,4].map(r=>C(52,75+r*15,6.4,'none',1.6).replace(INK,'#C9443A')).join('');},
 8:id=>{ // podium
   let p=R(26,96,48,50,'#C9CED4',2.4,2)+R(76,72,48,74,'#F2D24A',2.4,2)+R(126,110,48,36,'#D9A070',2.4,2);
   p+=T(50,128,'2',24,INK,'middle',800)+T(100,116,'1',28,INK,'middle',800)+T(150,136,'3',20,INK,'middle',800);
   return p+star5(100,48,14,'#F2D24A',1.6)+star4(50,78,5,'#C9CED4')+star4(150,92,5,'#D9A070');},
 9:id=>die(72,80,52,6,'#E8443A','#fff')+die(132,92,44,1),
 10:id=>{ // chiffres : divisibilité par 4
   let p=ltile(22,50,36,52,'1',30)+ltile(60,50,36,52,'2',30)+ltile(104,50,36,52,'3',30,'#FFF3D0')+ltile(142,50,36,52,'6',30,'#FFF3D0');
   return p+SC('M104,112 L104,118 L178,118 L178,112',`#C9443A`,2)+T(141,136,'÷ 4',15,'#C9443A','middle',800);},
};
SUBJECTS['logic.sequences']={
 1:id=>{ // escalier
   let p='';for(let i=0;i<5;i++)p+=R(28+i*28,124-(i+1)*18,28,(i+1)*18,['#9FD3F0','#9CC27A','#F2D24A','#F2B441','#E8838A'][i],2.2,2);
   return p+[0,1,2,3].map(i=>SC(`M${44+i*28},${96-i*18} C${50+i*28},${84-i*18} ${62+i*28},${80-i*18} ${70+i*28},${86-i*18}`,INK,1.6)+S(`M${66+i*28},${82-i*18} L${72+i*28},${88-i*18} L${64+i*28},${90-i*18} Z`,INK,1)).join('')+L(24,124,176,124,2.4);},
 2:id=>{ // grains qui doublent
   const sq=(x,n,f)=>{let q=R(x,58,34,34,f,2,2);const pts=[[17,17],[10,24],[24,10],[10,10],[24,24],[17,6],[17,28],[6,17]];for(let i=0;i<n;i++)q+=E(x+pts[i][0],58+pts[i][1],3.4,2,30+i*40,'#FBF6EA',1);return q;};
   let p=sq(14,1,'#F4E2C0')+sq(58,2,'#6B4426')+sq(102,4,'#F4E2C0')+sq(146,8,'#6B4426');
   return p+[0,1,2].map(i=>T(56+i*44,52,'×2',11,'#C9443A','middle',800)).join('')+T(100,124,'…',22,INK,'middle',800);},
 3:id=>{ // cubes : 1, 8, 27
   const cube=(x,y,s,n,c)=>{let q='';for(let a=0;a<n;a++)for(let b=0;b<n;b++){q+=S(`M${x+a*s},${y-b*s} L${x+(a+1)*s},${y-b*s} L${x+(a+1)*s},${y-(b+1)*s} L${x+a*s},${y-(b+1)*s} Z`,c,1.2);}
     for(let a=0;a<n;a++)for(let k=0;k<n;k++)q+=S(`M${x+a*s+k*s*.5},${y-n*s-k*s*.5} L${x+(a+1)*s+k*s*.5},${y-n*s-k*s*.5} L${x+(a+1)*s+(k+1)*s*.5},${y-n*s-(k+1)*s*.5} L${x+a*s+(k+1)*s*.5},${y-n*s-(k+1)*s*.5} Z`,'#fff',1.2);
     for(let b=0;b<n;b++)for(let k=0;k<n;k++)q+=S(`M${x+n*s+k*s*.5},${y-b*s-k*s*.5} L${x+n*s+(k+1)*s*.5},${y-b*s-(k+1)*s*.5} L${x+n*s+(k+1)*s*.5},${y-(b+1)*s-(k+1)*s*.5} L${x+n*s+k*s*.5},${y-(b+1)*s-k*s*.5} Z`,'#C9D2DA',1.2);return q;};
   return cube(22,120,12,1,'#9FD3F0')+cube(56,120,12,2,'#9CC27A')+cube(108,120,12,3,'#F2B441')+L(14,122,186,122,1.6,INK,.4);},
 4:id=>{ // spirale de Fibonacci (légendaire) : carrés 1, 1, 2, 3, 5, 8
   const x0=35,y0=44,u=10,sq=[[0,0,8,'#F2B441'],[8,0,5,'#E8838A'],[10,5,3,'#9FD3F0'],[8,6,2,'#9CC27A'],[8,5,1,'#F2D24A'],[9,5,1,'#F2D24A']];
   let p=`<circle cx="100" cy="84" r="64" fill="#F2D24A" opacity=".14"/>`;
   p+=sq.map(([a,b,n,c])=>R(x0+a*u,y0+b*u,n*u,n*u,c,n>1?2.2:1.4,2)+(n>1?T(x0+(a+n/2)*u,y0+(b+n/2)*u+n*1.6,String(n),n*4.4,INK,'middle',800):'')).join('');
   const P=(a,b)=>`${x0+a*u},${y0+b*u}`;
   p+=SC(`M${P(0,8)} A80,80 0 0 1 ${P(8,0)} A50,50 0 0 1 ${P(13,5)} A30,30 0 0 1 ${P(10,8)} A20,20 0 0 1 ${P(8,6)} A10,10 0 0 1 ${P(9,5)} A10,10 0 0 1 ${P(10,6)}`,INK,3.4)+SC(`M${P(0,8)} A80,80 0 0 1 ${P(8,0)} A50,50 0 0 1 ${P(13,5)} A30,30 0 0 1 ${P(10,8)} A20,20 0 0 1 ${P(8,6)} A10,10 0 0 1 ${P(9,5)} A10,10 0 0 1 ${P(10,6)}`,'#fff',1.2,'opacity=".7"');
   return p+[[24,28],[176,30],[24,140],[176,138]].map(([x,y],i)=>star4(x,y,5-i%2,'#F2D24A')).join('');},
 5:id=>{ // lettres des jours de la semaine
   const L7=['L','M','M','J','V','S','D'];
   return L7.map((t,i)=>ltile(14+i*25,i<4?52:92,22,30,i<4?t:'?',16,i<4?'#F8F2E6':'#FFF3D0',i<4?INK:'#C9443A')).join('')+SC('M118,84 C126,96 132,96 140,92',INK,1.4,'opacity=".5"');},
};
