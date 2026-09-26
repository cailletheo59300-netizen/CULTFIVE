#!/usr/bin/env node
// Récupère les données Wikidata (CC0) et les met en cache dans scripts/wikidata/cache/*.json.
// Le cache est versionné : la génération des questions est reproductible sans réseau.
// Usage : node scripts/wikidata/fetch.mjs [nom-de-requête…]
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const cacheDir = join(here, 'cache');
mkdirSync(cacheDir, { recursive: true });

const label = (v, lang = 'fr') => `?${v} rdfs:label ?${v}Fr FILTER(lang(?${v}Fr) = "${lang}")`;

const people = (occupations, minLinks) => `
SELECT DISTINCT ?p ?pFr ?desc ?birth ?death ?sex ?sl WHERE {
  VALUES ?occ { ${occupations.split(' ').map((o) => `wd:${o}`).join(' ')} }
  ?p wdt:P106 ?occ; wdt:P31 wd:Q5; wikibase:sitelinks ?sl FILTER(?sl >= ${minLinks})
  ?p wdt:P569 ?birth.
  OPTIONAL { ?p wdt:P570 ?death }
  OPTIONAL { ?p wdt:P21 ?sex }
  ${label('p')}
  OPTIONAL { ?p schema:description ?desc FILTER(lang(?desc) = "fr") }
}`;

export const QUERIES = {
  countries: `
SELECT ?c ?cFr ?cEn ?iso ?cap ?capFr ?cont ?contFr ?pop ?area ?sl WHERE {
  ?c wdt:P463 wd:Q1065; wdt:P31 wd:Q3624078; wdt:P297 ?iso; wikibase:sitelinks ?sl.
  ${label('c')} ?c rdfs:label ?cEn FILTER(lang(?cEn) = "en")
  OPTIONAL { ?c wdt:P36 ?cap. ${label('cap')} }
  OPTIONAL { ?c wdt:P30 ?cont. ${label('cont')} }
  OPTIONAL { ?c wdt:P1082 ?pop }
  OPTIONAL { ?c wdt:P2046 ?area }
}`,
  cities: `
SELECT ?city ?cityFr ?cityEn ?country ?pop ?coord ?sl WHERE {
  ?city wdt:P31 wd:Q1549591; wdt:P17 ?country; wdt:P1082 ?pop; wikibase:sitelinks ?sl
  OPTIONAL { ?city wdt:P625 ?coord }
  FILTER(?sl >= 100 && ?pop >= 1000000)
  ${label('city')} ?city rdfs:label ?cityEn FILTER(lang(?cityEn) = "en")
}`,
  capitalsGeo: `
SELECT ?c ?cap ?coord WHERE {
  ?c wdt:P463 wd:Q1065; wdt:P31 wd:Q3624078; wdt:P36 ?cap. ?cap wdt:P625 ?coord.
}`,
  currencies: `
SELECT ?c ?cur ?curFr WHERE {
  ?c wdt:P463 wd:Q1065; wdt:P31 wd:Q3624078; wdt:P38 ?cur. ${label('cur')}
}`,
  languages: `
SELECT ?c ?lang ?langFr WHERE {
  ?c wdt:P463 wd:Q1065; wdt:P31 wd:Q3624078; wdt:P37 ?lang. ${label('lang')}
}`,
  unesco: `
SELECT ?s ?sFr ?desc ?country ?sl WHERE {
  ?s wdt:P1435 wd:Q9259; wdt:P17 ?country; wikibase:sitelinks ?sl FILTER(?sl >= 45)
  ${label('s')}
  OPTIONAL { ?s schema:description ?desc FILTER(lang(?desc) = "fr") }
}`,
  painters: people('Q1028181', 90),
  writers: people('Q36180', 130),
  composers: people('Q36834', 90),
  scientists: people('Q169470 Q593644 Q170790 Q864503 Q11063', 110),
  philosophers: people('Q4964182', 110),
  explorers: people('Q11900058', 60),
  battles: `
SELECT ?e ?eFr ?desc ?date ?start ?place ?placeFr ?sl WHERE {
  ?e wdt:P31 wd:Q178561; wikibase:sitelinks ?sl FILTER(?sl >= 40)
  ${label('e')}
  OPTIONAL { ?e schema:description ?desc FILTER(lang(?desc) = "fr") }
  OPTIONAL { ?e wdt:P585 ?date }
  OPTIONAL { ?e wdt:P580 ?start }
  OPTIONAL { ?e wdt:P276 ?place. ${label('place')} }
}`,
  treaties: `
SELECT ?e ?eFr ?date ?sl WHERE {
  ?e wdt:P31 wd:Q131569; wikibase:sitelinks ?sl FILTER(?sl >= 30)
  ${label('e')}
  ?e wdt:P585 ?date.
}`,
  elements: `
SELECT ?e ?eFr ?sym ?z ?sl WHERE {
  ?e wdt:P31 wd:Q11344; wdt:P246 ?sym; wdt:P1086 ?z; wikibase:sitelinks ?sl.
  ${label('e')}
}`,
  books: `
SELECT ?w ?wFr ?author ?authorFr ?authorDesc ?date ?sl WHERE {
  ?w wdt:P31 wd:Q7725634; wdt:P50 ?author; wikibase:sitelinks ?sl FILTER(?sl >= 45)
  ${label('w')} ?author rdfs:label ?authorFr FILTER(lang(?authorFr) = "fr")
  OPTIONAL { ?w wdt:P577 ?date }
  OPTIONAL { ?author schema:description ?authorDesc FILTER(lang(?authorDesc) = "fr") }
}`,
  paintings: `
SELECT ?w ?wFr ?author ?authorFr ?authorDesc ?date ?sl WHERE {
  ?w wdt:P31 wd:Q3305213; wdt:P170 ?author; wikibase:sitelinks ?sl FILTER(?sl >= 35)
  ${label('w')} ?author rdfs:label ?authorFr FILTER(lang(?authorFr) = "fr")
  OPTIONAL { ?w wdt:P571 ?date }
  OPTIONAL { ?author schema:description ?authorDesc FILTER(lang(?authorDesc) = "fr") }
}`,
  films: `
SELECT ?w ?wFr ?author ?authorFr ?authorDesc ?date ?sl WHERE {
  ?w wdt:P31 wd:Q11424; wdt:P57 ?author; wikibase:sitelinks ?sl FILTER(?sl >= 80)
  ${label('w')} ?author rdfs:label ?authorFr FILTER(lang(?authorFr) = "fr")
  OPTIONAL { ?w wdt:P577 ?date }
  OPTIONAL { ?author schema:description ?authorDesc FILTER(lang(?authorDesc) = "fr") }
}`,
};

