/* --- Calcul : instruments, signes et objets du quotidien --- */
const tile=(x,y,w,h,t,size,fill='#F4F1EA',col=INK)=>R(x+2,y+4,w,h,'#9A8F7E',0,6)+R(x,y,w,h,fill,2.2,6)+T(x+w/2,y+h/2+size*.34,t,size,col,'middle',800);
const mono=(x,y,t,size,col=INK,w=700)=>`<text x="${x}" y="${y}" font-family="Menlo, Consolas, monospace" font-weight="${w}" font-size="${size}" fill="${col}" text-anchor="middle">${t}</text>`;
function clockFace(cx,cy,r,h,m,fill='#fff',roman=false){
  let p=C(cx,cy,r,fill,2.4);
  for(let i=0;i<60;i++){const a=i*6*Math.PI/180,r1=i%5?r*.88:r*.8;if(roman&&i%5===0)continue;p+=L((cx+r1*Math.sin(a)).toFixed(1),(cy-r1*Math.cos(a)).toFixed(1),(cx+r*.94*Math.sin(a)).toFixed(1),(cy-r*.94*Math.cos(a)).toFixed(1),i%5?.7:1.8);}
  if(roman)p+=['XII','I','II','III','IV','V','VI','VII','VIII','IX','X','XI'].map((t,i)=>{const a=i*30*Math.PI/180;return T((cx+r*.72*Math.sin(a)).toFixed(1),(cy-r*.72*Math.cos(a)+2.8).toFixed(1),t,7.6,INK,'middle',700);}).join('');
  const ha=(h%12+m/60)*30,ma=m*6;
  return p+rot(ha,cx,cy,SC(`M${cx},${cy+4} L${cx},${cy-r*.5}`,INK,3.4))+rot(ma,cx,cy,SC(`M${cx},${cy+6} L${cx},${cy-r*.76}`,INK,2.2))+C(cx,cy,3.4,GOLD,1.2);}
