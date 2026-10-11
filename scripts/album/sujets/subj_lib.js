/* --- formes partagées entre les pages : profils, lauriers, livres, rectangles --- */
const R=(x,y,w,h,fill='none',sw=2.2,rx=0)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${INK}" stroke-width="${sw}" stroke-linejoin="round"/>`;
const E=(cx,cy,rx,ry,rot=0,fill='none',w=1.4)=>`<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${cx} ${cy})" fill="${fill}" stroke="${INK}" stroke-width="${w}"/>`;
const F=(d,fill,o=1)=>`<path d="${d}" fill="${fill}" opacity="${o}" stroke="none"/>`;
const clipTo=(cid,d,inner)=>`<clipPath id="${cid}"><path d="${d}"/></clipPath><g clip-path="url(#${cid})">${inner}</g>`;
const rot=(a,cx,cy,inner)=>`<g transform="rotate(${a} ${cx} ${cy})">${inner}</g>`;
/* profil tourné vers la droite, centré en (0,0), environ 64 × 84 */
const PROFILE='M-16,42 C-17,30 -24,18 -26,2 C-28,-24 -12,-40 6,-40 C22,-40 31,-28 31,-14 C31,-10 32,-6 34,-2 C36,2 38,4 37,6 C36,8 33,8 32,9 C33,11 33,12 31,13 C33,15 32,17 30,18 C31,22 30,26 26,27 C22,28 18,28 14,28 C14,34 15,38 17,42';
function head(x,y,s,fill=PAPER,o={}){
  const w=2.2/s;
  let p=S(PROFILE,fill,w);
  if(o.ear!==false)p+=S('M-6,-2 C-12,-4 -14,8 -8,12 C-6,13 -4,11 -4,9','none',w*.7);
  p+=S('M18,-8 C21,-10 24,-10 26,-8','none',w*.8)+S('M20,-4 C22,-5 24,-5 25,-4','none',w*.6);
  return `<g transform="translate(${x} ${y}) scale(${s})">${p}${o.over||''}</g>`;}
/* feuilles de laurier le long d'un arc (angles en degrés, 90 = bas) */
function laurel(cx,cy,r,a0,a1,n,sz=7,fill=GOLD){
  const rd=a=>a*Math.PI/180, P=a=>[(cx+r*Math.cos(rd(a))).toFixed(1),(cy+r*Math.sin(rd(a))).toFixed(1)];
  const [x0,y0]=P(a0),[x1,y1]=P(a1);
  let p=`<path d="M${x0},${y0} A${r},${r} 0 ${Math.abs(a1-a0)>180?1:0},${a1>a0?1:0} ${x1},${y1}" fill="none" stroke="${INK}" stroke-width="1.6"/>`;
  for(let i=0;i<n;i++){const a=a0+(a1-a0)*(i+.6)/n;
    for(const s of [-1,1]){const rr=r+s*sz*.62,x=(cx+rr*Math.cos(rd(a))).toFixed(1),y=(cy+rr*Math.sin(rd(a))).toFixed(1);
      p+=E(x,y,sz,sz*.4,a+(a1>a0?90:-90)-s*28,fill,1.2);}}
  return p;}
/* livre ouvert : centre cx, haut ty, demi-largeur hw, hauteur h */
function openBook(cx,ty,hw,h,cover=WAX,lines=true){
  const l=cx-hw,r=cx+hw,b=ty+h;
  let p=S(`M${l-4},${ty+6} L${l-4},${b+6} C${l+hw*.4},${b} ${cx-hw*.3},${b} ${cx},${b+8} C${cx+hw*.3},${b} ${r-hw*.4},${b} ${r+4},${b+6} L${r+4},${ty+6} Z`,cover,2);
  p+=S(`M${cx},${ty+4} C${cx-hw*.3},${ty-4} ${l+hw*.3},${ty-4} ${l},${ty+2} L${l},${b} C${l+hw*.4},${b-6} ${cx-hw*.3},${b-6} ${cx},${b+2} Z`,PAPER,2);
  p+=S(`M${cx},${ty+4} C${cx+hw*.3},${ty-4} ${r-hw*.3},${ty-4} ${r},${ty+2} L${r},${b} C${r-hw*.4},${b-6} ${cx+hw*.3},${b-6} ${cx},${b+2} Z`,PAPER,2);
  if(lines)for(let y=ty+10;y<b-8;y+=6){p+=L(l+7,y,cx-6,y+1,1,INK,.45)+L(cx+6,y+1,r-7,y,1,INK,.45);}
  return p+L(cx,ty+4,cx,b+2,1.6);}
const star5=(x,y,r,fill=GOLD,w=.8)=>{x=+x;y=+y;let d='';for(let i=0;i<10;i++){const a=-Math.PI/2+i*Math.PI/5,rr=i%2?r*.42:r;d+=(i?'L':'M')+(x+rr*Math.cos(a)).toFixed(1)+','+(y+rr*Math.sin(a)).toFixed(1);}return S(d+'Z',fill,w);};
function timeline(marks){
  let p=L(26,86,174,86,3)+S('M168,80 L178,86 L168,92','none',2.4);
  p+=marks.map(([x,t],i)=>L(x,78,x,94,2)+C(x,86,4.4,i===0||i===marks.length-1?TONE:GOLD,1.6)+T(x,i%2?112:68,t,11,INK,'middle',800)).join('');
  return p+`<rect x="${marks[0][0]}" y="83" width="${marks[marks.length-1][0]-marks[0][0]}" height="6" fill="${TONE}" opacity=".18"/>`;}
const WOOD='#8A5A34', BLUE='#2F4E8C', SILVER='#D5DADF', GREEN='#4F7A3A';
const SC=(d,col,w=2.2,extra='')=>`<path d="${d}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
