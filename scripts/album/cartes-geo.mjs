// Vrais contours pour les cartes : node scripts/album/cartes-geo.mjs scripts/album/sujets/subj_maps.js
// Dépendances (dans un dossier de travail) : npm i world-atlas@2.0.2 topojson-client@3 d3-geo@3
// Génère sujets/subj_maps.js : vrais contours (Natural Earth, domaine public, via world-atlas) projetés pour le canevas 200×160.
import fs from 'node:fs'; import {feature} from 'topojson-client'; import * as d3 from 'd3-geo';
const W=JSON.parse(fs.readFileSync('node_modules/world-atlas/countries-50m.json'));
const L110=JSON.parse(fs.readFileSync('node_modules/world-atlas/land-110m.json'));
const countries=feature(W,W.objects.countries).features;
const byId=id=>countries.find(f=>+f.id===id);
// arrondit à 0,1 px et retire les points à moins de tol px du précédent
const r1=(s,tol=.9)=>s.split(/(?=[MZ])/).map(seg=>{if(seg[0]==='Z')return 'Z';const pts=seg.slice(1).split('L').map(p=>p.split(',').map(Number));const k=[pts[0]];for(const p of pts.slice(1)){const q=k[k.length-1];if(Math.hypot(p[0]-q[0],p[1]-q[1])>=tol)k.push(p);}
  return k.length<3?'':'M'+k.map(p=>p.map(v=>+v.toFixed(1)).join(',')).join('L');}).filter((x,i,a)=>x&&!(x==='Z'&&(i===0||a[i-1]===''))).join('');
// garde seulement les polygones dont un point tombe dans la boîte [lon0,lat0,lon1,lat1]
function clipFeature(f,box){const g=f.geometry;const polys=g.type==='Polygon'?[g.coordinates]:g.coordinates;
  const keep=polys.filter(p=>p[0].some(([x,y])=>x>=box[0]&&x<=box[2]&&y>=box[1]&&y<=box[3]));
  return {type:'Feature',geometry:{type:'MultiPolygon',coordinates:keep}};}
// enlève les îlots trop petits (moins de minArea en px²)
function shape(f,proj,minArea){const path=d3.geoPath(proj);const g=f.geometry;
  const polys=(g.type==='Polygon'?[g.coordinates]:g.coordinates).filter(p=>path.area({type:'Polygon',coordinates:p})>=minArea);
  return r1(path({type:'MultiPolygon',coordinates:polys}));}
const pt=(proj,ll)=>proj(ll).map(v=>+v.toFixed(1));
const out={};
{ // France métropolitaine et Corse
  const f=clipFeature(byId(250),[-6,41,10,52]);const proj=d3.geoConicConformal().rotate([-3,0]).parallels([44,49]).fitExtent([[34,22],[166,146]],f);
  out.france={d:shape(f,proj,6),cities:Object.fromEntries(Object.entries({Paris:[2.35,48.86],Lyon:[4.84,45.76],Marseille:[5.37,43.30],Bordeaux:[-0.58,44.84]}).map(([k,v])=>[k,pt(proj,v)]))};}
{ // Australie
  const f=byId(36);const proj=d3.geoMercator().fitExtent([[22,24],[178,146]],f);
  out.australia={d:shape(f,proj,8),cities:{Canberra:pt(proj,[149.13,-35.28])}};}
{ // Afrique du Sud
  const f=byId(710);const proj=d3.geoMercator().fitExtent([[22,30],[178,140]],clipFeature(f,[15,-36,34,-21]));
  out.southAfrica={d:shape(clipFeature(f,[15,-36,34,-21]),proj,4),cities:{Pretoria:pt(proj,[28.19,-25.75]),'Le Cap':pt(proj,[18.42,-33.92]),Bloemfontein:pt(proj,[26.21,-29.12])}};}
{ // globes (projection orthographique)
  const land=feature(L110,L110.objects.land);
  const globe=(rot,r)=>{const proj=d3.geoOrthographic().rotate(rot).scale(r).translate([100,84]).clipAngle(90);return r1(d3.geoPath(proj)(land),1.6);};
  out.globeEurAfr=globe([-10,-15],52);
  {const proj=d3.geoOrthographic().rotate([-10,-15]).scale(52).translate([100,84]);out.globeEurAfrCities=Object.fromEntries(Object.entries({Paris:[2.35,48.86],Moscou:[37.6,55.75],'Le Caire':[31.2,30],Nairobi:[36.8,-1.3],Dakar:[-17.4,14.7]}).map(([k,v])=>[k,pt(proj,v)]));}
  out.globeAtlantic=globe([40,-25],54);
  const proj=d3.geoOrthographic().rotate([40,-25]).scale(54).translate([100,84]);
  out.globeAtlanticCities={Paris:pt(proj,[2.35,48.86]),'New York':pt(proj,[-74,40.7])};}
{ // Pangée : Afrique et Amérique du Sud rapprochées
  const land=feature(L110,L110.objects.land);const polys=land.features.flatMap(f=>f.geometry.type==='Polygon'?[f.geometry.coordinates]:f.geometry.coordinates);
  const pick=([lo,la])=>polys.find(p=>d3.geoContains({type:'Polygon',coordinates:p},[lo,la]));
  const afr={type:'Polygon',coordinates:pick([20,0])},sam={type:'Polygon',coordinates:pick([-60,-15])};
  const pa=d3.geoOrthographic().rotate([-15,0]).fitExtent([[96,22],[176,146]],afr);
  const ps=d3.geoOrthographic().rotate([60,15]).fitExtent([[24,40],[104,148]],sam);
  out.pangea={afr:r1(d3.geoPath(pa)(afr),1.2),sam:r1(d3.geoPath(ps)(sam),1.2)};}
const js='/* vrais contours (Natural Earth, domaine public, via world-atlas) ; généré par scripts/album/cartes-geo.mjs */\nconst MAPS='+JSON.stringify(out)+';\n';
fs.writeFileSync(process.argv[2],js);console.log(Object.keys(out).map(k=>k+':'+JSON.stringify(out[k]).length).join(' '));
