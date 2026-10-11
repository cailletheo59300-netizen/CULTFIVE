/* --- Sport : ballons, trophées génériques (aucun logo), équipements --- */
const pentaD=(cx,cy,r,a0=-90)=>[0,1,2,3,4].map(k=>{const a=(a0+k*72)*Math.PI/180;return (k?'L':'M')+(cx+r*Math.cos(a)).toFixed(1)+','+(cy+r*Math.sin(a)).toFixed(1);}).join(' ')+' Z';
/* ballon de football : panneaux noirs (ou foncés) découpés dans le cercle */
function soccer(cid,cx,cy,r,fill='#fff',dark='#2B2B2B',w=2.4){
  const pol=(a,rr)=>{const t=a*Math.PI/180;return [(cx+rr*Math.cos(t)).toFixed(1),(cy+rr*Math.sin(t)).toFixed(1)];};
  let in_=S(pentaD(cx,cy,r*.3),dark,1.4);
  for(let k=0;k<5;k++){const a=-90+k*72,[x1,y1]=pol(a,r*.3),[x2,y2]=pol(a,r*.6),[x3,y3]=pol(a-26,r*.78),[x4,y4]=pol(a+26,r*.78);
    in_+=L(x1,y1,x2,y2,1.4)+L(x2,y2,x3,y3,1.4)+L(x2,y2,x4,y4,1.4);
    const [px,py]=pol(a+36,r*1.02);in_+=S(pentaD(+px,+py,r*.3,a+36+180),dark,1.4);}
  const d=`M${cx-r},${cy} A${r},${r} 0 1 1 ${cx+r},${cy} A${r},${r} 0 1 1 ${cx-r},${cy} Z`;
  return S(d,fill,w)+clipTo(cid,d,in_+`<path d="M${cx-r*.7},${cy-r*.2} A${r*.75},${r*.75} 0 0 1 ${cx-r*.1},${cy-r*.72}" fill="none" stroke="#fff" stroke-width="${r*.08}" opacity=".5"/>`)+S(d,'none',w);}
/* coq tricolore (dessin générique, pas l'écusson) : tourné vers la droite */
function rooster(x,y,s,id){
  let p=S('M-30,16 C-48,6 -52,-22 -40,-40 C-36,-26 -30,-18 -22,-14 C-30,-30 -26,-48 -12,-56 C-14,-40 -12,-28 -6,-20 C-8,-34 0,-46 10,-50 C6,-36 6,-24 8,-14 Z',BLUE,2);
  p+=S('M-40,-40 C-36,-26 -30,-18 -22,-14 L-14,-10 C-26,-20 -34,-30 -40,-40 Z','#fff',0,'opacity=".5"')+S('M-30,16 C-40,22 -44,30 -40,34 C-30,30 -24,26 -20,22 Z','#C9443A',1.8);
  p+=S('M-30,16 C-34,-6 -14,-18 6,-14 C14,-30 20,-44 32,-46 C42,-46 46,-38 44,-30 L52,-26 L44,-22 C42,-14 38,-4 34,4 C30,18 14,28 -4,28 C-16,28 -26,24 -30,16 Z','#F4F1EA',2.2);
  p+=S('M6,-14 C14,-4 18,10 12,22 C24,16 32,6 34,4 C36,-6 30,-14 26,-18 Z','#C9443A',1.6,'opacity=".9"');
  p+=S('M30,-46 C28,-54 34,-58 36,-52 C38,-60 44,-60 44,-52 C48,-56 52,-52 48,-46 C44,-46 40,-48 30,-46 Z','#C9443A',1.6)+S('M42,-26 C44,-20 42,-14 38,-14 C36,-18 38,-24 42,-26 Z','#C9443A',1.2);
  p+=C(38,-36,2.4,INK,0)+C(38.6,-36.6,.8,'#fff',0)+SC('M-2,-2 C6,2 12,8 14,16 M2,-8 C10,-4 18,4 20,10',INK,1,'opacity=".35"');
  p+=SC('M-2,28 L-4,46 M8,26 L10,46',GOLD,3)+SC('M-12,46 L-4,46 L2,42 M2,46 L10,46 L16,42',GOLD,2.4);
  return `<g transform="translate(${x} ${y}) scale(${s})">${p}</g>`;}
/* coupe à deux anses générique */
const cup=(fill,stroke=INK)=>S('M70,40 L130,40 C130,78 116,96 100,98 C84,96 70,78 70,40 Z',fill,2.4)+SC('M70,48 C52,48 50,74 74,78 M130,48 C148,48 150,74 126,78',INK,5)+SC('M70,48 C52,48 50,74 74,78 M130,48 C148,48 150,74 126,78',fill,2.6)
  +S('M94,98 L106,98 L108,118 L92,118 Z',fill,2)+S('M78,118 L122,118 L126,134 L74,134 Z','#3B3A3A',2)+`<path d="M80,46 C80,66 86,80 94,88" fill="none" stroke="#fff" stroke-width="3" opacity=".5"/>`;
const medalS=(x,y,r,fill,ribbon,t='')=>S(`M${x-r*.7},${y-r*3.2} L${x-r*.2},${y-r*.8} L${x+r*.2},${y-r*.8} L${x+r*.7},${y-r*3.2} Z`,ribbon,1.6)+C(x,y,r,fill,2)+C(x,y,r*.74,'none',1.2)+(t?T(x,y+r*.3,t,r*.8,INK):'');

