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
SELECT ?city ?cityFr ?cityEn ?country ?pop ?sl WHERE {
  ?city wdt:P31 wd:Q1549591; wdt:P17 ?country; wdt:P1082 ?pop; wikibase:sitelinks ?sl
  FILTER(?sl >= 100 && ?pop >= 1000000)
  ${label('city')} ?city rdfs:label ?cityEn FILTER(lang(?cityEn) = "en")
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

const names = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(QUERIES);
for (const name of names) {
  const rows = sparql(QUERIES[name]);
  writeFileSync(join(cacheDir, `${name}.json`), JSON.stringify({ fetched: new Date().toISOString().slice(0, 10), rows }, null, 0));
  console.log(`✓ ${name} : ${rows.length} lignes`);
}
