// Sujets des pages Espace et Relief. Chaque fonction reçoit l'identifiant de motif de hachures (« cN »).
const star4=(x,y,r,fill=GOLD)=>`<path d="M${x},${y-r} Q${x},${y} ${x+r},${y} Q${x},${y} ${x},${y+r} Q${x},${y} ${x-r},${y} Q${x},${y} ${x},${y-r} Z" fill="${fill}" stroke="${INK}" stroke-width=".9"/>`;
function clipCircle(id,cx,cy,r,inner){return `<clipPath id="${id}"><circle cx="${cx}" cy="${cy}" r="${r}"/></clipPath><g clip-path="url(#${id})">${inner}</g>`;}
const waves=(x,y,n,w=1.4,o=.55)=>[...Array(n)].map((_,i)=>S(`M${x},${y+i*7} q10,-5 20,0 t20,0 t20,0 t20,0 t20,0 t20,0`,'none',w,`opacity="${o}"`)).join('');

SUBJECTS['science.space']={
 1:id=>{ // Soleil
   let p='';for(let i=0;i<16;i++){const a=i/16*Math.PI*2,r1=34,r2=i%2?46:56,w=i%2?5:7;
     const x1=100+Math.cos(a-.12)*r1,y1=84+Math.sin(a-.12)*r1,x2=100+Math.cos(a)*r2,y2=84+Math.sin(a)*r2,x3=100+Math.cos(a+.12)*r1,y3=84+Math.sin(a+.12)*r1;
     p+=`<path d="M${x1.toFixed(1)},${y1.toFixed(1)} L${x2.toFixed(1)},${y2.toFixed(1)} L${x3.toFixed(1)},${y3.toFixed(1)} Z" fill="${i%2?PAPER:GOLD}" stroke="${INK}" stroke-width="1.4" stroke-linejoin="round"/>`;}
   p+=C(100,84,32,GOLD,2.4)+H('M100,52 A32,32 0 0 1 100,116 Z','c1');
   p+=S('M128,64 C142,52 146,70 134,74','none',1.8)+S('M74,108 C62,118 58,100 70,98','none',1.8);
   return p+`<circle cx="90" cy="74" r="8" fill="#fff" opacity=".35"/>`;},
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
 5:id=>{ // Olympus Mons
   let p=C(150,40,14,TONE,2)+H('M150,26 A14,14 0 0 1 150,54 Z','c5');
   p+=S('M14,132 C40,128 62,104 78,92 C86,86 94,84 100,84 C106,84 114,86 122,92 C138,104 160,128 186,132 Z',PAPER,2.4);
   p+=H('M100,84 C106,84 114,86 122,92 C138,104 160,128 186,132 L100,132 Z','c5')+`<ellipse cx="100" cy="86" rx="14" ry="3.5" fill="${TONE}" stroke="${INK}" stroke-width="1.6"/>`;
   p+=S('M14,140 L186,140','none',1.6)+S('M60,108 C70,112 76,118 80,126 M140,108 C130,112 124,118 120,126','none',1.2,'opacity=".5"');
   return p+star4(40,40,5)+star4(70,24,3.5);},
 6:id=>{ // Jupiter et sa Grande Tache rouge
   let p=C(100,84,46,PAPER,2.4);
   p+=clipCircle('j6',100,84,46,[[-34,8,GOLD],[-18,6,TONE],[-4,10,GOLD],[14,7,TONE],[28,9,GOLD]].map(([y,h,c])=>`<rect x="50" y="${84+y}" width="100" height="${h}" fill="${c}" opacity=".8"/>`).join('')
     +[-26,-12,6,22,38].map(y=>S(`M50,${84+y} C80,${80+y} 120,${88+y} 150,${84+y}`,'none',1,'opacity=".5"')).join('')+H('M100,38 A46,46 0 0 1 100,130 Z','c6'));
   p+=`<ellipse cx="118" cy="104" rx="12" ry="7" fill="${WAX}" stroke="${INK}" stroke-width="1.6"/>`+C(100,84,46,'none',2.4);
   return p+C(162,46,4,PAPER,1.4)+C(40,120,3,PAPER,1.2);},
 7:id=>{ // Saturne et ses anneaux
   const ringBack=`<path d="M48,92 A56,15 -14 0 1 152,72" fill="none" stroke="${INK}" stroke-width="2.4"/>`;
   let p=`<g transform="rotate(-14 100 84)"><path d="M44,84 A56,15 0 0 1 156,84" fill="none" stroke="${INK}" stroke-width="2.2"/><path d="M54,84 A46,11 0 0 1 146,84" fill="none" stroke="${INK}" stroke-width="1" opacity=".6"/></g>`;
   p+=C(100,84,30,GOLD,2.4)+clipCircle('s7',100,84,30,[-16,-6,4,14].map(y=>`<rect x="66" y="${84+y}" width="70" height="4" fill="${TONE}" opacity=".35"/>`).join('')+H('M100,54 A30,30 0 0 1 100,114 Z','c7'));
   p+=`<g transform="rotate(-14 100 84)"><path d="M44,84 A56,15 0 0 0 156,84" fill="none" stroke="${INK}" stroke-width="2.6"/><path d="M54,84 A46,11 0 0 0 146,84" fill="none" stroke="${INK}" stroke-width="1.2" opacity=".7"/><path d="M50,84 A51,13 0 0 0 151,84" fill="none" stroke="${GOLD}" stroke-width="3" opacity=".7"/></g>`;
   return `<g transform="translate(100 84) scale(1.3) translate(-100 -84)">${p}</g>`+star4(34,32,5)+star4(170,134,4)+C(166,36,3,PAPER,1.2);},
 8:id=>{ // Uranus couchée
   let p=L(40,84,160,84,1.6,INK,.8)+`<g transform="rotate(82 100 84)"><ellipse cx="100" cy="84" rx="54" ry="13" fill="none" stroke="${INK}" stroke-width="1.6"/></g>`;
   p+=C(100,84,30,'#BFE3E8',2.4)+H('M100,54 A30,30 0 0 1 100,114 Z','c8');
   p+=`<g transform="rotate(82 100 84)"><path d="M46,84 A54,13 0 0 0 154,84" fill="none" stroke="${INK}" stroke-width="2.2"/></g>`;
   return p+S('M150,70 L160,84 L150,98','none',1.6)+C(40,40,8,'#7FB3D5',1.8)+star4(160,36,5)+star4(36,128,4);},
 9:id=>{ // Comète
   let p='';for(let i=0;i<5;i++)p+=S(`M128,58 C${100-i*6},${70+i*4} ${70-i*6},${96+i*6} ${30-i*4},${124+i*4}`,'none',i===2?2.4:1.4,`opacity="${i===2?1:.6}"`);
   p+=S('M128,58 C108,82 84,104 50,126','none',6,`stroke="${GOLD}" opacity=".5"`);
   p+=C(130,56,10,PAPER,2.4)+H('M130,46 A10,10 0 0 1 130,66 Z','c9');
   return p+star4(160,30,5)+star4(44,40,4)+star4(158,110,4)+C(80,40,1.8,INK,0)+C(170,70,1.6,INK,0);},
 10:id=>{ // Le système solaire
   let p=C(10,84,36,GOLD,2.4)+H('M10,48 A36,36 0 0 1 10,120 Z','c10');
   const orbits=[52,70,88,108,132,156,176,194];
   p+=orbits.map(r=>`<path d="M${10+r*Math.cos(-.6)},${84+r*Math.sin(-.6)} A${r},${r} 0 0 1 ${10+r*Math.cos(.6)},${84+r*Math.sin(.6)}" fill="none" stroke="${INK}" stroke-width=".9" opacity=".55"/>`).join('');
   const pl=[[52,.1,3,PAPER],[70,-.3,4,GOLD],[88,.25,4.5,'#7FB3D5'],[108,-.15,3.6,TONE],[132,.3,9,GOLD],[156,-.25,7.5,PAPER],[176,.15,5.5,'#BFE3E8'],[194,-.05,5,'#7FB3D5']];
   return p+pl.map(([r,a,s,c])=>C((10+r*Math.cos(a)).toFixed(1),(84+r*Math.sin(a)).toFixed(1),s,c,1.6)).join('');},
 11:id=>{ // Grande Ourse et étoile polaire
   const st=[[40,112],[60,104],[78,104],[94,96],[104,76],[134,72],[132,98]];
   let p=`<path d="M${st.map(s=>s.join(',')).join(' L')} L94,96" fill="none" stroke="${INK}" stroke-width="1.4" stroke-dasharray="3 3"/>`;
   p+=S('M134,72 L148,34','none',1,'stroke-dasharray="2 4" opacity=".7"');
   return p+st.map(([x,y],i)=>star4(x,y,i>3?7:6)).join('')+star4(150,30,10,PAPER)+T(150,54,'Polaire',9,INK,'middle',800);},
 12:id=>{ // Voie lactée
   let p='';for(let arm=0;arm<2;arm++)for(let i=0;i<70;i++){const t=i/70*4.2,r=6+t*12,a=t*1.15+arm*Math.PI;const x=100+Math.cos(a)*r,y=84+Math.sin(a)*r*.62;
     p+=`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(2.6-t*.45).toFixed(2)}" fill="${i%5?INK:GOLD}" opacity="${(1-t*.18).toFixed(2)}"/>`;}
   p+=`<ellipse cx="100" cy="84" rx="12" ry="8" fill="${GOLD}" stroke="${INK}" stroke-width="1.4"/>`;
   return p+star4(160,30,5)+star4(36,132,4)+star4(42,36,3.5);},
 13:id=>{ // Spoutnik
   let p=[[-.5,180],[-.2,186],[.15,186],[.45,180]].map(([a,len])=>{const x=100-Math.cos(a)*90,y=84+Math.sin(a)*70;return L(100,84,x.toFixed(1),y.toFixed(1),1.6)}).join('');
   p+=C(110,72,20,PAPER,2.4)+H('M110,52 A20,20 0 0 1 110,92 Z','c13')+S('M90,72 L130,72','none',1,'opacity=".5"')+C(102,64,4,'#fff',0);
   return p+S('M136,48 c6,6 6,14 0,20 M144,42 c10,10 10,26 0,36','none',1.4,'opacity=".6"')+star4(160,124,5)+star4(40,40,4);},
 14:id=>{ // Empreinte de pas sur la Lune
   let p=S('M10,124 C50,116 70,128 100,120 C130,112 160,124 190,116 L190,160 L10,160 Z',PAPER,2)+H('M10,140 L190,134 L190,160 L10,160 Z','c14');
   p+=`<g transform="rotate(-14 100 92)">${S('M78,46 C78,34 122,34 122,46 L124,112 C124,126 76,126 76,112 Z',PAPER,2.4)}
     ${[56,66,76,86,96,106].map(y=>`<path d="M82,${y} L118,${y-4}" stroke="${INK}" stroke-width="3" stroke-linecap="round" opacity=".75"/>`).join('')}</g>`;
   return p+L(150,104,150,56,1.8)+S('M150,56 L176,58 L176,74 L150,72 Z',TONE,1.6)+C(36,40,10,'#BFE3E8',1.6);},
 15:id=>{ // Station spatiale internationale
   let p=L(26,84,174,84,3);
   for(const x of [36,60,140,164])for(const s of [-1,1])p+=S(`M${x-9},${84+s*8} L${x+9},${84+s*8} L${x+9},${84+s*40} L${x-9},${84+s*40} Z`,GOLD,1.6)+H(`M${x},${84+s*8} L${x+9},${84+s*8} L${x+9},${84+s*40} L${x},${84+s*40} Z`,'c15');
   p+=S('M84,74 L116,74 L116,94 L84,94 Z',PAPER,2)+S('M92,94 L92,110 L108,110 L108,94','none',2)+C(100,70,6,PAPER,1.8);
   return p+star4(100,30,5)+star4(40,140,4);},
};