SUBJECTS['sport.champions']={
 1:id=>{ // ballon d'or et huit étoiles (légendaire)
   let p=`<circle cx="100" cy="90" r="58" fill="#F2D24A" opacity=".18"/>`;
   p+=laurel(100,92,56,170,100,6,7,'#E9B949')+laurel(100,92,56,10,80,6,7,'#E9B949');
   p+=soccer(id+'bo',100,92,44,'#F2D24A','#B8892A');
   p+=`<defs><radialGradient id="${id}sh" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#7A5A1A" stop-opacity=".3"/></radialGradient></defs><circle cx="100" cy="92" r="44" fill="url(#${id}sh)"/>`;
   return p+[...Array(8)].map((_,i)=>{const a=(200+i*20)*Math.PI/180;return star5((100+66*Math.cos(a)).toFixed(1),(96+66*Math.sin(a)).toFixed(1),6.4,'#F2D24A',1.2);}).join('');},
 2:id=>{ // raquette sur la terre battue
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#D9784A')+L(20,120,180,120,4,'#fff',.9)+L(100,120,100,160,4,'#fff',.9)+[...Array(14)].map((_,i)=>C(28+(i*53)%150,20+(i*37)%96,.9,'#B85A30',0)).join('');
   const head='M0,-40 C22,-40 30,-20 30,0 C30,22 18,40 0,40 C-18,40 -30,22 -30,0 C-30,-20 -22,-40 0,-40 Z';
   let str='';for(let i=-28;i<=28;i+=7)str+=L(i,-42,i,42,1,'#F4F1EA')+L(-32,i,32,i,1,'#F4F1EA');
   const rk=`<g transform="translate(86 66) rotate(-35)">${S(head,'none',7).replace(INK,'#2F4E8C')+clipTo(id+'st',head,str)+S(head,'none',2)+S('M-8,38 L-4,58 L4,58 L8,38 C4,46 -4,46 -8,38 Z','#2F4E8C',1.8)+R(-5,58,10,34,'#F4F1EA',2,3)+[64,70,76,82].map(y=>L(-5,y,5,y+3,1,INK,.4)).join('')}</g>`;
   const tb=C(140,46,11,'#D8E84A',2)+SC('M131,40 C138,44 138,52 132,56 M149,38 C142,42 142,50 148,54','#fff',1.6);
   return inMedal(id+'tc',g)+medalRing()+rk+tb;},
 3:id=>{ // chronomètre
   let p=R(92,16,16,10,SILVER,2,2)+R(96,24,8,8,'#9FA8B4',1.6)+rot(40,100,90,R(94,22,12,8,SILVER,1.8,2));
   p+=C(100,90,50,SILVER,2.6)+C(100,90,42,'#fff',2)+[...Array(60)].map((_,i)=>{const a=i*6*Math.PI/180,r1=i%5?38:34;return L((100+r1*Math.sin(a)).toFixed(1),(90-r1*Math.cos(a)).toFixed(1),(100+40*Math.sin(a)).toFixed(1),(90-40*Math.cos(a)).toFixed(1),i%5?.8:1.8);}).join('');
   p+=`<path d="M100,90 L100,50 A40,40 0 0 1 ${(100+40*Math.sin(57.5*Math.PI/180)).toFixed(1)},${(90-40*Math.cos(57.5*Math.PI/180)).toFixed(1)} Z" fill="#F2D24A" opacity=".45"/>`;
   p+=rot(57.5,100,90,SC('M100,98 L100,52','#C9443A',2.6))+C(100,90,4,'#C9443A',1.4);
   return p+SC('M22,70 L44,70 M16,86 L42,86 M24,102 L44,102',INK,2.4,'opacity=".5"');},
 4:id=>{ // tableau d'affichage 1.00
   let p=R(28,40,144,84,'#1E1E22',2.6,6)+R(36,48,128,68,'#2B2B2B',1.4,3)+L(60,124,52,148,3)+L(140,124,148,148,3);
   p+=`<text x="100" y="98" font-family="Menlo, Consolas, monospace" font-weight="700" font-size="40" fill="#F28C3A" text-anchor="middle" letter-spacing="2">1.00</text>`;
   return p+[...Array(16)].map((_,i)=>C(44+i*7.4,108,1,'#F28C3A',0)).join('')+C(44,56,2,'#C9443A',0);},
 5:id=>{ // maillot jaune
   const j='M70,34 L84,28 C90,36 110,36 116,28 L130,34 L160,54 L148,80 L134,72 L134,144 L66,144 L66,72 L52,80 L40,54 Z';
   let p=S(j,'#F2D24A',2.4)+S('M84,28 C90,40 110,40 116,28 C110,34 90,34 84,28 Z','#E9B030',1.6)+L(100,38,100,70,1.6,INK,.6)+C(100,40,2,SILVER,1);
   return p+SC('M66,72 L66,144 M134,72 L134,144',INK,1)+SC('M74,60 C74,90 76,120 78,140',`#fff`,3,'opacity=".35"')+L(66,136,134,136,1.4,INK,.5);},
 6:id=>{ // casque et drapeau à damier
   let sq='';for(let i=0;i<9;i++)for(let j=0;j<6;j++)if((i+j)%2)sq+=`<rect x="${92+i*9}" y="${20+j*9}" width="9" height="9" fill="#1E1E22"/>`;
   let p=wavyFlag(id+'dm',96,24,72,44,`<rect x="90" y="16" width="84" height="60" fill="#fff"/>`+sq,5,false)+L(96,18,96,96,3,WOOD);
   p+=S('M40,118 C36,86 58,62 92,62 C124,62 146,82 146,108 L146,124 C146,130 140,134 134,134 L58,134 C48,134 40,128 40,118 Z','#C9443A',2.6);
   p+=S('M88,84 C108,78 136,82 146,96 L146,110 L92,110 C86,104 84,92 88,84 Z','#1E1E22',2)+`<path d="M98,88 C112,84 130,86 140,94" fill="none" stroke="#fff" stroke-width="2.6" opacity=".45"/>`;
   return p+SC('M44,104 C70,100 80,110 86,124',PAPER,4)+SC('M44,104 C70,100 80,110 86,124',INK,1,'opacity=".3"')+R(56,130,64,8,'#3B3A3A',1.6,3);},
 7:id=>{ // ballon de basket
   const d='M50,84 A50,50 0 1 1 150,84 A50,50 0 1 1 50,84 Z';
   return S(d,'#E8833A',2.6)+clipTo(id+'bb',d,SC('M100,34 L100,134 M50,84 L150,84 M66,46 C84,64 84,104 66,122 M134,46 C116,64 116,104 134,122',INK,2.2)+`<path d="M66,60 A40,40 0 0 1 96,42" fill="none" stroke="#fff" stroke-width="4" opacity=".35"/>`)+S(d,'none',2.6);},
 8:id=>{ // kimono et ceinture noire
   let p=S('M64,36 L100,48 L136,36 L170,58 L156,92 L140,84 L140,146 L60,146 L60,84 L44,92 L30,58 Z','#F4F1EA',2.4);
   p+=S('M64,36 L100,108 L136,36 L128,34 L100,92 L72,34 Z','#E8E2D4',1.8)+SC('M84,66 L116,66',INK,1,'opacity=".3"');
   p+=R(58,104,84,14,'#1E1E22',2,2)+S('M92,100 L108,100 L110,122 L90,122 Z','#1E1E22',1.8)+S('M94,120 L82,150 L92,152 L100,122 Z M106,120 L118,150 L108,152 L100,122 Z','#1E1E22',1.8);
   return p+SC('M64,36 L60,46 M136,36 L140,46',INK,1);},
 9:id=>{ // ballon ovale
   return rot(-30,100,86,E(100,86,62,38,0,'#8A5A34',2.6)+SC('M42,72 C70,64 130,64 158,72 M42,100 C70,108 130,108 158,100',PAPER,2,'opacity=".7"')+L(76,86,124,86,2.2,PAPER)+[82,90,98,106,114,122].map(x=>L(x,81,x,91,1.8,PAPER)).join('')+`<path d="M58,70 C70,58 90,54 106,54" fill="none" stroke="#fff" stroke-width="3" opacity=".35"/>`);},
 10:id=>{ // trois médailles d'or
   return [[64,98,-10],[136,98,10],[100,104,0]].map(([x,y,a],i)=>rot(a,x,y,medalS(x,y,22,'#F2D24A',['#2F4E8C','#C9443A','#F4F1EA'][i])+star5(x,y,9,'#E9B030',1))).join('');},
 11:id=>{ // coupe
   return cup('#F2D24A')+star5(100,62,9,'#fff',1.2)+[[46,36],[156,36],[40,100],[162,104]].map(([x,y])=>star4(x,y,4,'#F2D24A')).join('');},
};
SUBJECTS['sport.football']={
 1:id=>{ // trophée Jules Rimet : victoire ailée qui lève une coupe octogonale
   let p=S('M72,130 L128,130 L132,150 L68,150 Z',BLUE,2.2)+S('M80,120 L120,120 L126,130 L74,130 Z','#24366A',2)+R(92,144,16,3,GOLD,.6,1);
   const wing=k=>S(`M100,${96} C${100+k*10},86 ${100+k*30},70 ${100+k*40},40 C${100+k*42},34 ${100+k*36},34 ${100+k*34},40 C${100+k*30},54 ${100+k*20},70 ${100+k*8},80 Z`,GOLD,2)+[0,1,2,3].map(i=>SC(`M${100+k*(10+i*6)},${88-i*9} L${100+k*(18+i*6)},${82-i*9}`,INK,1,'opacity=".45"')).join('');
   p+=wing(-1)+wing(1)+S('M90,120 C88,108 92,92 96,80 L104,80 C108,92 112,108 110,120 Z',GOLD,2.2)+SC('M96,96 C98,104 98,112 96,118 M104,96 C102,104 102,112 104,118',INK,1,'opacity=".4"');
   p+=SC('M96,80 L90,62 M104,80 L110,62',GOLD,4.4)+SC('M96,80 L90,62 M104,80 L110,62',INK,1,'opacity=".4"')+C(100,74,5.4,GOLD,1.6);
   p+=S('M80,46 L86,62 L114,62 L120,46 Z',GOLD,2)+S('M78,40 L122,40 L120,46 L80,46 Z','#E9B949',1.8)+L(92,46,94,62,1,INK,.45)+L(108,46,106,62,1,INK,.45);
   return p+`<path d="M84,48 L88,60" stroke="#fff" stroke-width="2.4" opacity=".55"/>`+[[44,40],[156,40]].map(([x,y])=>star4(x,y,4,'#F2D24A')).join('');},
 2:id=>{ // trophée doré qui porte un globe (dessin générique)
   let p=S('M72,136 L128,136 L124,150 L76,150 Z',GOLD,2)+R(76,126,48,10,'#4F9A5A',1.8,2)+R(80,118,40,8,GOLD,1.6,2)+R(82,112,36,6,'#4F9A5A',1.6,2);
   p+=S('M86,112 C88,96 82,82 72,70 C68,62 74,56 82,60 C90,66 96,68 100,68 C104,68 110,66 118,60 C126,56 132,62 128,70 C118,82 112,96 114,112 Z',GOLD,2.2);
   p+=SC('M90,108 C94,96 90,84 80,72 M110,108 C106,96 110,84 120,72',INK,1.2,'opacity=".45"')+`<path d="M78,66 C84,74 88,82 90,92" fill="none" stroke="#fff" stroke-width="2.6" opacity=".5"/>`;
   p+=C(100,42,26,'#F2D24A',2.2)+SC('M80,34 C88,28 96,34 92,42 C88,48 96,54 104,48 M106,22 C114,26 122,32 118,42 M110,60 C116,58 120,54 124,48',`#B8892A`,2);
   return p+`<path d="M84,36 A18,18 0 0 1 96,22" fill="none" stroke="#fff" stroke-width="3" opacity=".55"/>`+[[44,40],[156,44]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
 3:id=>{ // coq tricolore et une étoile (légendaire)
   let p=`<circle cx="100" cy="88" r="60" fill="#F2D24A" opacity=".15"/>`+laurel(100,90,62,160,110,5,7,'#E9B949')+laurel(100,90,62,20,70,5,7,'#E9B949');
   p+=rooster(98,104,1.25,id);
   return p+`<circle cx="148" cy="30" r="16" fill="#F2D24A" opacity=".3"/>`+star5(148,30,13,'#F2D24A',1.6)+star4(40,40,4,'#fff')+star4(168,72,3,'#fff');},
 4:id=>{ // coq et deux étoiles
   return rooster(96,104,1.15,id)+star5(134,24,10,'#F2D24A',1.4)+star5(162,30,10,'#F2D24A',1.4);},
 5:id=>{ // trophée de l'Euro (coupe d'argent)
   let p=S('M80,132 L120,132 L124,148 L76,148 Z','#5C5C5C',2)+S('M94,116 L106,116 L110,132 L90,132 Z',SILVER,2);
   p+=S('M74,34 L126,34 C128,70 118,104 106,116 L94,116 C82,104 72,70 74,34 Z',SILVER,2.4)+E(100,34,26,5,0,'#E8ECF0',2);
   p+=SC('M78,44 C68,46 66,60 76,64 M122,44 C132,46 134,60 124,64',INK,4)+SC('M78,44 C68,46 66,60 76,64 M122,44 C132,46 134,60 124,64',SILVER,2.2);
   return p+`<path d="M84,44 C84,70 88,92 96,108" fill="none" stroke="#fff" stroke-width="3.4" opacity=".6"/>`+L(76,82,124,82,1,INK,.35);},
 6:id=>{ // coupe aux grandes oreilles
   let p=SC('M72,40 C26,36 22,96 78,96 M128,40 C174,36 178,96 122,96',INK,8)+SC('M72,40 C26,36 22,96 78,96 M128,40 C174,36 178,96 122,96',SILVER,5);
   p+=S('M66,30 L134,30 C134,80 118,104 100,106 C82,104 66,80 66,30 Z',SILVER,2.4)+E(100,30,34,6,0,'#E8ECF0',2);
   p+=S('M94,106 L106,106 L108,124 L92,124 Z',SILVER,2)+S('M76,124 L124,124 L128,142 L72,142 Z','#5C5C5C',2.2);
   return p+`<path d="M76,40 C76,66 84,86 94,96" fill="none" stroke="#fff" stroke-width="3.4" opacity=".6"/>`;},
 7:id=>{ // tribune de stade
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#2B3E6E')+[...Array(10)].map((_,i)=>C(30+(i*41)%150,16+(i*17)%20,.9,'#fff',0)).join('');
   g+=S('M10,46 C60,34 140,34 190,46 L190,54 C140,42 60,42 10,54 Z','#1E1E22',1.6);
   for(let r=0;r<5;r++){const y=54+r*12;g+=S(`M10,${y} C60,${y-12} 140,${y-12} 190,${y} L190,${y+12} C140,${y} 60,${y} 10,${y+12} Z`,r%2?'#9FA8B4':'#B9C2CC',1);
     g+=[...Array(20)].map((_,i)=>{const x=14+i*9;const yy=y+6-12*(1-Math.pow((x-100)/90,2))*1+1;return C(x,yy.toFixed(1),1.8,['#F2D24A','#C9443A','#2F4E8C','#F4F1EA'][(i+r*3)%4],0);}).join('');}
   g+=S('M10,114 C60,104 140,104 190,114 L190,160 L10,160 Z','#5E9E4A',1.6)+SC('M20,130 C60,124 140,124 180,130',`#fff`,1.4,'opacity=".8"')+E(100,140,22,6,0,'none',1.4).replace(INK,'#fff')+L(100,108,100,160,1.4,'#fff',.8);
   const pole=x=>L(x,18,x,48,2.6,'#3B3A3A')+R(x-10,10,20,10,'#F4F1EA',1.4,1)+`<circle cx="${x}" cy="15" r="14" fill="#FFF3B0" opacity=".25"/>`;
   return inMedal(id+'st',g+pole(48)+pole(152))+medalRing();},
 8:id=>{ // maillot jaune à col vert et cinq étoiles
   const j='M70,48 L84,42 C90,50 110,50 116,42 L130,48 L160,68 L148,94 L134,86 L134,150 L66,150 L66,86 L52,94 L40,68 Z';
   let p=S(j,'#F2D24A',2.4)+S('M84,42 C90,56 110,56 116,42 C110,48 90,48 84,42 Z','#3E8E4E',1.8)+SC('M40,68 L52,94 M160,68 L148,94','#3E8E4E',4);
   p+=[0,1,2,3,4].map(i=>star5(72+i*14,28-(i===2?3:i%2?1.6:0),6.2,'#3E8E4E',1)).join('');
   return p+S('M110,68 C110,64 122,64 122,68 L122,76 C122,82 116,84 116,84 C116,84 110,82 110,76 Z','#2F4E8C',1.4)+T(100,130,'10','32','#3E8E4E');},
 9:id=>{ // trophée du Ballon d'or : ballon doré sur un socle
   let p=S('M70,128 L130,128 L136,148 L64,148 Z','#3B3A3A',2.2)+S('M84,112 L116,112 L120,128 L80,128 Z','#2B2B2B',2);
   p+=soccer(id+'bt',100,70,40,'#F2D24A','#C9A040');
   return p+`<defs><radialGradient id="${id}g" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#fff" stop-opacity=".5"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></radialGradient></defs><circle cx="100" cy="70" r="40" fill="url(#${id}g)"/>`+R(86,140,28,4,GOLD,.8,1);},
 10:id=>{ // sifflet et carton jaune
   let p=rot(12,124,80,R(102,38,48,68,'#F2D24A',2.4,4)+`<path d="M108,44 L120,44" stroke="#fff" stroke-width="3" opacity=".6"/>`);
   p+=S('M40,104 C40,88 52,80 66,80 L104,80 L104,96 L86,96 C90,100 92,106 92,112 C92,126 80,136 66,136 C52,136 40,124 40,108 Z',SILVER,2.4)+R(100,80,10,16,SILVER,2,2)+C(66,110,10,'#9FA8B4',1.6);
   return p+SC('M60,80 C60,66 48,56 38,58 C30,60 28,70 34,74',INK,2.2)+C(36,74,3.4,'none',1.6);},
};
SUBJECTS['sport.olympics']={
 1:id=>{ // flambeau olympique
   let p=`<circle cx="100" cy="46" r="34" fill="#F28C3A" opacity=".16"/>`;
   p+=S('M100,18 C112,30 122,40 116,56 C126,52 128,44 126,38 C134,52 130,70 116,74 L84,74 C70,70 66,54 74,42 C74,50 78,56 84,58 C78,44 88,30 100,18 Z','#F28C3A',2.2)+S('M100,38 C108,46 112,56 106,68 L94,68 C88,60 92,48 100,38 Z','#F2D24A',1.4);
   p+=S('M76,74 L124,74 L118,86 L82,86 Z',GOLD,2.2)+S('M82,86 L118,86 L104,146 L96,146 Z',GOLD,2.4)+SC('M88,92 L112,92 M90,104 L110,104 M93,118 L107,118',INK,1,'opacity=".45"');
   return p+`<path d="M88,90 L98,140" stroke="#fff" stroke-width="2.6" opacity=".5"/>`+R(94,144,12,6,'#3B3A3A',1.4,2);},
 2:id=>{ // couronne d'olivier
   let p=laurel(100,86,46,95,265,11,9,'#7FA86A')+laurel(100,86,46,85,-85,11,9,'#7FA86A');
   p+=[[58,62],[142,62],[56,112],[144,112],[70,40],[130,40]].map(([x,y])=>E(x,y,3.4,4.6,20,'#4E5A2E',1)).join('');
   return p+SC('M90,134 C94,140 106,140 110,134',`#C9443A`,3)+SC('M94,138 L86,152 M106,138 L114,152','#C9443A',2.4);},
 3:id=>{ // stade panathénaïque : fer à cheval de marbre
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#BFD8EC')+S('M10,52 C50,40 80,48 110,38 C140,30 170,40 190,36 L190,90 L10,90 Z','#8FAE7A',1.2);
   const U=(k)=>`M${24+k},160 L${24+k},${78+k*.4} C${24+k},${34+k*.9} ${176-k},${34+k*.9} ${176-k},${78+k*.4} L${176-k},160`;
   g+=S(U(0)+' Z',MARBLE,1.8)+[6,12,18,24].map(k=>SC(U(k),INK,1,'opacity=".4"')).join('');
   g+=S(U(30)+' Z','#D9B880',1.8)+SC(U(40),'#fff',1.4,'opacity=".7"')+SC(U(50),'#fff',1.4,'opacity=".7"');
   g+=[40,70,100,130,160].map(x=>L(x,148,x,160,1,INK,.2)).join('');
   return inMedal(id+'pn',g)+medalRing();},
 4:id=>{ // saut en Fosbury : dos cambré au-dessus de la barre
   let p=R(30,124,140,22,'#3C6FD0',2,4)+L(34,135,166,135,1,'#fff',.4)+L(44,64,44,124,3)+L(156,64,156,124,3)+L(44,74,156,74,3,'#F2D24A')+L(44,74,156,74,1,INK,.5);
   p+=SC('M58,96 L70,74 L84,62',`#2F4E8C`,7)+SC('M50,104 L58,96',`#E8B48A`,5)+SC('M84,62 L104,58 L126,66 L136,80','#C9443A',11);
   p+=C(144,90,8,'#E8B48A',1.8)+SC('M132,78 L126,96 M138,80 L140,100','#E8B48A',3.6)+SC('M84,62 L104,58 L126,66 L136,80',INK,1,'opacity=".3"');
   return p+SC('M44,98 C42,70 70,40 110,40 C140,40 156,60 160,80',INK,1.2,'stroke-dasharray="3 4" opacity=".45"')+SC('M44,106 L54,104',INK,2);},
 5:id=>{ // skateboard
   let p=rot(-14,100,84,S('M30,74 C24,74 20,68 24,62 L36,70 L164,70 L176,62 C180,68 176,74 170,74 L36,80 C34,80 30,78 30,74 Z','#C9443A',2.4)+R(36,70,128,8,'#2F4E8C',1.8,4)+S('M54,78 L66,78 L62,86 L58,86 Z M134,78 L146,78 L142,86 L138,86 Z',SILVER,1.4)+C(50,94,9,'#F2D24A',2.2)+C(70,94,9,'#F2D24A',2.2)+C(130,94,9,'#F2D24A',2.2)+C(150,94,9,'#F2D24A',2.2)+[50,70,130,150].map(x=>C(x,94,2.4,INK,0)).join(''));
   return p+SC('M30,130 L170,130',INK,1.6,'opacity=".4"')+SC('M44,112 L28,112 M48,120 L24,120',INK,1.6,'opacity=".5"');},
 6:id=>{ // vasque montgolfière (légendaire)
   let p=`<defs><radialGradient id="${id}fl" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#FFF3B0"/><stop offset=".6" stop-color="#F28C3A" stop-opacity=".6"/><stop offset="1" stop-color="#F28C3A" stop-opacity="0"/></radialGradient></defs>`;
   p+=`<ellipse cx="100" cy="130" rx="62" ry="18" fill="url(#${id}fl)"/>`+[...Array(14)].map((_,i)=>{const x=46+i*8.3,h=12+Math.sin(i*1.7)*5;return S(`M${x-4},132 C${x-6},${126-h*.4} ${x},${122-h*.6} ${x},${130-h} C${x+2},${122-h*.6} ${x+6},${126-h*.4} ${x+4},132 Z`,i%2?'#F2D24A':'#F28C3A',1);}).join('');
   p+=E(100,134,52,9,0,'none',2.6).replace(INK,GOLD)+E(100,134,52,9,0,'none',1);
   const env='M100,16 C134,16 152,40 150,66 C148,88 128,100 118,110 L82,110 C72,100 52,88 50,66 C48,40 66,16 100,16 Z';
   p+=S(env,'#F4F1EA',2.6)+clipTo(id+'en',env,[...Array(7)].map((_,i)=>SC(`M${100+(i-3)*16},14 C${100+(i-3)*22},50 ${100+(i-3)*15},90 ${100+(i-3)*6},112`,INK,1,'opacity=".3"')).join('')+`<rect x="40" y="56" width="120" height="10" fill="#E9B949" opacity=".85"/><rect x="40" y="36" width="120" height="3" fill="#E9B949" opacity=".7"/>`)+S(env,'none',2.6);
   p+=SC('M84,110 L92,120 M116,110 L108,120',INK,1.4)+R(90,118,20,8,GOLD,1.4,2)+`<path d="M70,30 C62,40 60,54 62,64" fill="none" stroke="#fff" stroke-width="4" opacity=".7"/>`;
   return p+[[30,36],[172,40],[26,98],[176,100]].map(([x,y],i)=>star4(x,y,4-i%2,'#F2D24A')).join('');},
 7:id=>{ // skieur
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#CFE3F2')+S('M10,70 L50,40 L80,62 L120,30 L160,58 L190,46 L190,90 L10,90 Z','#9FB8CC',1.2)+S('M44,44 L50,40 L58,46 Z M114,34 L120,30 L126,35 Z','#fff',0);
   g+=S('M10,90 C70,80 120,100 190,140 L190,160 L10,160 Z','#fff',1.6)+[[46,92],[150,124]].map(([x,y])=>L(x,y-26,x,y,1.6)+S(`M${x},${y-26} L${x+12},${y-21} L${x},${y-16} Z`,'#C9443A',1)).join('');
   const sk=SC('M60,118 L148,140 M56,112 L144,134',INK,2.6)+S('M92,92 C100,80 116,76 126,82 L120,100 L104,112 L92,108 Z','#C9443A',2)+C(130,74,8,'#2F4E8C',2)+R(124,72,12,4,'#9FD3DC',1,1)+SC('M104,110 L96,124 M118,102 L118,128',`#2F4E8C`,6)+SC('M112,92 L86,120 M120,90 L106,122',INK,1.6);
   return inMedal(id+'sk',g)+medalRing()+sk;},
 8:id=>{ // médaille d'or
   let p=S('M70,14 L96,74 L104,74 L82,14 Z','#2F4E8C',1.6)+S('M130,14 L104,74 L96,74 L118,14 Z','#C9443A',1.6)+S('M82,14 L100,56 L118,14 Z','#F4F1EA',1.4);
   p+=C(100,108,38,'#F2D24A',2.6)+C(100,108,30,'#E9B030',1.6)+laurel(100,108,24,150,30,0,5,'#F2D24A');
   return p+star5(100,106,12,'#F2D24A',1.4)+`<path d="M76,96 A28,28 0 0 1 92,82" fill="none" stroke="#fff" stroke-width="3" opacity=".6"/>`+R(94,68,12,8,GOLD,1.6,2);},
};
SUBJECTS['sport.rules']={
 1:id=>{ // balle sur la ligne
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#3E7A5A')+F('M70,10 L130,10 L130,160 L70,160 Z','#447F5E');
   g+=R(10,96,190,8,'#fff',0)+R(96,10,8,86,'#fff',0)+[...Array(16)].map((_,i)=>C(26+(i*43)%150,20+(i*29)%130,.9,'#2E6648',0)).join('');
   g+=`<ellipse cx="128" cy="104" rx="26" ry="6" fill="#fff" opacity=".6"/>`+[...Array(8)].map((_,i)=>C(108+i*6,106+(i%2)*3,1.2,'#fff',0)).join('');
   const b=C(128,90,16,'#D8E84A',2.4)+SC('M115,80 C124,86 124,96 116,102 M141,80 C132,86 132,96 140,102','#fff',2)+E(128,106,14,3,0,'#000',0).replace('fill="#000"','fill="#000" opacity=".25"');
   return inMedal(id+'tl',g)+medalRing()+b;},
 2:id=>{ // poteaux en H
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#BFD8EC')+S('M10,120 C60,114 140,114 190,120 L190,160 L10,160 Z','#5E9E4A',1.6)+L(30,138,170,138,1.4,'#fff',.8);
   g+=[[50,30],[150,40],[120,22]].map(([x,y])=>E(x,y,14,5,0,'#fff',0)).join('');
   const posts=R(66,14,8,114,'#F4F1EA',2,2)+R(126,14,8,114,'#F4F1EA',2,2)+R(66,78,68,7,'#F4F1EA',2,2)+R(65,96,10,24,'#2F4E8C',1.4,2)+R(125,96,10,24,'#2F4E8C',1.4,2);
   return inMedal(id+'rg',g)+medalRing()+posts;},
 3:id=>{ // panier et filet
   let p=R(46,24,108,70,'#fff',2.4,3)+R(82,50,36,30,'none',2.4).replace(INK,'#C9443A')+R(96,94,8,12,'#9FA8B4',1.4);
   p+=E(100,104,32,6,0,'none',3.4).replace(INK,'#E8833A')+E(100,104,32,6,0,'none',1);
   const net=[0,1,2,3,4,5,6].map(i=>{const x=70+i*10;return SC(`M${x},106 L${82+i*6},144`,INK,1.2)+SC(`M${x},106 L${70+(i+1)*10},144`,INK,1,'opacity=".5"');}).join('')+SC('M72,118 L128,118 M76,130 L124,130 M80,144 L120,144',INK,1);
   return p+net+C(144,40,9,'#E8833A',1.6)+SC('M135,40 L153,40 M144,31 C140,36 140,44 144,49',INK,1);},
 4:id=>{ // cage de but (légendaire)
   let g=`<defs><linearGradient id="${id}sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1E2B4A"/><stop offset="1" stop-color="#3E5A8A"/></linearGradient></defs><rect x="0" y="0" width="200" height="160" fill="url(#${id}sk)"/>`;
   g+=[...Array(18)].map((_,i)=>C(40+(i*29)%120,30+(i*13)%40,1.6,['#C9443A','#F4F1EA','#F2D24A','#2F4E8C'][i%4],0)).join('')+S('M10,64 C60,56 140,56 190,64 L190,80 L10,80 Z','#26365A',1);
   g+=F('M10,80 L190,80 L190,160 L10,160 Z','#4E9A4A')+[0,1,2,3].map(i=>F(`M${10+i*48},80 L${34+i*48},80 L${34+i*48},160 L${10+i*48},160 Z`,'#5AA856')).join('');
   g+=SC('M20,140 L180,140 M44,140 L58,104 L142,104 L156,140','#fff',2,'opacity=".85"')+C(100,128,2.4,'#fff',0);
   let net='';for(let x=44;x<=156;x+=8)net+=L(x,42,x+(x-100)*.12,96,.8,'#fff',.7);for(let y=46;y<=94;y+=7)net+=L(42,y,158,y,.8,'#fff',.7);
   g+=net;
   const frame=SC('M38,104 L38,38 L162,38 L162,104',INK,7)+SC('M38,104 L38,38 L162,38 L162,104','#F4F1EA',4.4)+SC('M38,38 L48,46 M162,38 L152,46','#F4F1EA',1.6);
   const lights=x=>`<circle cx="${x}" cy="28" r="22" fill="#FFF3B0" opacity=".12"/>`;
   return inMedal(id+'cg',g+lights(36)+lights(164))+medalRing()+frame+soccer(id+'bl',132,140,12,'#fff','#2B2B2B',2);},
 5:id=>{ // ballon de volley : trois secteurs de bandes courbes
   const cx=100,cy=84,r=50,P=(x,y,a)=>{const t=a*Math.PI/180,dx=x-cx,dy=y-cy;return [(cx+dx*Math.cos(t)-dy*Math.sin(t)).toFixed(1),(cy+dx*Math.sin(t)+dy*Math.cos(t)).toFixed(1)].join(',');};
   const curve=a=>`C${P(124,74,a)} ${P(126,46,a)} ${P(100,34,a)}`,back=a=>`C${P(126,46,a)} ${P(124,74,a)} ${P(100,84,a)}`;
   const sector=(a,f)=>S(`M100,84 ${curve(a)} A50,50 0 0 1 ${P(100,34,a+120)} ${back(a+120)} Z`,f,0);
   const d='M50,84 A50,50 0 1 1 150,84 A50,50 0 1 1 50,84 Z';
   let in_=sector(0,'#F2D24A')+sector(120,'#2F4E8C')+sector(240,'#F4F1EA');
   for(const a of [0,120,240])in_+=SC(`M100,84 ${curve(a)}`,INK,2)+rot(a,100,84,SC('M112,82 C134,72 140,52 128,40 M120,92 C146,84 154,62 146,44',INK,1.2,'opacity=".6"'));
   return S(d,'#F4F1EA',2.6)+clipTo(id+'vb',d,in_+`<path d="M62,64 A40,40 0 0 1 84,42" fill="none" stroke="#fff" stroke-width="4" opacity=".5"/>`)+S(d,'none',2.6);},
 6:id=>{ // haie
   let p=S('M10,128 L190,128 L190,150 L10,150 Z','#C9604A',1.6)+L(10,139,190,139,1.6,'#fff',.8);
   p+=SC('M54,60 L54,128 M146,60 L146,128',INK,4)+SC('M54,128 L36,128 M146,128 L164,128',INK,4)+SC('M54,100 L62,100 M146,100 L138,100',INK,3);
   let bar=R(46,50,108,16,'#fff',2.2,2);for(let i=0;i<6;i++)if(i%2)bar+=R(46+i*18,50,18,16,'#1E1E22',0);
   return p+bar+R(46,50,108,16,'none',2.2,2);},
 7:id=>{ // couloirs de piscine
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#5BB0E0')+[...Array(9)].map((_,i)=>SC(`M20,${18+i*16} q10,-3 20,0 t20,0 t20,0 t20,0 t20,0 t20,0 t20,0 t20,0`,'#fff',1,'opacity=".35"')).join('');
   g+=[44,84,124].map(y=>[...Array(20)].map((_,i)=>C(20+i*8.4,y,3.6,i%4<2?'#C9443A':'#F4F1EA',.8)).join('')).join('');
   g+=[64,104].map(y=>R(20,y-2,160,4,'#2F4E8C',0)).join('');
   const sw=E(70,102,16,5,0,'#2F4E8C',1.4)+C(88,100,5,'#F2D24A',1.4)+SC('M56,98 C50,92 56,88 62,94 M84,96 C92,86 104,88 108,96','#E8B48A',3);
   return inMedal(id+'pc',g+sw)+medalRing();},
 8:id=>{ // maillot à pois
   const j='M70,34 L84,28 C90,36 110,36 116,28 L130,34 L160,54 L148,80 L134,72 L134,144 L66,144 L66,72 L52,80 L40,54 Z';
   let dots='';for(let y=30;y<150;y+=16)for(let x=40;x<164;x+=16)dots+=C(x+((y/16)%2?8:0),y,5,'#C9443A',0);
   return S(j,'#F8F6F0',2.4)+clipTo(id+'po',j,dots)+S(j,'none',2.4)+S('M84,28 C90,40 110,40 116,28 C110,34 90,34 84,28 Z','#C9443A',1.6)+L(100,38,100,70,1.4,INK,.5);},
 9:id=>{ // voiture de Formule 1
   let p=S('M20,96 L36,84 L84,80 L104,66 L120,66 L128,80 L164,84 L180,92 L182,104 L20,106 Z','#C9443A',2.4)+S('M14,74 L36,74 L36,96 L14,96 Z','#1E1E22',2)+S('M166,96 L190,96 L190,106 L160,106 Z','#1E1E22',2);
   p+=S('M104,66 C108,58 118,58 120,66 Z','#F2D24A',1.6)+R(76,86,40,6,'#fff',0)+L(36,90,164,92,1,INK,.4);
   return p+[48,152].map(x=>C(x,106,17,'#1E1E22',2.4)+C(x,106,7,'#9FA8B4',1.6)).join('')+SC('M2,84 L12,84 M0,96 L10,96',INK,1.6,'opacity=".5"');},
 10:id=>{ // drapeau sur le green
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#BFE0F0')+S('M10,90 C60,80 140,84 190,92 L190,160 L10,160 Z','#7FBF5E',1.6)+E(100,118,70,24,0,'#9CD478',1.6);
   g+=E(108,120,9,3,0,'#1E1E22',1.4)+[[60,46],[150,40]].map(([x,y])=>E(x,y,16,5,0,'#fff',0)).join('');
   const fl=L(108,120,108,30,2.6,'#F4F1EA')+L(108,120,108,30,1,INK,.6)+wavyFlag(id+'gf',108,32,40,24,`<rect x="100" y="24" width="56" height="40" fill="#C9443A"/>`,4,false)+C(76,128,5,'#fff',1.6);
   return inMedal(id+'gr',g)+medalRing()+fl;},
 11:id=>{ // fleuret, épée et sabre, côte à côte
   const w=(x,a,guard)=>rot(a,x,84,`<g transform="translate(${x-100} 0)">${SC('M100,18 L100,104',INK,4.4)+SC('M100,18 L100,104',SILVER,2.4)+guard+R(96,110,8,24,'#3B3A3A',1.8,2)+C(100,137,4.4,SILVER,1.6)}</g>`);
   const foil=E(100,106,8,3,0,SILVER,1.8),epee=S('M86,110 C86,96 114,96 114,110 Z',SILVER,2),sabre=S('M90,106 L112,106 L112,110 L90,110 Z',SILVER,1.8)+SC('M112,108 C124,114 122,130 108,136',SILVER,4)+SC('M112,108 C124,114 122,130 108,136',INK,1,'opacity=".5"');
   return w(64,-12,foil)+w(100,0,epee)+w(136,12,sabre);},
 12:id=>{ // cibles du biathlon
   let p=R(26,50,148,62,'#F4F1EA',2.4,4)+R(26,112,148,10,'#9FA8B4',2,2);
   return p+[0,1,2,3,4].map(i=>{const x=46+i*27;return C(x,81,11,'#1E1E22',2)+(i<3?C(x,81,10,'#fff',1.4)+C(x,81,4,'#C9443A',0):C(x,81,4,'#3B3A3A',0))}).join('')+L(40,128,40,146,3)+L(160,128,160,146,3);},
 13:id=>{ // roi d'échecs
   let p=E(100,150,44,5,0,'#000',0).replace('fill="#000"','fill="#000" opacity=".15"')+S('M68,138 L132,138 L136,150 L64,150 Z','#2B2B2B',2.2)+S('M72,128 L128,128 L132,138 L68,138 Z','#3B3A3A',2);
   p+=S('M80,128 C84,108 86,90 84,72 L116,72 C114,90 116,108 120,128 Z','#2B2B2B',2.4)+E(100,72,22,6,0,'#3B3A3A',2)+S('M82,66 C80,52 90,44 100,44 C110,44 120,52 118,66 Z','#2B2B2B',2.2);
   return p+R(96,20,8,26,'#2B2B2B',2,1)+R(88,26,24,8,'#2B2B2B',2,1)+`<path d="M90,78 C90,100 88,114 86,126" stroke="#fff" stroke-width="3" opacity=".3" fill="none"/>`;},
 14:id=>{ // boules de pétanque
   const boule=(x,y,r)=>C(x,y,r,'#B9C2CC',2.4)+SC(`M${x-r},${y} C${x-r*.4},${y-r*.3} ${x+r*.4},${y-r*.3} ${x+r},${y} M${x-r*.9},${y+r*.4} C${x-r*.3},${y+r*.1} ${x+r*.3},${y+r*.1} ${x+r*.9},${y+r*.4}`,INK,1,'opacity=".5"')+`<path d="M${x-r*.6},${y-r*.4} A${r*.7},${r*.7} 0 0 1 ${x-r*.1},${y-r*.75}" fill="none" stroke="#fff" stroke-width="3" opacity=".7"/>`;
   let p=S('M14,130 C60,122 140,122 186,130 L186,150 L14,150 Z','#D9C08A',1.6)+[...Array(14)].map((_,i)=>C(24+i*12,138+(i%3)*3,1,'#A88A5A',0)).join('');
   return p+boule(62,104,26)+boule(126,96,30)+boule(98,128,18)+C(156,126,7,'#E8B030',1.8);},
 15:id=>{ // batte et balle de baseball
   let p=rot(-38,100,84,S('M100,10 C108,10 110,20 110,40 L104,124 L96,124 L90,40 C90,20 92,10 100,10 Z','#C9A06A',2.4)+R(95,124,10,26,'#3B2A1E',1.8,2)+E(100,152,8,3,0,'#3B2A1E',1.6)+`<path d="M95,24 L95,60" stroke="#fff" stroke-width="2.4" opacity=".5"/>`);
   return p+C(144,112,16,'#F8F6F0',2.4)+SC('M132,102 C138,108 138,116 132,122 M156,102 C150,108 150,116 156,122','#C9443A',1.4,'stroke-dasharray="2 2"');},
};
