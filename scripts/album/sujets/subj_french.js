/* --- Français : objets, lettres et mots --- */
const wtile=(x,y,w,h,t,size,fill='#F8F2E6',col=INK,font='Fraunces, Georgia, serif')=>R(x+2,y+4,w,h,'#9A8F7E',0,6)+R(x,y,w,h,fill,2.2,6)+`<text x="${x+w/2}" y="${y+h/2+size*.34}" font-family="${font}" font-weight="800" font-size="${size}" fill="${col}" text-anchor="middle">${t}</text>`;
const hand=(x,y,t,size,col=INK)=>`<text x="${x}" y="${y}" font-family="'Segoe Script','Bradley Hand','Comic Sans MS',cursive" font-size="${size}" fill="${col}">${t}</text>`;
SUBJECTS['french.expressions']={
 1:id=>{ // mouton dans le pré (légendaire) : « revenons à nos moutons »
   let g=`<defs><linearGradient id="${id}sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BFE0F4"/><stop offset="1" stop-color="#E8F4FA"/></linearGradient></defs><rect x="20" y="10" width="160" height="150" fill="url(#${id}sk)"/>`;
   g+=E(60,40,18,6,0,'#fff',0)+E(150,34,14,5,0,'#fff',0)+S('M10,104 C50,92 90,100 120,94 C150,88 170,96 190,94 L190,160 L10,160 Z','#9CCB78',1.4)+S('M10,124 C60,116 140,120 190,114 L190,160 L10,160 Z','#86B864',1.2);
   g+=[[30,130],[44,140],[150,136],[168,128]].map(([x,y])=>C(x,y,2.4,'#fff',.8)+C(x,y,1,'#F2D24A',0)).join('');
   let sh=[[-26,-6,14],[-14,-16,14],[2,-18,15],[18,-14,14],[28,-2,13],[20,10,14],[4,14,14],[-12,12,14],[-26,6,13],[0,-2,18]].map(([x,y,r])=>C(x,y,r,'#FBFAF6',2)).join('')+[[-14,-16,14],[2,-18,15],[18,-14,14],[0,-2,18]].map(([x,y,r])=>C(x,y,r-2,'#FBFAF6',0)).join('');
   sh=[[-18,22],[-6,24],[10,24],[22,20]].map(([x,y])=>R(x-3,y,6,18,'#3B3A3A',1.4,2)).join('')+sh;
   sh+=E(38,-14,12,16,-25,'#3B3A3A',2)+E(30,-26,7,3.4,-30,'#3B3A3A',1.6)+E(50,-24,7,3.4,30,'#3B3A3A',1.6)+C(34,-24,9,'#FBFAF6',1.8)+C(42,-24,8,'#FBFAF6',1.6)+C(36,-12,2,'#fff',0)+C(44,-12,2,'#fff',0)+C(36.4,-11.6,1,INK,0)+C(44.4,-11.6,1,INK,0);
   return inMedal(id+'pr',g)+medalRing()+`<g transform="translate(92 98) scale(1.25)">${sh}</g>`;},
 2:id=>{ // gant vert de jardinier et plante
   let p=S('M114,148 L106,108 L162,108 L154,148 Z','#C9704A',2.4)+R(102,100,64,10,'#B85E3A',2.2,2)+SC('M134,100 C132,80 138,64 136,46',GREEN,3);
   p+=[[124,72,-40],[146,62,40],[128,52,-30],[144,84,30]].map(([x,y,a])=>E(x,y,12,5,a,'#7FB86A',1.4)).join('');
   p+=S('M44,140 L44,104 C40,96 38,86 40,76 C42,70 50,70 50,78 L52,90 L52,62 C52,54 62,54 62,62 L62,88 L64,56 C64,48 74,48 74,56 L74,88 L78,62 C78,54 88,56 88,64 L86,96 C92,90 100,92 98,100 C92,112 86,122 82,140 Z','#5EA84A',2.4);
   return p+R(42,134,42,14,'#3E8A3A',2,2)+SC('M58,96 C62,92 70,92 74,96',INK,1,'opacity=".35"');},
 3:id=>{ // part de fromage
   const w='M34,112 L150,52 C164,62 170,78 170,92 L170,126 L34,126 Z';
   let p=E(100,130,78,12,0,'#E8ECF0',2.2)+S(w,'#F2C84A',2.4)+S('M34,112 L150,52 C164,62 170,78 170,92 Z','#F8DA6A',2.2);
   p+=[[80,108,8],[120,112,6],[150,104,7],[104,88,4],[136,78,5]].map(([x,y,r])=>E(x,y,r,r*.8,0,'#D9A830',1.4)).join('')+E(60,96,4,3,0,'#D9A830',1.2);
   return p+[[40,40],[170,30]].map(([x,y])=>star4(x,y,4,'#F2D24A')).join('');},
 4:id=>{ // nuage d'avril : soleil et averse
   let p=C(130,52,20,'#F2D24A',2)+[...Array(8)].map((_,i)=>{const a=i*Math.PI/4;return L((130+25*Math.cos(a)).toFixed(1),(52+25*Math.sin(a)).toFixed(1),(130+32*Math.cos(a)).toFixed(1),(52+32*Math.sin(a)).toFixed(1),2.4,'#E9A030');}).join('');
   p+=S('M38,100 C26,100 22,82 36,78 C36,62 56,56 66,66 C72,50 98,48 104,66 C118,62 130,72 126,86 C138,88 138,100 128,100 Z','#F4F7FA',2.4)+S('M38,100 C26,100 24,90 30,86 C60,94 100,94 134,94 C134,98 132,100 128,100 Z','#D8E2EA',0);
   return p+[[46,112],[62,120],[78,110],[94,122],[110,112],[58,138],[90,140],[74,132]].map(([x,y])=>SC(`M${x},${y} L${x-4},${y+10}`,'#3C6FD0',2.4)).join('');},
 5:id=>{ // arche romaine en construction
   let p=S('M10,140 L190,140 L190,150 L10,150 Z','#D9C08A',1.4);
   p+=S('M44,140 L44,70 L156,70 L156,140 L128,140 L128,104 C128,88 116,80 100,80 C84,80 72,88 72,104 L72,140 Z','#E8D8B8',2.4);
   p+=[0,1,2,3,4,5,6].map(i=>{const a=Math.PI+i*Math.PI/6;return L((100+28*Math.cos(a)).toFixed(1),(104+28*Math.sin(a)).toFixed(1),(100+40*Math.cos(a)).toFixed(1),(104+40*Math.sin(a)).toFixed(1),1.2,INK,.5);}).join('')+[86,102,118].map(y=>L(44,y,72,y,1,INK,.4)+L(128,y,156,y,1,INK,.4)).join('');
   p+=R(80,46,40,24,'none',0)+[0,1,2].map(i=>R(56+i*30,56+(i===1?-6:0),26,14,'#E8D8B8',2,1)).join('');
   p+=SC('M36,140 L36,40 M164,140 L164,40 M36,60 L164,60 M36,100 L44,100 M156,100 L164,100',WOOD,2.6)+SC('M36,40 L60,60 M164,40 L140,60',WOOD,1.6);
   return p+SC('M150,40 L150,20 L120,20',INK,1.6)+R(116,20,8,12,'#9A9A9A',1.2,1);},
 6:id=>{ // chandelle
   let p=`<circle cx="100" cy="46" r="30" fill="#FFE7A0" opacity=".35"/>`+S('M100,22 C108,32 110,44 100,54 C90,44 92,32 100,22 Z','#F28C3A',1.6)+S('M100,34 C104,40 104,46 100,50 C96,46 96,40 100,34 Z','#FFF3B0',0);
   p+=L(100,54,100,60,1.6)+R(88,60,24,62,'#FBF6EA',2.4,2)+S('M88,64 C92,70 96,66 98,74 L98,62 Z','#FBF6EA',1.2);
   return p+E(100,126,40,8,0,GOLD,2.2)+R(90,120,20,8,GOLD,2,2)+SC('M140,126 C156,126 160,108 146,104',GOLD,4)+SC('M140,126 C156,126 160,108 146,104',INK,1,'opacity=".5"');},
};
SUBJECTS['french.grammar']={
 1:id=>{ // tableau noir de conjugaison (légendaire)
   let p=R(20,24,160,108,WOOD,2.6,4)+R(28,32,144,92,'#2E4A3A',1.6,2)+`<rect x="28" y="32" width="144" height="92" fill="#fff" opacity=".04"/>`;
   const lines=[['je','suis'],['tu','es'],['il','est'],['nous','sommes']];
   p+=T(100,50,'être',15,'#F2D24A','middle',700)+L(78,55,122,55,1.2,'#F2D24A',.8);
   p+=lines.map(([a,b],i)=>hand(44,72+i*15,a,12,'#F4F1EA')+hand(92,72+i*15,b,12,'#F4F1EA')).join('');
   p+=R(26,132,148,6,'#7A4A28',1.6,2)+R(118,126,24,6,'#F4F1EA',1.2,2)+R(60,124,30,9,'#C9A86A',1.6,2)+R(62,124,26,4,'#5A5A5A',0,1);
   return p+SC('M36,40 C60,36 80,38 96,42',`#fff`,1,'opacity=".15"')+[[18,16],[182,18]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
 2:id=>{ // flèche d'accord : le sujet commande
   let p=wtile(22,92,74,34,'elles',20)+wtile(110,92,74,34,'parties',18);
   p+=SC('M58,90 C62,54 140,54 146,88',`#C9443A`,2.6)+S('M140,84 L147,92 L152,82 Z','#C9443A',1.6);
   return p+`<rect x="160" y="96" width="20" height="26" fill="#F2D24A" opacity=".45" rx="3"/>`+T(100,48,'être',14,'#2F4E8C','middle',800);},
 3:id=>{ // vitrail
   const w='M54,148 L54,64 C54,32 76,18 100,18 C124,18 146,32 146,64 L146,148 Z';
   const cols=['#3C6FD0','#E8443A','#F2D24A','#4FC05A','#8B5CF6','#F28C3A'];
   let pieces='';let k=0;for(let y=16;y<150;y+=22)for(let x=50;x<150;x+=24){pieces+=S(`M${x},${y} L${x+24},${y+4} L${x+22},${y+24} L${x-2},${y+20} Z`,cols[(k++*7)%6],1.6);}
   return S(w,'#3B3A3A',4)+clipTo(id+'vt',w,pieces+C(100,60,16,'#F2D24A',2)+star5(100,60,9,'#fff',1))+S(w,'none',4)+L(100,18,100,148,2.4)+R(48,146,104,8,'#9A8F7E',2,2);},
 4:id=>{ // arbre de la phrase
   const box=(x,y,t,f)=>R(x-22,y-11,44,22,f,2,5)+T(x,y+4.4,t,12,INK,'middle',800);
   let p=SC('M100,44 L50,92 M100,44 L100,92 M100,44 L150,92 M150,104 L130,132 M150,104 L170,132',INK,2);
   return p+box(100,40,'phrase','#F2D24A')+box(50,96,'sujet','#9FD3DC')+box(100,96,'verbe','#E8A0B8')+box(150,96,'COD','#9CC27A')+[[130,136],[170,136]].map(([x,y])=>R(x-14,y-6,28,12,'#F4F1EA',1.4,3)).join('');},
 5:id=>{ // et et est
   return wtile(22,56,64,52,'et',32)+T(100,94,'≠',28,'#C9443A','middle',800)+wtile(114,56,68,52,'est',30,'#FFF3D0');},
};
SUBJECTS['french.spelling']={
 1:id=>wtile(22,46,66,70,'a',46)+wtile(112,46,66,70,'à',46,'#FFF3D0','#C9443A')+T(100,92,'/',30,'#9A9A9A','middle',700),
 2:id=>{ // pot de peinture et pinceau : « ils ont peint »
   let p=S('M48,78 L120,78 L114,146 L54,146 Z','#C9CED4',2.4)+E(84,78,36,8,0,'#3C6FD0',2.2);
   p+=SC('M48,80 C40,60 60,48 84,46 C108,48 128,60 120,80',INK,1.6);
   return p+rot(35,138,70,R(132,24,12,60,'#C9A06A',2,3)+R(130,82,16,12,SILVER,1.8,1)+S('M130,94 L146,94 L148,114 C144,120 132,120 128,114 Z','#3C6FD0',1.8));},
 3:id=>{ // chèque en toutes lettres (légendaire)
   let p=R(14,36,172,96,'#EAF3F0',2.4,4)+[...Array(8)].map((_,i)=>SC(`M14,${44+i*11} q20,-3 40,0 t40,0 t40,0 t40,0 t12,0`,'#A8D0C4',.8)).join('');
   p+=R(124,46,54,18,'#fff',1.6,2)+mono(151,59,'80,00 €',10,INK);
   p+=L(24,80,176,80,.8,INK,.5)+hand(28,77,'quatre-vingts euros',13,'#2F4E8C');
   p+=`<rect x="122" y="66" width="12" height="16" fill="#F2D24A" opacity=".55" rx="2"/>`+L(24,98,110,98,.8,INK,.5)+L(120,118,176,118,.8,INK,.5)+hand(126,116,'Léa',12,'#2F4E8C');
   p+=R(24,108,70,14,'#fff',1,2)+[0,1,2,3,4,5].map(i=>R(28+i*10,112,6,6,'#3B3A3A',0)).join('');
   return p+rot(-30,170,24,R(166,6,8,44,'#2F4E8C',1.6,2)+S('M166,50 L174,50 L170,58 Z','#F4F1EA',1.2))+star4(20,22,5,'#F2D24A')+star4(24,148,4,'#F2D24A');},
 4:id=>{ // bijoux
   let p=SC('M40,36 C40,90 160,90 160,36',GOLD,3)+SC('M40,36 C40,90 160,90 160,36',INK,1,'opacity=".4"')+[...Array(9)].map((_,i)=>{const t=i/8,x=40+t*120,y=36+Math.sin(t*Math.PI)*40;return C(x.toFixed(1),y.toFixed(1),3,'#F4F1EA',1);}).join('');
   p+=S('M100,78 L112,90 L100,108 L88,90 Z','#3C6FD0',2)+L(88,90,112,90,1,INK,.5);
   return p+E(66,128,18,8,0,'none',4).replace(INK,GOLD)+E(66,128,18,8,0,'none',1)+S('M60,116 L66,108 L72,116 L66,122 Z','#E8443A',1.6)+E(136,128,16,7,0,'none',4).replace(INK,SILVER)+E(136,128,16,7,0,'none',1)+C(136,118,5,'#9FE0F0',1.6);},
 5:id=>{ // gomme et crayon
   let p=rot(-30,100,84,R(30,74,120,18,'#F2D24A',2.4,1)+L(30,80,150,80,1,INK,.3)+L(30,86,150,86,1,INK,.3)+S('M150,74 L172,83 L150,92 Z','#E8C99A',2)+S('M164,80 L172,83 L164,86 Z','#3B3A3A',0)+R(18,74,14,18,SILVER,2)+R(8,74,12,18,'#E8838A',2,3));
   p+=rot(12,64,128,R(38,116,52,24,'#E8838A',2.2,4)+R(38,116,22,24,'#3C6FD0',2.2,4));
   return p+[[104,136],[110,132],[100,142]].map(([x,y])=>C(x,y,1.6,'#E8838A',.6)).join('');},
 6:id=>wtile(52,28,96,104,'ô',72,'#F8F2E6',INK)+S('M78,62 L100,40 L122,62 L112,62 L100,50 L88,62 Z','#E9B030',1.4).replace(/^/,'')+[[36,40],[164,124]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join(''),
};
SUBJECTS['french.synonyms']={
 1:id=>{ // jour et nuit : les contraires (légendaire)
   const half='M100,26 A58,58 0 0 1 100,142 Z';
   let p=`<circle cx="100" cy="84" r="66" fill="#F2D24A" opacity=".14"/>`+C(100,84,58,'#9FD3F0',2.6)+S(half,'#1E2B4A',0);
   p+=C(72,72,15,'#F2D24A',1.8)+[...Array(8)].map((_,i)=>{const a=i*Math.PI/4;return L((72+19*Math.cos(a)).toFixed(1),(72+19*Math.sin(a)).toFixed(1),(72+24*Math.cos(a)).toFixed(1),(72+24*Math.sin(a)).toFixed(1),2,'#E9A030');}).join('')+E(62,112,14,5,0,'#fff',0);
   p+=S('M138,58 C124,60 118,74 122,86 C126,98 140,104 152,100 C140,98 132,88 132,76 C132,68 134,62 138,58 Z','#F4E9C0',1.6)+[[118,46],[150,118],[160,72],[124,112]].map(([x,y])=>star4(x,y,3,'#fff')).join('');
   return p+L(100,26,100,142,2)+C(100,84,58,'none',2.6);},
 2:id=>wtile(14,58,72,44,'ardu',24)+T(100,90,'=',30,'#4F9A5A','middle',800)+wtile(114,58,76,44,'difficile',17,'#EAF4E8'),
 3:id=>{ // dictionnaire des synonymes
   let p=S('M48,40 L132,32 L152,46 L152,140 L68,148 L48,134 Z','#2F4E8C',2.4)+S('M48,40 L68,54 L68,148 L48,134 Z','#24366A',2)+S('M68,54 L152,46 L152,52 L68,60 Z','#F4F1EA',1.4);
   p+=S('M80,72 L140,66 L140,96 L80,102 Z','#F2D24A',1.6)+T(110,90,'A = B',13,INK,'middle',800);
   return p+S('M130,46 L130,24 L138,30 L146,22 L146,47 Z','#C9443A',1.6)+[64,84,104,124].map(y=>L(52,y-2+(y/30),64,y+6,1,'#F2D24A',.7)).join('');},
};
SUBJECTS['french.vocabulary']={
 1:id=>openBook(100,46,56,72,WAX)+T(70,80,'A',28,'#C9443A','middle',800)+T(130,80,'O',28,'#2F4E8C','middle',800),
 2:id=>{ // loupe sur une page
   let p=R(36,26,104,124,'#F8F2E6',2.2,3)+[...Array(9)].map((_,i)=>R(48,40+i*12,i%3===2?50:80,3,'#B8B0A0',0,1.5)).join('');
   p+=C(118,92,32,'#fff',3)+clipCircle(id+'lp',118,92,30,`<rect x="80" y="60" width="80" height="70" fill="#F8F2E6"/>`+T(118,98,'sibyllin',14,INK,'middle',800))+C(118,92,32,'none',3)+`<circle cx="118" cy="92" r="30" fill="#9FD3F0" opacity=".2"/>`;
   return p+SC('M141,115 L166,140',INK,10)+SC('M141,115 L166,140','#6B4426',6)+`<path d="M98,74 A22,22 0 0 1 112,66" fill="none" stroke="#fff" stroke-width="3" opacity=".8"/>`;},
 3:id=>{ // plume, encrier et guillemets (légendaire)
   let p=R(26,40,120,100,'#F8F2E6',2.2,3)+T(86,104,'« »',56,'#C9443A','middle',800)+[56,124].map(y=>R(40,y,92,3,'#C8BFA8',0,1.5)).join('');
   p+=S('M138,140 L170,140 L166,118 C166,110 142,110 142,118 Z','#1E2B4A',2.2)+E(154,114,10,3,0,'#3B3A3A',1.6);
   p+=S('M152,112 C150,80 160,40 186,14 C182,44 174,76 156,112 Z','#F4F1EA',2)+SC('M152,112 C160,80 172,46 186,14',INK,1.2)+[0,1,2,3,4].map(i=>SC(`M${160+i*4},${90-i*16} L${170+i*4},${84-i*16}`,INK,.9,'opacity=".4"')).join('');
   return p+[[20,30],[176,150]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
 4:id=>{ // arbre aux racines grecques
   let g=F('M20,10 L180,10 L180,160 L20,160 Z','#DDEFF8')+S('M10,96 L190,96 L190,160 L10,160 Z','#C9A06A',1.4)+[[40,110],[150,140],[70,150],[160,108]].map(([x,y])=>C(x,y,2,'#A8804A',0)).join('');
   g+=SC('M100,96 C96,110 80,118 60,124 M100,96 C102,112 100,126 100,142 M100,96 C108,110 124,116 144,122 M80,118 C70,130 60,134 46,138',WOOD,3);
   g+=T(56,116,'α',16,'#2F4E8C','middle',800)+T(114,144,'β',15,'#2F4E8C','middle',800)+T(150,112,'γ',16,'#2F4E8C','middle',800);
   const tr=S('M92,98 C92,76 90,64 86,56 L114,56 C110,64 108,76 108,98 Z',WOOD,2.2)+C(100,44,32,'#7FB86A',2.4)+C(74,56,18,'#7FB86A',2)+C(126,56,18,'#7FB86A',2)+C(100,44,24,'#8CC478',0)+T(100,50,'ἵππος',13,INK,'middle',700);
   return inMedal(id+'rc',g)+medalRing()+tr;},
 5:id=>{ // bulle de SMS : MDR
   let p=S('M30,40 C30,30 38,24 48,24 L152,24 C162,24 170,30 170,40 L170,96 C170,106 162,112 152,112 L82,112 L54,136 L60,112 L48,112 C38,112 30,106 30,96 Z','#4FC05A',2.6);
   return p+T(100,82,'MDR',36,'#fff','middle',800)+[[142,128],[154,128],[166,128]].map(([x,y])=>C(x,y,3.4,'#9A9A9A',0)).join('');},
 6:id=>{ // baguette et croissant
   let p=R(20,124,160,12,'#B07A4A',2,4)+rot(-10,100,80,S('M24,86 C24,72 40,68 100,68 C160,68 176,72 176,86 C176,98 160,102 100,102 C40,102 24,98 24,86 Z','#E0A458',2.4)+[50,76,102,128,154].map(x=>SC(`M${x-8},${80} C${x-2},${74} ${x+4},${74} ${x+10},${80}`,'#F6D49A',2.4)).join(''));
   const cr='M40,124 C30,104 50,90 66,98 C76,84 124,84 134,98 C150,90 170,104 160,124 C150,116 140,114 132,118 C120,108 80,108 68,118 C60,114 50,116 40,124 Z';
   return p+S(cr,'#D9963A',2.4)+SC('M66,98 C70,104 70,110 68,118 M86,90 C90,98 90,106 88,112 M114,90 C110,98 110,106 112,112 M134,98 C130,104 130,110 132,118',INK,1.4,'opacity=".5"')+`<path d="M76,94 C88,88 104,88 116,90" fill="none" stroke="#FFE7A0" stroke-width="2.4" opacity=".8"/>`;},
};