// Node n'utilise pas le proxy HTTPS de l'environnement : on passe par curl.
function sparql(query) {
  const out = execFileSync('curl', [
    '-sS', '-m', '120', '-G', 'https://query.wikidata.org/sparql',
    '--data-urlencode', `query=${query}`,
    '-H', 'Accept: application/sparql-results+json',
    '-H', 'User-Agent: CultFive/0.1 (bonjour@cultfive.app)',
  ], { maxBuffer: 64 * 1024 * 1024 }).toString();
  const json = JSON.parse(out);
  // Aplatit : URI d'entité → QID, littéraux → valeur.
  return json.results.bindings.map((row) => Object.fromEntries(Object.entries(row).map(([k, v]) => [
    k, v.type === 'uri' && v.value.startsWith('http://www.wikidata.org/entity/') ? v.value.split('/').pop() : v.value,
  ])));
}

// Silhouettes : Natural Earth 1:110m (domaine public), simplifiées et normalisées (0…1) pour tenir dans une question.
function fetchShapes() {
  const raw = JSON.parse(execFileSync('curl', ['-sS', '-m', '120',
    'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson'],
    { maxBuffer: 64 * 1024 * 1024 }).toString());
  const shapes = {};
  for (const f of raw.features) {
    const iso = f.properties.ISO_A2_EH;
    if (!iso || iso === '-99') continue;
    const polys = f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
    // Anneaux extérieurs uniquement ; on garde les morceaux significatifs (≥ 8 % de l'aire du plus grand).
    const rings = polys.map((p) => p[0]);
    const area = (r) => Math.abs(r.reduce((a, [x1, y1], i) => { const [x2, y2] = r[(i + 1) % r.length]; return a + x1 * y2 - x2 * y1; }, 0) / 2);
    const biggest = Math.max(...rings.map(area));
    const main = rings.find((r) => area(r) === biggest);
    const bbox = (r) => [Math.min(...r.map(([x]) => x)), Math.min(...r.map(([, y]) => y)), Math.max(...r.map(([x]) => x)), Math.max(...r.map(([, y]) => y))];
    const [mx1, my1, mx2, my2] = bbox(main);
    // Morceaux significatifs ET proches du territoire principal (pas de Guyane pour la France, pas d'Alaska pour les États-Unis).
    const kept = rings.filter((r) => {
      if (area(r) < biggest * 0.08) return false;
      const [x1, y1, x2, y2] = bbox(r);
      return x1 < mx2 + 3 && x2 > mx1 - 3 && y1 < my2 + 3 && y2 > my1 - 3;
    });
    // Pas de coupe par l'antiméridien (Russie, Fidji…) : on ignore ces pays.
    const lons = kept.flat().map(([x]) => x);
    if (Math.max(...lons) - Math.min(...lons) > 180) continue;
    const midLat = kept.flat().reduce((a, [, y]) => a + y, 0) / kept.flat().length;
    const k = Math.cos((midLat * Math.PI) / 180);
    const proj = kept.map((r) => r.map(([x, y]) => [x * k, -y]));
    const xs = proj.flat().map(([x]) => x), ys = proj.flat().map(([, y]) => y);
    const [minX, minY] = [Math.min(...xs), Math.min(...ys)];
    const size = Math.max(Math.max(...xs) - minX, Math.max(...ys) - minY) || 1;
    shapes[iso] = {
      area: biggest,
      paths: proj.map((r) => r.map(([x, y]) => [Math.round(((x - minX) / size) * 1000) / 1000, Math.round(((y - minY) / size) * 1000) / 1000])),
    };
  }
  writeFileSync(join(cacheDir, 'shapes.json'), JSON.stringify({ fetched: new Date().toISOString().slice(0, 10), source: 'Natural Earth 1:110m (domaine public)', shapes }));
  console.log(`✓ shapes : ${Object.keys(shapes).length} pays`);
}

const names = process.argv.slice(2).length ? process.argv.slice(2) : [...Object.keys(QUERIES), 'shapes'];
for (const name of names) {
  if (name === 'shapes') { fetchShapes(); continue; }
  const rows = sparql(QUERIES[name]);
  writeFileSync(join(cacheDir, `${name}.json`), JSON.stringify({ fetched: new Date().toISOString().slice(0, 10), rows }, null, 0));
  console.log(`✓ ${name} : ${rows.length} lignes`);
}
