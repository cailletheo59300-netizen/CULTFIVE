// Sujets des pages Espace et Relief. Chaque fonction reçoit l'identifiant de motif de hachures (« cN »).
const star4=(x,y,r,fill=GOLD)=>`<path d="M${x},${y-r} Q${x},${y} ${x+r},${y} Q${x},${y} ${x},${y+r} Q${x},${y} ${x-r},${y} Q${x},${y} ${x},${y-r} Z" fill="${fill}" stroke="${INK}" stroke-width=".9"/>`;
function clipCircle(id,cx,cy,r,inner){return `<clipPath id="${id}"><circle cx="${cx}" cy="${cy}" r="${r}"/></clipPath><g clip-path="url(#${id})">${inner}</g>`;}
const waves=(x,y,n,w=1.4,o=.55)=>[...Array(n)].map((_,i)=>S(`M${x},${y+i*7} q10,-5 20,0 t20,0 t20,0 t20,0 t20,0 t20,0`,'none',w,`opacity="${o}"`)).join('');

SUBJECTS['science.space']={
 1:id=>{ // le Soleil et ses éruptions
   let p=`<defs><radialGradient id="${id}sun" cx="45%" cy="40%" r="60%"><stop offset="0" stop-color="#FFE8A3"/><stop offset=".6" stop-color="#F2B441"/><stop offset="1" stop-color="#D9822B"/></radialGradient></defs>`;
   p+=`<defs><radialGradient id="${id}glo"><stop offset=".7" stop-color="#FFD66B" stop-opacity=".55"/><stop offset="1" stop-color="#FFD66B" stop-opacity="0"/></radialGradient></defs><circle cx="96" cy="86" r="66" fill="url(#${id}glo)"/>`+C(96,86,46,`url(#${id}sun)`,2.4);
   p+=SC('M54,64 C40,48 50,30 66,40',WAX,3)+SC('M134,58 C150,40 166,54 148,70',WAX,3)+SC('M136,118 C152,128 150,146 132,134',WAX,2.6)+SC('M58,116 C42,128 50,140 64,132',WAX,2.4);
   let r=5;for(let i=0;i<22;i++){r=(r*9301+49297)%233280;const a=r/233280*Math.PI*2;r=(r*9301+49297)%233280;const d=Math.sqrt(r/233280)*38;p+=C((96+Math.cos(a)*d).toFixed(1),(86+Math.sin(a)*d).toFixed(1),1.4,'#D9822B',0);}
   return p;},
 2:id=>{ // Lune et cratères
   let p=C(100,84,44,PAPER,2.4)+H('M100,40 A44,44 0 0 1 100,128 A30,44 0 0 0 100,40 Z','c2');
   p+=[[82,66,9],[112,98,12],[90,108,6],[118,62,5],[74,92,5],[104,76,4]].map(([x,y,r])=>C(x,y,r,'none',1.6)+`<path d="M${x-r*.7},${y+r*.3} A${r},${r} 0 0 0 ${x+r*.7},${y+r*.3}" fill="none" stroke="${INK}" stroke-width="1" opacity=".5"/>`).join('');
   return p+star4(40,40,6)+star4(160,124,5)+star4(152,40,4);},
 3:id=>{ // Vénus voilée, et Mercure
   let p=C(108,90,38,GOLD,2.4);
   p+=clipCircle('v3',108,90,38,[0,1,2,3,4].map(i=>S(`M60,${66+i*12} C84,${58+i*12} 100,${74+i*12} 156,${62+i*12}`,'none',1.6,'opacity=".55"')).join('')+H('M108,52 A38,38 0 0 1 108,128 Z','c3'));
   p+=C(108,90,38,'none',2.4)+C(52,48,12,PAPER,2)+H('M52,36 A12,12 0 0 1 52,60 Z','c3');
   return p+star4(160,36,5)+star4(36,120,4);},
 4:id=>{ // Terre penchée
   let p=S('M70,26 L130,142','none',1.8,'stroke-dasharray="4 4"')+C(100,84,40,PAPER,2.4);
   p+=clipCircle('e4',100,84,40,`<g transform="rotate(-23 100 84)">${[-24,-8,8,24].map(y=>`<ellipse cx="100" cy="${84+y}" rx="${Math.sqrt(1600-y*y)}" ry="4" fill="none" stroke="${INK}" stroke-width="1" opacity=".45"/>`).join('')}
     <path d="M76,70 C84,60 98,64 96,74 C94,82 82,82 80,92 C78,98 70,94 72,86 Z M104,92 C112,86 124,90 122,100 C120,110 108,114 104,106 Z M108,58 C116,54 126,60 122,66 Z" fill="${TONE}" stroke="${INK}" stroke-width="1.2"/></g>`+H('M100,44 A40,40 0 0 1 100,124 Z','c4'));
   p+=C(100,84,40,'none',2.4);
   return p+S('M138,42 C150,52 154,64 152,74','none',1.8)+S('M148,70 L152,76 L156,69','none',1.8)+T(118,22,'23°',11,INK,'middle');},
 5:id=>{ // Mars et Olympus Mons
   let g=F('M20,20 L180,20 L180,160 L20,160 Z','#EDC79B')+C(60,42,5,'#9C8F80',1.2)+C(142,34,3,'#9C8F80',1);
   g+=S('M10,112 C40,104 60,72 84,62 C94,58 106,58 116,62 C140,72 160,104 190,112 L190,160 L10,160 Z','#C2603A',2.4)+E(100,63,14,3.4,0,'#8E3E22',1.4);
   g+=H('M100,58 C106,58 112,60 116,62 C140,72 160,104 190,112 L190,160 L100,160 Z',id)+SC('M60,88 C70,90 78,96 82,104 M140,88 C130,90 122,96 118,104',INK,1.2,'opacity=".5"');
   g+=S('M10,126 C50,118 100,126 190,120 L190,160 L10,160 Z','#D9784A',1.8)+[[46,138,6],[140,142,4],[96,148,3]].map(([x,y,r])=>E(x,y,r,r*.4,0,'#B5522E',1)).join('');
   const fg=R(112,124,20,8,SILVER,1.4)+[114,122,130].map(x=>C(x+2,134,3,INK,0)).join('')+L(126,124,126,116,1.2)+R(122,112,8,5,SILVER,1);
   return inMedal(id+'ma',g)+medalRing()+`<g transform="translate(140 146) scale(2) translate(-122 -134)">${fg}</g>`;},
 6:id=>{ // Jupiter et sa Grande Tache rouge
   let p=C(100,84,46,PAPER,2.4);
   p+=clipCircle('j6',100,84,46,[[-34,8,GOLD],[-18,6,TONE],[-4,10,GOLD],[14,7,TONE],[28,9,GOLD]].map(([y,h,c])=>`<rect x="50" y="${84+y}" width="100" height="${h}" fill="${c}" opacity=".8"/>`).join('')
     +[-26,-12,6,22,38].map(y=>S(`M50,${84+y} C80,${80+y} 120,${88+y} 150,${84+y}`,'none',1,'opacity=".5"')).join('')+H('M100,38 A46,46 0 0 1 100,130 Z','c6'));
   p+=`<ellipse cx="118" cy="104" rx="12" ry="7" fill="${WAX}" stroke="${INK}" stroke-width="1.6"/>`+C(100,84,46,'none',2.4);
   return p+C(162,46,4,PAPER,1.4)+C(40,120,3,PAPER,1.2);},
 7:id=>{ // Saturne et ses anneaux
   const ring=(half)=>`<g transform="rotate(-16 100 84)">`+[[70,19,'#E9D2A0',7],[60,15,'#D9B877',4],[52,12.5,'#F2E3BF',3]].map(([rx,ry,c,w])=>`<path d="M${100-rx},84 A${rx},${ry} 0 0 ${half} ${100+rx},84" fill="none" stroke="${c}" stroke-width="${w}"/>`).join('')+`<path d="M30,84 A70,19 0 0 ${half} 170,84 M48,84 A52,12 0 0 ${half} 152,84" fill="none" stroke="${INK}" stroke-width="1.6"/>`+`</g>`;
   let p=ring(1);
   p+=C(100,84,34,'#E2B865',2.4)+clipCircle(id+'sb',100,84,34,[-22,-12,-4,6,16,26].map((y,i)=>`<rect x="60" y="${84+y}" width="80" height="${i%2?4:6}" fill="${i%2?'#B9853C':'#F3D9A0'}" opacity=".7"/>`).join('')+`<path d="M100,50 A34,34 0 0 1 100,118 A22,34 0 0 0 100,50 Z" fill="${INK}" opacity=".18"/>`);
   p+=ring(0)+C(100,84,34,'none',2.4);
   return p+C(160,40,6,'#E9A84E',1.4)+C(44,128,3.4,'#D5DADF',1.1)+C(150,132,2.6,'#D5DADF',1)+star4(36,36,5)+star4(172,96,4)+star4(70,24,3);},
 8:id=>{ // Uranus couchée
   let p=L(40,84,160,84,1.6,INK,.8)+`<g transform="rotate(82 100 84)"><ellipse cx="100" cy="84" rx="54" ry="13" fill="none" stroke="${INK}" stroke-width="1.6"/></g>`;
   p+=C(100,84,30,'#BFE3E8',2.4)+H('M100,54 A30,30 0 0 1 100,114 Z','c8');
   p+=`<g transform="rotate(82 100 84)"><path d="M46,84 A54,13 0 0 0 154,84" fill="none" stroke="${INK}" stroke-width="2.2"/></g>`;
   return p+S('M150,70 L160,84 L150,98','none',1.6)+C(40,40,8,'#7FB3D5',1.8)+star4(160,36,5)+star4(36,128,4);},
 9:id=>{ // Pluton et son cœur
   const heart='M92,70 C84,58 66,60 66,76 C66,90 82,100 92,112 C102,100 118,90 118,76 C118,60 100,58 92,70 Z';
   let g=F('M44,96 C60,104 80,116 92,118 C80,128 60,132 48,120 C44,112 42,104 44,96 Z','#8A5A34',.7)+F('M118,60 C130,66 138,84 134,100 C126,96 120,86 118,74 Z','#B98B5E',.6);
   g+=S(heart,'#F8EEDC',1.2,'stroke-opacity=".45"')+`<path d="M44,84 A48,48 0 0 0 140,84 A48,48 0 0 1 44,84 Z" fill="${INK}" opacity=".12"/>`;
   let p=C(92,84,48,'#D9BE96',2.4)+clipTo(id+'pl','M44,84 A48,48 0 1 1 140,84 A48,48 0 1 1 44,84 Z',g)+C(92,84,48,'none',2.4);
   return p+C(154,44,12,'#B8B0A4',1.8)+star4(36,36,4)+star4(160,120,3)+star4(30,130,3);},
 10:id=>{ // le système solaire
   let p=`<defs><radialGradient id="${id}ss"><stop offset="0" stop-color="#FFE8A3"/><stop offset="1" stop-color="#E9A84E"/></radialGradient></defs>`;
   const orb=[18,27,36,46,60,72,84,96];
   p+=orb.map(r=>`<ellipse cx="100" cy="84" rx="${r*.62}" ry="${r*.26}" fill="none" stroke="${INK}" stroke-width=".8" opacity=".45"/>`).join('');
   p+=C(100,84,9,`url(#${id}ss)`,1.6);
   const pl=[[.2,2,'#9C8F80'],[2.2,3,'#E2B865'],[3.6,3.2,'#5B8FD0'],[5,2.6,'#C2603A'],[.8,6,'#D9B877'],[2.7,5,'#E2B865'],[4.3,4,'#9FD3DC'],[5.7,3.8,'#4C6FD6']];
   p+=pl.map(([a,r,c],i)=>C((100+Math.cos(a)*orb[i]*.62).toFixed(1),(84+Math.sin(a)*orb[i]*.26).toFixed(1),r,c,1.1)).join('');
   const sx=(100+Math.cos(2.7)*72*.62).toFixed(1),sy=(84+Math.sin(2.7)*72*.26).toFixed(1);
   return p+`<ellipse cx="${sx}" cy="${sy}" rx="9" ry="2.4" fill="none" stroke="${INK}" stroke-width="1"/>`+star4(40,40,4)+star4(160,130,4)+star4(150,36,3);},
 11:id=>{ // Grande Ourse et étoile polaire
   const st=[[40,112],[60,104],[78,104],[94,96],[104,76],[134,72],[132,98]];
   let p=`<path d="M${st.map(s=>s.join(',')).join(' L')} L94,96" fill="none" stroke="${INK}" stroke-width="1.4" stroke-dasharray="3 3"/>`;
   p+=S('M134,72 L148,34','none',1,'stroke-dasharray="2 4" opacity=".7"');
   return p+st.map(([x,y],i)=>star4(x,y,i>3?7:6)).join('')+star4(150,30,10,PAPER)+T(150,54,'Polaire',9,INK,'middle',800);},
 12:id=>{ // galaxie spirale
   let p=`<defs><radialGradient id="${id}gx"><stop offset="0" stop-color="#FFF4D0"/><stop offset=".35" stop-color="#E9C566" stop-opacity=".8"/><stop offset="1" stop-color="#7E5BC9" stop-opacity="0"/></radialGradient></defs>`;
   p+=E(100,84,62,40,-20,`url(#${id}gx)`,0);
   for(const k of [0,1]){let d='';for(let t=0;t<=1;t+=.02){const a=t*3.6*Math.PI+k*Math.PI,r=6+t*58;d+=(t?'L':'M')+(100+Math.cos(a)*r).toFixed(1)+','+(84+Math.sin(a)*r*.62).toFixed(1);}
     p+=`<g transform="rotate(-20 100 84)">${SC(d,'#B9A3F0',9,'opacity=".55"')+SC(d,'#FFF0C2',3.4)+SC(d,INK,.8,'opacity=".5"')}</g>`;}
   p+=C(100,84,10,'#FFF4D0',1.4);
   let r=3;for(let i=0;i<40;i++){r=(r*9301+49297)%233280;const x=30+r/233280*140;r=(r*9301+49297)%233280;const y=24+r/233280*120;p+=C(x.toFixed(1),y.toFixed(1),(.5+(i%3)*.4).toFixed(1),'#FFF0C2',0);}
   return p+star4(156,36,5)+star4(40,128,4);},
 13:id=>{ // Spoutnik au-dessus de la Terre
   let p=S('M14,160 C40,124 160,124 186,160 Z','#5B8FD0',2.2)+F('M50,142 C64,134 80,138 86,146 C76,150 60,150 50,142 Z',GREEN,.8)+F('M120,136 C134,132 146,138 150,146 C138,148 126,146 120,136 Z',GREEN,.8);
   p+=SC('M24,140 C50,118 150,118 176,140',PAPER,3,'stroke-opacity=".6"');
   p+=L(92,64,40,92,1.4)+L(94,70,48,106,1.4)+L(98,72,70,112,1.4)+L(96,58,44,70,1.4);
   p+=C(104,60,16,SILVER,2.2)+`<path d="M92,52 A16,16 0 0 1 116,50" fill="none" stroke="#fff" stroke-width="2.4" opacity=".8"/>`+SC('M104,76 L104,80',INK,1);
   return p+[10,18,26].map(r=>SC(`M${122+r*.4},${46-r*.6} A${r},${r} 0 0 1 ${124+r},${58}`,INK,1.4,'opacity=".55"')).join('')+star4(160,34,4)+star4(40,36,3);},
 14:id=>{ // Apollo 11 : le module lunaire
   let p=C(48,36,14,'#5B8FD0',1.8)+F('M40,28 C46,24 52,30 48,36 C44,40 38,36 40,28 Z',GREEN,.8)+F('M52,40 C58,38 60,44 56,46 Z',GREEN,.8)+`<path d="M34,36 A14,14 0 0 0 62,36 A14,10 0 0 1 34,36 Z" fill="${INK}" opacity=".35"/>`;
   p+=[[150,30],[166,52],[30,70],[136,18]].map(([x,y])=>star4(x,y,3,PAPER)).join('');
   p+=S('M26,124 C50,116 90,122 120,118 C150,114 168,118 176,120 C182,132 178,146 166,150 L36,150 C24,146 20,134 26,124 Z','#C9C6BF',2)+[[44,136,10],[150,140,8],[110,150,5]].map(([x,y,r])=>E(x,y,r,r*.35,0,'#B3AFA6',1)).join('');
   p+=L(84,96,70,124,2)+L(116,96,130,124,2)+L(90,98,92,124,2)+R(62,122,14,4,SILVER,1.2)+R(124,122,14,4,SILVER,1.2);
   p+=S('M76,78 L124,78 L128,100 L72,100 Z',GOLD,2.2)+H('M110,78 L124,78 L128,100 L112,100 Z',id)+[84,96,108].map(x=>L(x,80,x-1,98,.8,INK,.5)).join('');
   p+=S('M82,78 L84,58 L96,52 L110,54 L118,62 L118,78 Z',SILVER,2.2)+S('M90,62 L98,58 L104,64 L94,68 Z','#3B3A3A',1.2)+L(110,54,114,40,1.4)+C(114,38,3,SILVER,1);
   p+=L(150,120,150,72,1.8)+L(150,74,172,74,1.2)+clipTo(id+'us','M150,74 L172,74 L172,88 L150,88 Z',[0,1,2,3,4,5,6].map(i=>`<rect x="150" y="${74+i*2}" width="22" height="1" fill="${WAX}"/>`).join('')+`<rect x="150" y="74" width="9" height="7" fill="${BLUE}"/>`)+R(150,74,22,14,'none',1);
   return p+S('M96,140 c3,-4 9,-4 10,0 c1,4 -2,8 -6,8 c-4,0 -5,-4 -4,-8 Z',INK,0,'opacity=".35"');},
 15:id=>{ // Station spatiale internationale
   let p=L(26,84,174,84,3);
   for(const x of [36,60,140,164])for(const s of [-1,1])p+=S(`M${x-9},${84+s*8} L${x+9},${84+s*8} L${x+9},${84+s*40} L${x-9},${84+s*40} Z`,GOLD,1.6)+H(`M${x},${84+s*8} L${x+9},${84+s*8} L${x+9},${84+s*40} L${x},${84+s*40} Z`,'c15');
   p+=S('M84,74 L116,74 L116,94 L84,94 Z',PAPER,2)+S('M92,94 L92,110 L108,110 L108,94','none',2)+C(100,70,6,PAPER,1.8);
   return p+star4(100,30,5)+star4(40,140,4);},
};