SUBJECTS['geography.relief']={
 1:id=>{ // Everest et drapeau
   let p=S('M14,138 L62,78 L80,94 L108,46 L126,66 L140,58 L186,138 Z',PAPER,2.4)+H('M108,46 L126,66 L140,58 L186,138 L108,138 Z','c1');
   p+=S('M108,46 L98,64 L106,60 L112,70 L118,62 L126,66 Z','#fff',1.6)+S('M62,78 L56,88 L66,86 L70,92 L80,94 Z','#fff',1.4);
   return p+L(108,46,108,26,1.8)+S('M108,26 L124,30 L108,34 Z',TONE,1.4)+S('M30,146 L170,146','none',1.2,'opacity=".5"');},
 2:id=>{ // Mont Blanc et glacier
   let p=S('M10,138 C40,120 60,86 92,62 C100,56 108,56 116,62 C146,86 166,120 190,138 Z',PAPER,2.4)+H('M104,58 C116,62 146,86 166,120 L190,138 L104,138 Z','c2');
   p+=S('M80,72 C92,58 112,56 128,72 C120,76 112,72 104,80 C96,74 88,78 80,72 Z','#fff',1.6);
   return p+S('M96,78 C90,96 84,116 74,138 L126,138 C116,116 110,96 104,78 Z','#DDEFF5',1.8)+[0,1,2,3].map(i=>S(`M${92-i*3},${92+i*12} l${6+i*2},3 l${6+i*2},-3`,'none',1,'opacity=".55"')).join('');},
 3:id=>{ // Silhouette des Alpes (toits d'Europe)
   let p=S('M8,138 L40,90 L56,104 L78,62 L96,84 L112,70 L134,98 L150,80 L192,138 Z',PAPER,2.4)+H('M78,62 L96,84 L112,70 L134,98 L150,80 L192,138 L78,138 Z','c3');
   p+=S('M78,62 L70,74 L80,72 L86,76 Z M150,80 L144,90 L154,88 Z M40,90 L34,100 L44,98 Z','#fff',1.4);
   return p+[[78,62,TONE],[150,80,GOLD],[40,90,'#7FB3D5']].map(([x,y,c])=>L(x,y,x,y-18,1.6)+S(`M${x},${y-18} l12,3 l-12,4 z`,c,1.2)).join('');},
 4:id=>{ // Kilimandjaro et acacia
   let p=S('M10,132 L70,72 L130,72 L190,132 Z',PAPER,2.4)+H('M100,72 L130,72 L190,132 L100,132 Z','c4');
   p+=S('M70,72 L130,72 L120,82 L110,78 L100,86 L90,78 L80,82 Z','#fff',1.6);
   p+=L(50,140,50,108,2.4)+S('M24,106 C30,96 70,96 78,106 C70,110 30,110 24,106 Z',TONE,1.8)+S('M50,118 L40,108 M50,114 L62,106','none',1.6);
   return p+S('M8,140 L192,140','none',1.6)+C(160,40,10,GOLD,1.8);},
 5:id=>{ // Pics de l'Himalaya
   let p=S('M6,138 L36,70 L52,92 L80,40 L100,72 L116,56 L140,96 L160,64 L194,138 Z',PAPER,2.4)+H('M80,40 L100,72 L116,56 L140,96 L160,64 L194,138 L80,138 Z','c5');
   p+=S('M80,40 L70,60 L82,56 L90,64 L96,58 Z M160,64 L152,78 L162,76 L168,80 Z M36,70 L30,84 L40,82 Z','#fff',1.4);
   p+=S('M20,104 Q60,118 100,104 T180,104','none',1.2);
   return p+[30,46,62,78,94,110,126,142,158].map((x,i)=>`<path d="M${x},${104+Math.sin(i)*3} l6,0 l-3,8 z" fill="${[TONE,GOLD,'#7FB3D5',PAPER,'#2F7D55'][i%5]}" stroke="${INK}" stroke-width=".8"/>`).join('');},
 6:id=>{ // Aconcagua et condor
   let p=S('M20,138 L84,46 L104,70 L120,58 L180,138 Z',PAPER,2.4)+H('M84,46 L104,70 L120,58 L180,138 L84,138 Z','c6');
   p+=S('M84,46 L76,60 L86,58 L92,64 L98,62 Z','#fff',1.4);
   return p+S('M128,36 C138,28 146,32 152,38 C158,32 166,28 176,36 C166,36 158,42 152,46 C146,42 138,36 128,36 Z',INK,1.2);},
 7:id=>{ // Vésuve en éruption
   let p=S('M20,138 L80,74 L120,74 L180,138 Z',PAPER,2.4)+H('M100,74 L120,74 L180,138 L100,138 Z','c7');
   p+=S('M80,74 C70,58 74,40 90,40 C88,26 108,22 114,34 C126,24 142,36 132,48 C144,54 136,70 120,74 Z','#EFE7DA',2);
   p+=S('M90,74 C92,96 82,112 86,138 L94,138 C94,112 104,96 100,74 Z',WAX,1.6)+S('M108,74 C114,94 124,108 128,138','none',2.6,`stroke="${TONE}"`);
   return p+[[70,34],[60,52],[146,30]].map(([x,y])=>C(x,y,2.4,WAX,1)).join('');},
 8:id=>{ // Crêtes des Andes
   let p=S('M0,96 L30,70 L54,84 L86,52 L112,76 L140,58 L170,82 L200,66 L200,160 L0,160 Z','#EFE4D2',2)+H('M0,110 L200,96 L200,160 L0,160 Z','c8');
   p+=S('M0,118 L40,96 L70,110 L100,86 L130,104 L160,90 L200,112 L200,160 L0,160 Z',PAPER,2.2);
   p+=S('M0,140 L50,124 L90,136 L130,120 L170,134 L200,126 L200,160 L0,160 Z',TONE,2,'opacity=".9"');
   return p+S('M86,52 L80,62 L90,60 Z M140,58 L134,68 L144,66 Z','#fff',1.2);},
 9:id=>{ // Falaises d'Étretat
   let p=S('M0,40 L96,44 C102,60 104,80 98,96 C92,96 86,94 80,92 C76,104 74,118 76,128 L0,128 Z',PAPER,2.4)+H('M70,44 L96,44 C102,60 104,80 98,96 C92,96 86,94 80,92 C76,104 74,118 76,128 L60,128 Z','c9');
   p+=S('M80,92 C88,104 96,110 104,108 C110,106 110,96 98,96','none',2);
   p+=S('M126,128 L130,74 C132,66 138,66 140,74 L144,128 Z',PAPER,2.2)+H('M135,68 C138,66 140,70 140,74 L144,128 L135,128 Z','c9');
   for(let y=56;y<124;y+=10)p+=L(4,y,60,y+2,1,INK,.35);
   return p+waves(0,132,3)+S('M0,40 C30,32 70,34 96,44','#7CB86A',1.6);},
 10:id=>{ // Delta du Nil
   let p=S('M100,20 C98,50 104,70 100,90','none',3.4,`stroke="#4C8FB8"`);
   p+=S('M100,90 C86,104 66,118 44,140 M100,90 C96,110 92,124 86,144 M100,90 C106,110 112,126 116,144 M100,90 C116,104 134,118 156,140','none',2.4,`stroke="#4C8FB8"`);
   p+=S('M40,140 C70,150 130,150 160,140 L100,90 Z','#7CB86A',1.6,'opacity=".45"');
   p+=S('M20,140 L180,140','none',1.6);
   return p+S('M138,60 L152,36 L166,60 Z',GOLD,1.8)+H('M152,36 L166,60 L152,60 Z','c10')+S('M156,62 L166,46 L176,62 Z',GOLD,1.6);},
 11:id=>{ // Méandres de la Seine
   let p=S('M10,30 C60,30 70,60 40,72 C10,84 30,110 70,104 C120,96 140,60 170,74 C196,86 180,120 150,128 C120,136 130,150 190,150','none',9,`stroke="#9CC9E0"`);
   p+=S('M10,30 C60,30 70,60 40,72 C10,84 30,110 70,104 C120,96 140,60 170,74 C196,86 180,120 150,128 C120,136 130,150 190,150','none',1.2,'opacity=".6"');
   return p+S('M92,92 L108,108','none',4.4)+S('M88,96 C94,90 104,100 112,104','none',1.6)+C(130,40,5,TONE,1.4)+C(46,124,4,TONE,1.2);},
 12:id=>{ // Vagues
   let p=S('M0,128 C30,120 46,96 50,76 C54,52 80,34 108,40 C132,46 140,70 124,80 C114,86 104,78 110,70 C96,72 92,90 104,100 C122,114 160,110 186,96 L200,96 L200,160 L0,160 Z','#4C8FB8',2.4);
   p+=S('M124,80 C114,86 104,78 110,70 C118,62 130,64 134,72','#fff',1.6)+H('M0,140 L200,120 L200,160 L0,160 Z','c12');
   return p+[0,1,2,3].map(i=>S(`M${60+i*8},${46+i*4} q6,-6 12,-2`,'none',1.4)).join('')+C(160,40,10,'#fff',1.4);},
 13:id=>{ // Salto Ángel
   let p=S('M20,40 L130,36 L134,160 L20,160 Z',PAPER,2.4)+H('M90,38 L130,36 L134,160 L90,160 Z','c13');
   p+=S('M20,40 C60,30 100,30 130,36','#7CB86A',1.6);
   p+=`<rect x="96" y="36" width="10" height="112" fill="#DDF0F8" stroke="${INK}" stroke-width="1.4"/>`+[44,60,76,92,108,124].map(y=>L(98,y,104,y+8,1,'#4C8FB8')).join('');
   return p+S('M80,150 C90,140 112,140 122,150','#DDF0F8',1.4)+S('M140,150 L190,150','none',1.4)+T(166,92,'979 m',11,INK,'middle');},
 14:id=>{ // Globe et équateur
   let p=C(100,84,46,PAPER,2.4)+clipCircle('g14',100,84,46,[-32,-16,0,16,32].map(x=>`<ellipse cx="100" cy="84" rx="${Math.abs(x)+.1}" ry="46" fill="none" stroke="${INK}" stroke-width="1" opacity=".45"/>`).join('')
     +[-30,-15,15,30].map(y=>L(50,84+y,150,84+y,1,INK,.45)).join('')+H('M100,38 A46,46 0 0 1 100,130 Z','c14'));
   p+=L(54,84,146,84,3,TONE)+C(100,84,46,'none',2.4);
   return p+S('M100,38 L100,26 M100,130 L100,142','none',2)+C(100,24,3,'#BFE3E8',1.2)+C(100,144,3,'#BFE3E8',1.2);},
};