SUBJECTS['calc.conversions']={
 1:id=>{ // mètre ruban
   let p=S('M96,104 L176,104 L176,124 L96,124 Z','#F2D24A',2);
   for(let x=100;x<176;x+=4)p+=L(x,104,x,x%20===0?114:x%10===0?111:108,x%20===0?1.4:.8);
   p+=[120,140,160].map((x,i)=>T(x,121,String(i+1),7,INK,'middle',700)).join('')+R(172,100,8,28,'#5C5C5C',1.6,1);
   p+=C(72,100,44,'#E8574A',2.6)+C(72,100,34,'#C9443A',1.6)+C(72,100,10,'#5C5C5C',1.6)+C(72,100,4,SILVER,1)+R(104,96,12,32,'#C9443A',2,3);
   return p+`<path d="M44,80 A34,34 0 0 1 64,68" fill="none" stroke="#fff" stroke-width="3.4" opacity=".45"/>`+R(60,134,24,10,'#5C5C5C',1.6,2);},
 2:id=>{ // balance de cuisine
   let p=S('M40,140 L160,140 L150,96 L50,96 Z','#E8ECF0',2.6)+C(100,120,15,'#fff',2)+rot(28,100,120,SC('M100,120 L100,109','#C9443A',2))+[...Array(9)].map((_,i)=>{const a=(-120+i*30)*Math.PI/180;return L((100+12*Math.sin(a)).toFixed(1),(120-12*Math.cos(a)).toFixed(1),(100+15*Math.sin(a)).toFixed(1),(120-15*Math.cos(a)).toFixed(1),1);}).join('');
   p+=R(56,88,88,8,'#C9CED4',2,3)+S('M44,50 L156,50 C152,76 132,88 100,88 C68,88 48,76 44,50 Z','#DDF0F8',2.4)+`<path d="M56,58 C62,72 74,80 88,82" fill="none" stroke="#fff" stroke-width="3" opacity=".7"/>`;
   return p+S('M70,52 C70,38 84,30 98,34 C104,26 120,28 122,40 C132,42 134,52 128,56 Z','#F2D24A',1.6)+C(84,44,5,'#F2C14E',1)+C(108,38,4,'#F2C14E',1);},
 3:id=>{ // sablier (légendaire)
   let p=`<circle cx="100" cy="84" r="58" fill="#F2D24A" opacity=".15"/>`;
   const glass='M66,32 L134,32 C134,62 110,72 104,84 C110,96 134,106 134,136 L66,136 C66,106 90,96 96,84 C90,72 66,62 66,32 Z';
   p+=S(glass,'#EAF4F8',2.4)+clipTo(id+'sb',glass,S('M60,46 L140,46 L140,52 C126,64 108,74 100,84 C92,74 74,64 60,52 Z','#E8B868',0)+S('M60,136 L60,122 C76,110 90,104 100,102 C110,104 124,110 140,122 L140,136 Z','#E8B868',0)+`<path d="M100,84 L100,104" stroke="#E8B868" stroke-width="2.4"/>`+[0,1,2,3].map(i=>C(100+(i%2?1:-1),90+i*3,.8,'#C9944A',0)).join(''))+S(glass,'none',2.4);
   p+=`<path d="M74,40 C76,56 86,66 94,74" fill="none" stroke="#fff" stroke-width="3.4" opacity=".8"/><path d="M76,128 C78,114 86,106 92,100" fill="none" stroke="#fff" stroke-width="2.4" opacity=".6"/>`;
   const plate=y=>R(52,y,96,10,WOOD,2.4,3)+R(56,y+2,88,3,'#B07A4A',0,1.5);
   p+=plate(22)+plate(136)+[56,144].map(x=>R(x-4,32,8,104,'#8A5A34',2,3)+[52,70,98,116].map(y=>E(x,y,5.4,2.6,0,'#B07A4A',1.2)).join('')).join('');
   return p+[[30,40],[170,44],[28,124],[172,128]].map(([x,y],i)=>star4(x,y,4+i%2,'#F2D24A')).join('');},
 4:id=>{ // compteur de vitesse
   let p=S('M30,112 A70,70 0 0 1 170,112 L150,112 A50,50 0 0 0 50,112 Z','#2B2B2B',2.4)+S('M30,112 A70,70 0 0 1 170,112 Z','#1E1E22',2.4);
   p+=`<path d="M146,62 A64,64 0 0 1 164,112" fill="none" stroke="#E8443A" stroke-width="7" opacity=".85"/>`;
   for(let i=0;i<=12;i++){const a=(-90+i*15)*Math.PI/180;p+=L((100+50*Math.sin(a)).toFixed(1),(112-50*Math.cos(a)).toFixed(1),(100+60*Math.sin(a)).toFixed(1),(112-60*Math.cos(a)).toFixed(1),i%2?1.2:2.4,'#fff');}
   p+=rot(40,100,112,SC('M100,118 L100,58','#F28C3A',3.4))+C(100,112,8,'#5C5C5C',2)+R(78,120,44,14,'#2B2B2B',1.6,3)+mono(100,131,'km/h',10,'#F2D24A');
   return p+L(24,112,176,112,2.4);},
 5:id=>{ // étiquette de marché
   let p=SC('M100,22 C90,30 92,40 100,44',INK,1.6)+S('M66,48 L134,48 L150,64 L150,132 L50,132 L50,64 Z','#F8F2E6',2.4)+C(100,58,4,'#fff',1.6);
   p+=T(100,96,'2,50 €',26,'#C9443A','middle',800)+T(100,118,'le kilo',13,INK,'middle',700);
   return p+[[34,138],[164,132],[170,146]].map(([x,y],i)=>C(x,y,10-i*2,['#E8443A','#E8443A','#F28C3A'][i],1.8)+SC(`M${x},${y-9+i*2} L${x+2},${y-14+i*2}`,GREEN,1.6)).join('');},
};
SUBJECTS['calc.fractions']={
 1:id=>{ // pizza en parts : il reste trois quarts (légendaire)
   let p=`<circle cx="100" cy="88" r="62" fill="#F2D24A" opacity=".14"/>`;
   const cx=94,cy=92,r=52;
   p+=S(`M${cx},${cy} L${cx},${cy-r} A${r},${r} 0 1 0 ${cx+r},${cy} Z`,'#E8B060',2.6)+S(`M${cx},${cy} L${cx},${cy-r+7} A${r-7},${r-7} 0 1 0 ${cx+r-7},${cy} Z`,'#F2D27A',1.4);
   p+=[[70,70],[66,110],[100,124],[78,92],[112,104],[56,90],[94,72]].map(([x,y])=>C(x,y,6.4,'#C9443A',1.4)+C(x-1.6,y-1.6,1.4,'#E8746A',0)).join('')+[[84,62],[60,124],[118,118],[70,82]].map(([x,y],i)=>E(x,y,4,2,i*40,'#5E9E4A',1)).join('');
   p+=SC(`M${cx},${cy} L${cx},${cy-r} M${cx},${cy} L${cx-r},${cy} M${cx},${cy} L${cx},${cy+r}`,INK,1.4,'opacity=".55"');
   const sl=`M0,0 L0,${-r} A${r},${r} 0 0 1 ${r},0 Z`;
   p+=`<g transform="translate(${cx+16} ${cy-18})">${S(sl,'#E8B060',2.6)+S(`M0,0 L0,${-r+7} A${r-7},${r-7} 0 0 1 ${r-7},0 Z`,'#F2D27A',1.4)+C(18,-22,6.4,'#C9443A',1.4)+C(30,-10,6,'#C9443A',1.4)+E(12,-38,4,2,30,'#5E9E4A',1)}</g>`;
   return p+SC(`M${cx+4},${cy-8} C${cx+8},${cy-14} ${cx+12},${cy-14} ${cx+16},${cy-18} M${cx+6},${cy-2} C${cx+12},${cy-6} ${cx+16},${cy-8} ${cx+20},${cy-12}`,'#F8E6A0',2.2)+star4(40,36,5,'#F2D24A')+star4(164,140,4,'#F2D24A');},
 2:id=>{ // barres de fractions
   const row=(y,n,cols,on)=>[...Array(n)].map((_,i)=>R(30+i*140/n,y,140/n,24,i<on?cols:'#F4F1EA',2,2)).join('');
   return row(30,1,'#9FD3DC',1)+row(62,2,'#F2D24A',1)+row(94,4,'#E8838A',1)+row(126,4,'#9CC27A',3)+SC('M24,138 L18,138 L18,30 L24,30',INK,1,'opacity=".4"');},
 3:id=>{ // fraction renversée
   const fr=(x,a,b,c)=>T(x,72,a,30,c,'middle',800)+L(x-16,82,x+16,82,3,c)+T(x,114,b,30,c,'middle',800);
   let p=tile(30,40,52,88,'',1)+fr(56,'2','3',INK)+tile(118,40,52,88,'',1,'#FFF3D0')+fr(144,'3','2','#C9443A');
   return p+SC('M90,84 L110,84',INK,2.6)+S('M106,78 L114,84 L106,90 Z',INK,1.4)+SC('M60,30 C80,16 120,16 140,30',INK,1.6,'stroke-dasharray="3 3" opacity=".6"');},
 4:id=>{ // fraction et virgule : un huitième
   let p=C(100,68,36,'#F4F1EA',2.4);
   p+=S(`M100,68 L100,32 A36,36 0 0 1 ${(100+36*Math.sin(Math.PI/4)).toFixed(1)},${(68-36*Math.cos(Math.PI/4)).toFixed(1)} Z`,'#F28C3A',2);
   p+=[...Array(8)].map((_,i)=>{const a=i*Math.PI/4;return L(100,68,(100+36*Math.sin(a)).toFixed(1),(68-36*Math.cos(a)).toFixed(1),1.2);}).join('');
   return p+mono(100,130,'0,125',20,'#C9443A');},
};
SUBJECTS['calc.mental']={
 1:id=>{ // plaques de chiffres (légendaire)
   let p=R(46,24,108,34,'#1E1E22',2.4,5)+R(52,30,96,22,'#2B1A1A',1,3)+mono(100,48,'742',22,'#FF5A4A');
   p+=`<rect x="52" y="30" width="96" height="22" fill="#FF5A4A" opacity=".08"/>`;
   const nums=['1','5','10','25','50','100'];
   p+=nums.map((t,i)=>{const x=24+i*26+(i>2?4:0),y=82+(i%2)*14,a=(i-2.5)*4;return rot(a,x+12,y+20,R(x+2,y+3,26,40,'#8A7E6A',0,3)+R(x,y,26,40,i===5?'#F2D24A':'#F8F2E6',2,3)+T(x+13,y+25,t,t.length>2?10:13,INK,'middle',800));}).join('');
   return p+[[30,30],[170,30],[24,146],[176,146]].map(([x,y])=>star4(x,y,4,'#F2D24A')).join('');},
 2:id=>{ // grille de Pythagore : la case 7 × 8
   let p='';const s=11,x0=50,y0=34;
   for(let r=0;r<9;r++)for(let c=0;c<9;c++){const hi=(r===6&&c<=7)||(c===7&&r<=6);p+=`<rect x="${x0+c*s}" y="${y0+r*s}" width="${s}" height="${s}" fill="${hi?'#FFE7A0':'#fff'}" stroke="${INK}" stroke-width=".5"/>`;}
   p+=R(x0,y0,9*s,9*s,'none',2.2,2);
   return p+`<rect x="${x0+7*s-3}" y="${y0+6*s-3}" width="${s+6}" height="${s+6}" fill="#F28C3A" stroke="${INK}" stroke-width="1.8" rx="2"/>`+star4(x0+7.5*s,y0+6.5*s,4,'#fff');},
 3:id=>{ // carré quadrillé : puissance de deux
   let p='';for(let r=0;r<8;r++)for(let c=0;c<8;c++)p+=`<rect x="${42+c*9}" y="${48+r*9}" width="9" height="9" fill="${(r<4&&c<4)?'#9FD3DC':(r<4||c<4)?'#DDF0F8':'#fff'}" stroke="${INK}" stroke-width=".6"/>`;
   p+=R(42,48,72,72,'none',2.4,1)+R(42,48,36,36,'none',1.8,1);
   return p+T(138,104,'2',40,'#2F4E8C','middle',800)+T(160,76,'10',18,'#C9443A','middle',800);},
 4:id=>tile(56,28,88,88,'×',80,'#FFF3D0','#C9443A')+[[36,40],[164,120]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join(''),
 5:id=>tile(56,28,88,88,'÷',80,'#DDF0F8','#2F4E8C')+[[36,40],[164,120]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join(''),
 6:id=>{ // boulier
   let p=R(26,26,148,112,'none',8,6).replace(INK,WOOD)+R(26,26,148,112,'none',2,6)+R(30,30,140,104,'#FBF6EA',0,3);
   const cols=['#E8443A','#F28C3A','#F2D24A','#4FC05A','#3C6FF0'];
   for(let r=0;r<5;r++){const y=44+r*20;p+=L(30,y,170,y,1.6,'#8A8A8A');const n=[3,6,7,4,2][r];for(let k=0;k<10;k++){const x=k<n?40+k*11:72+k*10;p+=E(x,y,5,7,0,cols[r],1.4);}}
   return p+L(26,138,18,152,4,WOOD)+L(174,138,182,152,4,WOOD);},
 7:id=>{ // billet et pièces
   let p=rot(-8,92,72,R(30,40,124,64,'#E8B07A',2.4,4)+R(36,46,112,52,'none',1,3)+C(70,72,16,'#F2D2A8',1.4)+T(128,80,'50',26,'#8A4A2A','middle',800)+[0,1,2].map(i=>L(96,60+i*8,118,60+i*8,1,INK,.35)).join(''));
   const coin=(x,y,r,f)=>C(x,y,r,f,2)+C(x,y,r*.74,'none',1)+T(x,y+r*.32,r>14?'2':'1',r*.9,INK,'middle',800);
   return p+coin(120,122,18,'#C9CED4')+C(120,122,10,'#E9B949',0)+T(120,128,'2',14,INK,'middle',800)+coin(156,116,15,'#E9B949')+coin(82,128,13,'#E9B949');},
 8:id=>{ // montre-bracelet
   let p=R(80,8,40,40,'#6B4426',2.2,6)+R(80,120,40,40,'#6B4426',2.2,6)+[16,28,128,140].map(y=>L(84,y,116,y,1,INK,.35)).join('')+R(94,136,12,6,SILVER,1.2,1);
   return p+C(100,84,42,SILVER,2.6)+clockFace(100,84,34,10,10)+R(140,78,8,12,SILVER,1.6,2);},
};
SUBJECTS['calc.number_logic']={
 1:id=>{ // crible des nombres premiers
   const pr=new Set([2,3,5,7,11,13,17,19,23]);let p='';
   for(let n=1;n<=25;n++){const c=(n-1)%5,r=Math.floor((n-1)/5),x=44+c*23,y=24+r*23;p+=R(x,y,21,21,pr.has(n)?(n===2?'#F28C3A':'#FFE7A0'):'#F4F1EA',1.4,3)+T(x+10.5,y+15,String(n),10,pr.has(n)?INK:'#9A9A9A','middle',800)+(pr.has(n)||n===1?'':L(x+4,y+17,x+17,y+4,1.2,'#C9443A',.7));}
   return p;},
 2:id=>{ // règle graduée
   return rot(-10,100,84,R(16,64,168,40,'#F2D24A',2.4,3)+[...Array(31)].map((_,i)=>{const x=22+i*5.2;return L(x,64,x,i%10===0?80:i%5===0?76:71,i%5===0?1.4:.8);}).join('')+[0,10,20,30].map((n,i)=>T(22+i*52,92,String(n),9,INK,'middle',700)).join('')+`<path d="M20,98 L180,98" stroke="#fff" stroke-width="2" opacity=".4"/>`);},
 3:id=>{ // escalier de nombres : l'astuce de Gauss (légendaire)
   let p=`<rect x="20" y="24" width="160" height="120" fill="#F2D24A" opacity=".1"/>`;const s=13,x0=35,y0=138;
   for(let i=0;i<10;i++)for(let k=0;k<=i;k++)p+=R(x0+i*s,y0-(k+1)*s,s,s,'#3C6FF0',1.2,2);
   for(let i=0;i<10;i++)for(let k=i+1;k<=10;k++)p+=R(x0+i*s,y0-(k+1)*s,s,s,'#F28C3A',1.2,2);
   p+=R(x0,y0-11*s,10*s,11*s,'none',2.4,2)+SC(`M${x0+10*s+8},${y0-11*s} L${x0+10*s+8},${y0}`,INK,1.4)+SC(`M${x0},${y0+8} L${x0+10*s},${y0+8}`,INK,1.4);
   return p+T(x0+10*s+18,y0-5*s,'11',10,INK,'start',800)+T(x0+5*s,y0+20,'10',10,INK,'middle',800);},
 4:id=>{ // cadran en chiffres romains
   return C(100,84,58,'#C9A86A',2.6)+clockFace(100,84,50,10,10,'#F8F2E6',true);},
 5:id=>{ // horloge et angle des aiguilles
   let p=C(100,84,56,'#2F4E8C',2.6)+clockFace(100,84,48,3,0);
   return p+`<path d="M100,84 L100,58 A26,26 0 0 1 126,84 Z" fill="#F28C3A" opacity=".35"/>`+SC('M100,72 L112,72 L112,84',INK,1.4);},
 6:id=>{ // piquets de clôture
   let p=S('M10,128 C60,122 140,122 190,128 L190,150 L10,150 Z','#9CC27A',1.6);
   p+=R(26,70,150,7,'#C9A06A',1.6,2)+R(26,100,150,7,'#C9A06A',1.6,2);
   return p+[...Array(6)].map((_,i)=>{const x=24+i*30;return S(`M${x},132 L${x},58 L${x+6},50 L${x+12},58 L${x+12},132 Z`,'#E8C99A',2)+L(x+6,62,x+6,128,1,INK,.3);}).join('');},
 7:id=>{ // signe égal
   return R(42,54,116,18,'#2F4E8C',2.4,6)+R(42,92,116,18,'#2F4E8C',2.4,6)+`<path d="M50,59 L120,59 M50,97 L120,97" stroke="#fff" stroke-width="3" opacity=".4"/>`+[[40,36],[160,130]].map(([x,y])=>star4(x,y,5,'#F2D24A')).join('');},
};
SUBJECTS['calc.percent']={
 1:id=>{ // signe pour cent et un quart
   let p=C(100,84,52,'#F4F1EA',2.4)+S('M100,84 L100,32 A52,52 0 0 1 152,84 Z','#F28C3A',2.2);
   return p+T(100,104,'%',64,'#2F4E8C','middle',800);},
 2:id=>{ // étiquette barrée
   let p=rot(-12,100,84,S('M40,54 L138,54 L164,84 L138,114 L40,114 Z','#E8443A',2.6)+C(146,84,5,'#fff',1.6)+T(88,94,'−30 %',26,'#fff','middle',800));
   return p+SC('M146,84 C160,70 168,50 160,34',INK,1.6)+T(70,46,'40 €',15,'#7A7A7A','middle',700)+L(52,41,88,41,2,'#C9443A');},
 3:id=>{ // ticket de caisse
   const zz=[...Array(11)].map((_,i)=>`L${150-i*10},${i%2?152:146}`).join(' ');
   let p=S(`M50,16 L150,16 L150,146 ${zz} Z`,'#FBFAF6',2.2);
   p+=R(70,26,60,6,'#3B3A3A',0,3)+[44,56,68,80].map((y,i)=>R(60,y,44,3,'#9A9A9A',0,1.5)+R(122,y,18,3,'#9A9A9A',0,1.5)).join('')+L(58,94,142,94,1.2,INK,.5);
   return p+mono(78,110,'TVA',10,INK)+mono(126,110,'20 %',10,'#C9443A')+mono(78,128,'TOTAL',10,INK)+R(112,120,30,11,'#FFE7A0',1,2);},
 4:id=>{ // flèches haut et bas : on ne revient pas au départ (légendaire)
   let p=R(24,24,152,120,'#F8FAFC',2.2,6)+[44,64,84,104,124].map(y=>L(28,y,172,y,.8,INK,.18)).join('')+L(40,96,170,96,1.2,'#2F4E8C',.6).replace('opacity=".6"','opacity=".6" stroke-dasharray="4 3"');
   p+=SC('M40,96 L100,46 L164,102','#2F4E8C',3);
   p+=S('M54,92 L54,60 L46,60 L62,42 L78,60 L70,60 L70,92 Z','#4FC05A',2)+S('M130,48 L130,80 L122,80 L138,98 L154,80 L146,80 L146,48 Z','#E8443A',2);
   p+=C(40,96,4.4,'#2F4E8C',1.4)+C(100,46,4.4,'#2F4E8C',1.4)+C(164,102,4.4,'#E8443A',1.4);
   return p+T(64,124,'+10 %',13,'#3E9A48','middle',800)+T(138,124,'−10 %',13,'#C9443A','middle',800)+star4(176,24,5,'#F2D24A')+star4(24,146,4,'#F2D24A');},
 5:id=>{ // pièce à pile ou face
   let p=SC('M40,120 C40,70 70,40 98,34',INK,1.4,'stroke-dasharray="3 4" opacity=".5"')+SC('M160,120 C160,70 130,40 102,34',INK,1.4,'stroke-dasharray="3 4" opacity=".5"');
   p+=E(100,84,46,44,0,'#B8892A',0)+C(100,82,44,'#E9B949',2.6)+C(100,82,35,'none',1.4)+star5(100,80,16,'#F2D24A',1.4);
   return p+`<path d="M70,64 A34,34 0 0 1 90,50" fill="none" stroke="#fff" stroke-width="3" opacity=".6"/>`+E(100,146,30,4,0,'#000',0).replace('fill="#000"','fill="#000" opacity=".12"');},
};