SUBJECTS['geography.relief']={
 1:id=>{ // l'Everest et ses drapeaux de prière
   let p=S('M14,140 L58,74 L80,100 L102,30 L130,78 L148,62 L188,140 Z',PAPER,2.6);
   p+=S('M102,30 L116,54 L108,52 L102,62 L96,50 L88,56 Z','#FFFFFF',1.6)+S('M58,74 L68,88 L60,86 L54,92 L50,86 Z','#FFFFFF',1.4)+S('M148,62 L158,78 L150,76 L144,82 Z','#FFFFFF',1.4);
   p+=H('M102,30 L130,78 L148,62 L188,140 L120,140 C116,110 110,70 102,30 Z',id)+F('M14,140 L58,74 L80,100 L102,62 L120,140 Z','#C9B8A0',.35);
   p+=L(102,30,102,16,1.6)+S('M102,16 L116,20 L102,24 Z',WAX,1.2);
   const cols=[BLUE,PAPER,WAX,GREEN,GOLD];let q='M40,96 C64,88 84,80 100,62';p+=SC(q,INK,1);
   for(let i=0;i<10;i++){const t=i/10+.05,x=40+60*t,y=96-34*t+Math.sin(t*3.14)*4;p+=R(x.toFixed(1),y.toFixed(1),5,6,cols[i%5],.7);}
   return p+[[40,132,16],[70,138,12],[156,134,14]].map(([x,y,r])=>E(x,y,r,r*.4,0,'#FFFFFF',1.2)).join('');},
 2:id=>{ // mont Blanc, glacier et téléphérique
   let g=F('M20,20 L180,20 L180,150 L20,150 Z','#DCEBF0');
   g+=S('M10,130 L50,74 L76,96 L104,46 L134,84 L150,70 L192,130 Z',PAPER,2.4)+S('M104,46 L118,66 L110,64 L104,72 L98,62 L90,68 Z','#FFFFFF',1.4);
   g+=H('M104,46 L134,84 L150,70 L192,130 L120,130 C116,100 110,70 104,46 Z',id);
   g+=S('M96,84 C100,100 96,118 106,130 L120,130 C112,116 116,98 112,84 Z','#BFE0EC',1.6)+SC('M100,96 L110,96 M100,108 L112,108',INK,.9,'opacity=".5"');
   g+=S('M150,70 L152,52 L154,70 Z',INK,1)+L(40,128,152,52,1.2)+R(88,86,10,8,WAX,1.2)+L(93,86,93,82,1);
   g+=S('M10,128 C40,122 70,126 100,124 C130,122 160,126 190,124 L190,160 L10,160 Z',GREEN,1.6)+[30,44,58,150,164].map(x=>S(`M${x},134 L${x+5},120 L${x+10},134 Z`,'#3F6A2E',1)).join('');
   return inMedal(id+'mb',g)+medalRing();},
 3:id=>{ // Silhouette des Alpes (toits d'Europe)
   let p=S('M8,138 L40,90 L56,104 L78,62 L96,84 L112,70 L134,98 L150,80 L192,138 Z',PAPER,2.4)+H('M78,62 L96,84 L112,70 L134,98 L150,80 L192,138 L78,138 Z','c3');
   p+=S('M78,62 L70,74 L80,72 L86,76 Z M150,80 L144,90 L154,88 Z M40,90 L34,100 L44,98 Z','#fff',1.4);
   return p+[[78,62,TONE],[150,80,GOLD],[40,90,'#7FB3D5']].map(([x,y,c])=>L(x,y,x,y-18,1.6)+S(`M${x},${y-18} l12,3 l-12,4 z`,c,1.2)).join('');},
 4:id=>{ // Kilimandjaro et acacia
   let p=S('M10,132 L70,72 L130,72 L190,132 Z',PAPER,2.4)+H('M100,72 L130,72 L190,132 L100,132 Z','c4');
   p+=S('M70,72 L130,72 L120,82 L110,78 L100,86 L90,78 L80,82 Z','#fff',1.6);
   p+=L(50,140,50,108,2.4)+S('M24,106 C30,96 70,96 78,106 C70,110 30,110 24,106 Z',TONE,1.8)+S('M50,118 L40,108 M50,114 L62,106','none',1.6);
   return p+S('M8,140 L192,140','none',1.6)+C(160,40,10,GOLD,1.8);},
 5:id=>{ // le K2 et le camp de base
   let p=S('M6,138 L36,74 L52,92 L84,30 L112,80 L124,66 L150,96 L166,72 L194,138 Z',PAPER,2.4)+H('M84,30 L112,80 L124,66 L150,96 L166,72 L194,138 L92,138 C90,100 88,60 84,30 Z',id);
   p+=S('M84,30 L96,52 L88,50 L82,58 L76,48 L72,52 Z M166,72 L160,82 L168,80 Z M36,74 L30,86 L40,84 Z','#fff',1.4);
   p+=S('M14,138 C60,128 140,130 186,138 L186,146 L14,146 Z','#FFFFFF',1.4);
   const tent=(x,c)=>S(`M${x},140 L${x+9},124 L${x+18},140 Z`,c,1.4)+L(x+9,124,x+9,140,.8);
   return p+tent(60,GOLD)+tent(82,WAX)+tent(104,'#E9852B')+SC('M46,104 C60,96 70,86 78,70',INK,1,'stroke-dasharray="2 3"');},
 6:id=>{ // Aconcagua et condor
   let p=S('M20,138 L84,46 L104,70 L120,58 L180,138 Z',PAPER,2.4)+H('M84,46 L104,70 L120,58 L180,138 L84,138 Z','c6');
   p+=S('M84,46 L76,60 L86,58 L92,64 L98,62 Z','#fff',1.4);
   return p+S('M128,36 C138,28 146,32 152,38 C158,32 166,28 176,36 C166,36 158,42 152,46 C146,42 138,36 128,36 Z',INK,1.2);},
 7:id=>{ // le Vésuve en éruption au-dessus de Pompéi
   let p=S('M76,70 C62,60 64,42 78,40 C76,28 92,20 102,30 C110,18 132,24 130,38 C146,40 146,60 128,66 C120,72 92,74 76,70 Z','#B8B0A4',2)+H('M110,40 C120,40 128,46 128,56 C128,62 124,66 118,68 C116,58 114,48 110,40 Z',id);
   p+=S('M24,136 L82,74 L118,74 L176,136 Z','#C9B8A0',2.4)+H('M100,74 L118,74 L176,136 L112,136 Z',id);
   p+=S('M88,74 C90,92 80,106 82,124 L90,124 C92,106 100,92 98,74 Z','#E9852B',1.6)+S('M104,74 C110,92 122,104 126,122 L134,120 C128,102 116,90 112,74 Z',WAX,1.6);
   p+=[[66,48,2.6],[146,30,2.4],[58,30,2]].map(([x,y,r])=>C(x,y,r,'#E9852B',1)).join('');
   p+=S('M30,148 L170,148 L170,138 L30,138 Z',PAPER,1.8);
   return p+[44,58,72,128,142,156].map(x=>R(x-3,124,6,14,PAPER,1.4)+R(x-5,121,10,3,PAPER,1.2)).join('')+S('M86,138 L86,128 L114,128 L114,138',PAPER,1.4)+S('M84,128 L100,120 L116,128 Z',PAPER,1.4);},
 8:id=>{ // les Andes et un lama
   let p=S('M0,96 L30,70 L54,84 L86,52 L112,76 L140,58 L170,82 L200,66 L200,160 L0,160 Z','#EFE4D2',2)+H('M0,110 L200,96 L200,160 L0,160 Z',id);
   p+=S('M0,118 L40,96 L70,110 L100,86 L130,104 L160,90 L200,112 L200,160 L0,160 Z',PAPER,2.2);
   p+=S('M0,140 L50,124 L90,136 L130,120 L170,134 L200,126 L200,160 L0,160 Z',GREEN,2,'opacity=".85"');
   p+=S('M86,52 L80,62 L90,60 Z M140,58 L134,68 L144,66 Z','#fff',1.2);
   const fg='<g transform="translate(-40 -4)">'+S('M120,140 L120,126 C120,120 126,118 134,118 L148,118 L150,100 C150,94 156,92 158,96 L160,102 L164,102 L158,108 L156,122 L156,140 L151,140 L150,128 L130,128 L128,140 Z','#F2E6D0',1.8)+L(152,96,150,90,1.4)+C(155,100,1,INK,0)+S('M132,118 L148,118 L148,128 L132,128 Z',WAX,1,'opacity=".8"')+'</g>';
   return inMedal(id+'an',F('M20,20 L180,20 L180,160 L20,160 Z','#DCEBF0')+p)+medalRing()+`<g transform="translate(100 150) scale(1.7) translate(-100 -138)">${fg}</g>`;},
 9:id=>{ // gorges du Verdon
   let g=F('M20,20 L180,20 L180,160 L20,160 Z','#DCEBF0')+S('M40,70 C64,60 92,66 110,60 C130,54 148,60 166,56 L166,100 L40,100 Z','#7FA86A',1.4);
   g+=S('M66,160 L62,96 C92,100 118,98 142,94 L132,160 Z','#3FB0A8',2)+SC('M78,124 C92,118 108,120 122,114 M74,142 C90,136 106,140 124,132',PAPER,1.6,'stroke-opacity=".7"')+S('M94,128 L110,126 L108,129 L92,131 Z',WAX,1);
   g+=S('M10,20 L56,20 L62,40 L54,58 L70,78 L60,98 L78,118 L74,160 L10,160 Z','#D8C7A6',2.2)+S('M190,20 L150,20 L144,44 L152,62 L136,84 L146,104 L128,124 L132,160 L190,160 Z','#C9B08C',2.2);
   g+=[40,58,76,94,112,130,148].map(y=>SC(`M12,${y} C30,${y-3} 46,${y+2} 58,${y}`,INK,1,'opacity=".4"')+SC(`M188,${y} C170,${y-3} 156,${y+2} 144,${y}`,INK,1,'opacity=".4"')).join('')+H('M150,20 L190,20 L190,160 L132,160 L128,124 L146,104 L136,84 L152,62 L144,44 Z',id);
   return inMedal(id+'vd',g)+medalRing();},
 10:id=>{ // le Nil, ses palmiers et une felouque
   let g=F('M20,20 L180,20 L180,160 L20,160 Z','#F1DDB0')+S('M120,58 L132,40 L144,58 Z','#E3C38E',1.4)+S('M138,58 L146,46 L154,58 Z','#E3C38E',1.2);
   g+=S('M96,58 C104,60 108,64 104,70 C96,80 80,86 82,100 C84,116 120,118 122,134 C124,146 112,154 108,162 L60,162 C74,150 86,142 82,132 C76,118 46,112 50,94 C54,80 80,72 88,64 C90,60 92,58 96,58 Z','#5FA8C8',2);
   g+=SC('M66,96 C70,90 76,88 82,86 M96,126 C102,128 106,132 108,138',PAPER,1.4,'stroke-opacity=".7"');
   const palm=(x,y)=>SC(`M${x},${y} C${x-1},${y-10} ${x+1},${y-18} ${x+3},${y-24}`,'#6B4A2F',2)+[[-14,-4],[-10,6],[12,-6],[14,4],[0,-12]].map(([a,b])=>SC(`M${x+3},${y-24} q${a*.5},${b*.5-6} ${a},${b}`,GREEN,2)).join('');
   g+=palm(40,92)+palm(52,80)+palm(130,108)+palm(146,120)+palm(116,84);
   const fg=S('M92,116 C96,122 112,122 116,116 Z',WOOD,1.4)+L(104,118,104,92,1.2)+S('M104,92 L118,112 L104,112 Z',PAPER,1.4);
   return inMedal(id+'nl',g)+medalRing()+`<g transform="translate(104 120) scale(2.2) translate(-104 -116)">${fg}</g>`;},
 11:id=>{ // la Loire et un château
   let g=F('M20,20 L180,20 L180,100 L20,100 Z','#EEF4F6');
   let c=S('M30,96 L30,74 L44,74 L44,96 Z',PAPER,1.8)+S('M28,74 L37,56 L46,74 Z','#5C6E80',1.6);
   c+=S('M44,96 L44,66 L156,66 L156,96 Z',PAPER,2.2)+S('M44,66 L52,54 L148,54 L156,66 Z','#5C6E80',2);
   c+=S('M86,66 L86,40 L114,40 L114,66 Z',PAPER,2)+S('M82,40 L100,22 L118,40 Z','#5C6E80',2)+L(100,22,100,14,1.4);
   c+=S('M156,96 L156,74 L170,74 L170,96 Z',PAPER,1.8)+S('M154,74 L163,56 L172,74 Z','#5C6E80',1.6);
   c+=[52,64,76,124,136,148].map(x=>R(x,74,6,10,INK,0)).join('')+[92,104].map(x=>R(x,46,5,8,INK,0)+R(x,74,6,10,INK,0)).join('');
   g+=S('M10,98 C60,94 140,94 190,98 L190,160 L10,160 Z','#9FC6D3',2);
   g+=S('M50,118 C70,112 96,114 108,120 C92,126 64,126 50,118 Z','#E8D3A3',1.6)+S('M110,136 C126,130 146,132 156,138 C142,142 122,142 110,136 Z','#E8D3A3',1.6);
   g+=waves(30,106,1,1.2,.5)+SC('M40,140 c10,-4 20,4 30,0',INK,1.2,'opacity=".5"');
   return inMedal(id+'lo',g)+medalRing()+`<g transform="translate(100 98) scale(1.02) translate(-100 -96)">${c}</g>`;},
 12:id=>{ // mer Morte : on y flotte
   let g=F('M20,20 L180,20 L180,80 L20,80 Z','#F6EBD6')+C(138,44,9,GOLD,1.6)+S('M10,74 C50,66 80,76 110,70 C140,64 160,72 190,68 L190,86 L10,86 Z','#C9A57A',1.8);
   g+=S('M10,86 L190,86 L190,160 L10,160 Z','#7FBCC4',2)+waves(36,124,3,1.2,.45);
   let fg=S('M56,108 C70,100 120,100 142,104 C138,112 70,114 56,108 Z','#E8B48A',2)+C(56,100,9,'#E8B48A',2)+S('M48,96 C48,88 62,86 64,94','none',2.4);
   fg+=S('M142,104 L156,96 L160,100 L148,108 Z','#E8B48A',1.6);
   fg+=rot(-10,86,90,R(70,76,34,24,PAPER,1.8)+L(87,76,87,100,1)+[82,86,90,94].map(y=>L(74,y,84,y,.9,INK,.5)+L(90,y,100,y,.9,INK,.5)).join(''));
   fg+=SC('M66,100 L74,92 M100,100 L98,90',INK,2.2);
   g+=S('M10,140 C40,134 70,142 100,138 L100,160 L10,160 Z',PAPER,1.6);
   return inMedal(id+'mm',g)+medalRing()+`<g transform="translate(102 104) scale(1.35) translate(-102 -104)">${fg}</g>`;},
 13:id=>{ // Salto Ángel
   let g=F('M20,20 L180,20 L180,160 L20,160 Z','#DCEBF0');
   g+=S('M10,46 C60,38 120,38 190,44 L190,120 L10,120 Z','#B07A55',2.4)+S('M10,46 C60,38 120,38 190,44 L190,54 C120,48 60,48 10,56 Z',GREEN,1.6);
   g+=H('M120,46 L190,46 L190,120 L120,120 Z',id)+[70,90,110].map(y=>SC(`M14,${y} C60,${y-4} 140,${y+4} 186,${y}`,INK,1,'opacity=".35"')).join('');
   g+=S('M92,46 C94,70 92,100 96,124 L108,124 C104,100 106,70 104,46 Z','#E6F4FA',1.4)+[56,70,84,98,112].map(y=>L(96,y,102,y+8,1,'#4C8FB8')).join('');
   g+=[[100,126,12],[88,124,8],[112,124,8]].map(([x,y,r])=>C(x,y,r,'#FFFFFF',1.2)).join('');
   g+=S('M10,124 C40,118 70,128 100,124 C130,120 160,128 190,124 L190,160 L10,160 Z','#3F6A2E',1.8)+[30,46,62,138,154,170].map(x=>C(x,126,8,'#4F7A3A',1.2)).join('');
   return inMedal(id+'sa',g)+medalRing();},
 14:id=>{ // manchot sur la banquise
   let g=F('M20,20 L180,20 L180,160 L20,160 Z','#DCE7F0')+S('M10,118 C40,108 70,114 100,110 C130,106 160,112 190,108 L190,160 L10,160 Z','#FFFFFF',2)+S('M10,136 C50,130 100,140 190,132 L190,160 L10,160 Z','#BFD8E8',1.6);
   let fg=S('M100,124 C76,122 70,84 80,58 C86,42 102,36 114,44 C124,52 128,76 124,98 C122,114 114,124 100,124 Z',INK,2.4)+S('M102,120 C88,116 84,92 90,72 C96,60 110,62 114,74 C118,90 114,116 102,120 Z',PAPER,1.4);
   fg+=S('M90,58 C96,52 104,54 104,60 C100,64 94,64 90,58 Z','#F2C14E',0,'opacity=".8"')+C(108,52,2,PAPER,0)+C(108,52,1,INK,0)+S('M114,50 L130,55 L114,58 Z','#F2A33A',1.2);
   fg+=S('M80,82 C70,92 68,104 74,112 C80,104 82,94 84,86 Z',INK,1.4)+S('M90,124 l-8,4 l12,0 Z M108,124 l8,4 l-12,0 Z','#F2A33A',1);
   g+=[[40,40],[62,60],[150,44],[140,76],[46,90],[166,96],[120,30]].map(([x,y])=>star4(x,y,3.4,PAPER)).join('');
   return inMedal(id+'pg',g)+medalRing()+`<g transform="translate(100 132) scale(1.3) translate(-100 -126)">${fg}</g>`;},
};
