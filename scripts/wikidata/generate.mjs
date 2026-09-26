#!/usr/bin/env node
// Génère des questions à partir du cache Wikidata (CC0) → content/questions/wd_*.json.
// Déterministe (graine = identifiant de la question). Relecture humaine : scripts/wikidata/rejects.json liste les clés écartées.
// Usage : node scripts/wikidata/generate.mjs
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { countryForms, partitiveOf, centuryLabel, frenchDate, yearOf, roundedPopulation, slug, DISPLAY, EXCLUDED_COUNTRIES } from './french.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const load = (name) => JSON.parse(readFileSync(join(here, 'cache', `${name}.json`), 'utf8'));
const rejects = new Set(JSON.parse(readFileSync(join(here, 'rejects.json'), 'utf8')));

// ─────────────── Aléatoire déterministe
function rng(seed) {
  let h = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) { h = Math.imul(h ^ seed.charCodeAt(i), 3432918353); h = (h << 13) | (h >>> 19); }
  return () => {
    h = Math.imul(h ^ (h >>> 16), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909);
    return ((h ^= h >>> 16) >>> 0) / 4294967296;
  };
}
const shuffle = (arr, rand) => arr.map((v) => [rand(), v]).sort((a, b) => a[0] - b[0]).map((x) => x[1]);
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const areaText = (a) => (a >= 1e6 ? `${(a / 1e6).toFixed(1).replace('.', ',').replace(',0', '')} million${a >= 2e6 ? 's' : ''} de km²`
  : `${(a >= 10000 ? Math.round(a / 1000) * 1000 : Math.round(a / 10) * 10).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')} km²`);
const deName = (name) => (/^[AEIOUÉÈÊÎÔHaeiouéèêîôh]/.test(name) ? `d'${name}` : `de ${name}`);
const habitants = (n) => (n >= 1e6 ? `${roundedPopulation(n)} d'habitants` : `${roundedPopulation(n)} habitants`);
// Auteurs qui ne sont pas des auteurs au sens littéraire (textes religieux, attributions traditionnelles).
const NOT_AUTHORS = new Set(['Jésus-Christ', 'Dieu', 'Moïse', 'Mahomet', 'Homère', 'Vyāsa', 'Vyasa', 'Valmiki']);
/** Description sans parenthèse finale (dates redondantes). */
const cleanDesc = (d) => (d ?? '').replace(/\s*\([^()]*\)\s*$/, '').trim();
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
/** Période historique (thèmes de l'Histoire) : Antiquité < 476, Moyen Âge < 1492, Temps modernes < 1789, puis époque contemporaine. */
const eraOf = (year) => (year < 476 ? 'antiquity' : year < 1492 ? 'middle_ages' : year < 1789 ? 'modern' : 'contemporary');

// ─────────────── Déduplication avec la banque curée (même énoncé ou même titre cité)
const curatedText = readdirSync(join(root, 'content/questions'))
  .filter((f) => f.endsWith('.json') && !f.startsWith('wd_'))
  .flatMap((f) => JSON.parse(readFileSync(join(root, 'content/questions', f), 'utf8')))
  .map((q) => `${q.prompt} ${(q.options ?? []).join(' ')}`.toLowerCase());
const alreadyCovered = (needle) => curatedText.some((t) => t.includes(needle.toLowerCase()));

const out = { geography: [], history: [], science: [], arts: [], cinema: [], music: [], sport: [], tech: [] };
const stats = {};
// Famille = « même moule » de question. Le serveur évite d'en enchaîner deux de la même famille.
const FAMILY = {
  'capitale': 'capital', 'capitale inverse': 'capital', 'drapeau': 'flag', 'continent': 'continent', 'ville': 'city',
  'classement population': 'country_ranking', 'classement superficie': 'country_ranking', 'siècle de naissance': 'person_era',
  'classement naissances': 'person_era', 'bataille': 'battle', 'symbole chimique': 'element', 'élément du symbole': 'element',
  'livre auteur': 'book', 'tableau peintre': 'painting', 'film réalisateur': 'film', 'carte': 'map', 'monnaie': 'currency',
  'langue': 'language', 'unesco': 'monument', 'silhouette': 'shape',
  'famille instrument': 'instrument', 'groupe pays': 'band', 'groupe décennie': 'band',
  'coupe du monde vainqueur': 'world_cup', 'coupe du monde hôte': 'world_cup', 'jo ville': 'olympics',
  'invention inventeur': 'invention', 'inventeur invention': 'invention',
  'lune planète': 'moon', 'plus haut sommet': 'peak', 'film décennie': 'film_year', 'film acteur': 'film_cast',
};
/** Plusieurs formulations pour un même modèle, choisies de façon stable. */
const vary = (seed, variants) => variants[Math.floor(rng(`vary-${seed}`)() * variants.length)];

function add(bucket, template, q) {
  q.family = FAMILY[template];
  if (rejects.has(q.key)) { stats[`${template} (rejetées)`] = (stats[`${template} (rejetées)`] ?? 0) + 1; return; }
  q.source = 'Wikidata';
  q.origin = 'import';
  out[bucket].push(q);
  stats[template] = (stats[template] ?? 0) + 1;
}

// ─────────────── Pays
const countryRows = load('countries');
const fetchedOn = countryRows.fetched;
const countries = new Map();
for (const r of countryRows.rows) {
  const name = DISPLAY.get(r.cFr) ?? r.cFr;
  if (EXCLUDED_COUNTRIES.has(name)) continue;
  const c = countries.get(r.c) ?? { id: r.c, name, en: r.cEn, iso: r.iso, caps: new Map(), conts: new Set(), pop: 0, area: 0, sl: Number(r.sl) };
  if (r.cap && r.capFr) c.caps.set(r.cap, r.capFr);
  if (r.contFr) c.conts.add(r.contFr);
  c.pop = Math.max(c.pop, Number(r.pop ?? 0));
  c.area = Math.max(c.area, Number(r.area ?? 0));
  countries.set(r.c, c);
}
const countryList = [...countries.values()].filter((c) => c.pop > 0);
const continentOf = (c) => (c.conts.size === 1 ? [...c.conts][0] : null);
const CONT_OFFSET = { Europe: -8, 'Amérique du Nord': -4, 'Amérique du Sud': 0, Asie: 3, Afrique: 8, Océanie: 6 };
const CONTESTED_CAPITAL = new Set(['Israël', 'Guinée équatoriale', 'Nauru']);
// Continent discutable (pays transcontinentaux ou classement contre-intuitif).
const AMBIGUOUS_CONTINENT = new Set(['Chypre', 'Turquie', 'Russie', 'Arménie', 'Géorgie', 'Azerbaïdjan', 'Kazakhstan', 'Égypte', 'Indonésie', 'Papouasie-Nouvelle-Guinée', 'Timor oriental']);
const countryFame = (c) => 88 - 7 * Math.log10(Math.max(c.pop, 1000)) + (CONT_OFFSET[continentOf(c)] ?? 4);

const cities = load('cities').rows.map((r) => ({ id: r.city, name: r.cityFr, en: r.cityEn, country: r.country, pop: Number(r.pop), sl: Number(r.sl) }));
const citiesByCountry = new Map();
for (const city of cities) {
  if (!citiesByCountry.has(city.country) || citiesByCountry.get(city.country).every((c) => c.id !== city.id)) {
    citiesByCountry.set(city.country, [...(citiesByCountry.get(city.country) ?? []), city]);
  }
}

const sameContinent = (c) => countryList.filter((o) => o.id !== c.id && continentOf(o) && continentOf(o) === continentOf(c));
const nearestByFame = (c, pool, n, rand) =>
  shuffle(pool, rand).sort((a, b) => Math.abs(countryFame(a) - countryFame(c)) - Math.abs(countryFame(b) - countryFame(c))).slice(0, n);

for (const c of countryList) {
  const f = countryForms(c.name);
  const cont = continentOf(c);
  const key = slug(c.en);
  const fame = countryFame(c);
  const neighbours = cont ? sameContinent(c).filter((o) => o.caps.size === 1 && !CONTESTED_CAPITAL.has(o.name)) : [];

  // Capitale (un seul chef-lieu, sinon ambigu ; statuts contestés exclus)
  if (c.caps.size === 1 && neighbours.length >= 3 && !CONTESTED_CAPITAL.has(c.name)) {
    const [capId, capName] = [...c.caps.entries()][0];
    const rand = rng(`cap-${c.id}`);
    const others = nearestByFame(c, neighbours, 3, rand).map((o) => [...o.caps.values()][0]);
    const capCity = cities.find((x) => x.id === capId);
    const bigger = (citiesByCountry.get(c.id) ?? []).filter((x) => x.id !== capId && capCity && x.pop > capCity.pop * 1.1)
      .sort((a, b) => b.pop - a.pop)[0];
    const trap = bigger ? ` Ce n'est pas la plus grande ville du pays : ${bigger.name} est plus peuplée.` : '';
    const difficulty = Math.round(clamp(fame + (bigger ? 8 : 0), 18, 80));
    const sameName = capName.toLowerCase().includes(c.name.toLowerCase().split(' ')[0]) || c.name.toLowerCase().includes(capName.toLowerCase());
    if (!sameName && !new Set(others).has(capName) && new Set(others).size === 3) {
      add('geography', 'capitale', {
        key: `wd-cap-${c.id}`, concept: `geography.capitals.${key}`, label: `Capitale ${f.of}`, type: 'mcq', difficulty,
        prompt: vary(c.id, [`Quelle est la capitale ${f.of} ?`, `Quelle ville est la capitale ${f.of} ?`, `${cap(f.the)} a pour capitale…`]),
        options: [`${capName}*`, ...others],
        explanation: `${capName} est la capitale ${f.of}${cont ? `, en ${cont}` : ''}. Le pays compte environ ${habitants(c.pop)}.${trap}`,
        fact_as_of: fetchedOn,
      });
      if (c.pop >= 3e6) {
        const otherCountries = nearestByFame(c, neighbours, 3, rng(`capr-${c.id}`)).map((o) => o.name);
        add('geography', 'capitale inverse', {
          key: `wd-capr-${c.id}`, concept: `geography.capitals.${key}`, label: `Capitale ${f.of}`, type: 'mcq',
          difficulty: Math.round(clamp(difficulty - 4, 15, 80)),
          prompt: `De quel pays ${capName} est-elle la capitale ?`, options: [`${c.name}*`, ...otherCountries],
          explanation: `${capName} est la capitale ${f.of}.${trap}`,
        });
      }
    }
  }

  // Drapeau (émoji à partir du code ISO)
  if (cont && neighbours.length >= 3 && /^[A-Z]{2}$/.test(c.iso)) {
    const emoji = String.fromCodePoint(...[...c.iso].map((ch) => 0x1f1e6 + ch.charCodeAt(0) - 65));
    const rand = rng(`flag-${c.id}`);
    const others = nearestByFame(c, sameContinent(c), 3, rand).map((o) => o.name);
    const capName = c.caps.size === 1 ? [...c.caps.values()][0] : null;
    add('geography', 'drapeau', {
      key: `wd-flag-${c.id}`, concept: `geography.flags.${key}`, label: `Drapeau ${f.of}`, type: 'mcq',
      difficulty: Math.round(clamp(fame + 6, 18, 85)),
      prompt: vary(`flag-${c.id}`, [`À quel pays appartient ce drapeau ? ${emoji}`, `Ce drapeau est celui de quel pays ? ${emoji}`, `${emoji} Quel pays ce drapeau représente-t-il ?`]),
      options: [`${c.name}*`, ...others],
      explanation: `C'est le drapeau ${f.of}${capName ? `, dont la capitale est ${capName}` : ''} (${cont}).`,
    });
  }

  // Continent (seulement pour les pays qui ne sont pas évidents)
  if (cont && CONT_OFFSET[cont] !== undefined && fame >= 30 && cont !== 'Amérique du Nord' && !AMBIGUOUS_CONTINENT.has(c.name)) {
    const all = ['Afrique', 'Asie', 'Europe', 'Amérique du Sud', 'Océanie'].filter((x) => x !== cont);
    const rand = rng(`cont-${c.id}`);
    const verb = f.gender === 'p' ? 'se trouvent' : 'se trouve';
    add('geography', 'continent', {
      key: `wd-cont-${c.id}`, concept: `geography.countries.continent_${key}`, label: `Continent ${f.of}`, type: 'mcq',
      difficulty: Math.round(clamp(fame - 6, 18, 75)),
      prompt: `Sur quel continent ${verb} ${f.the} ?`, options: [`${cont}*`, ...shuffle(all, rand).slice(0, 3)],
      explanation: `${cap(f.the)} ${verb} en ${cont === 'Océanie' ? 'Océanie' : cont}${c.caps.size === 1 ? ` ; ${[...c.caps.values()][0]} en est la capitale` : ''}.`,
    });
  }
}

// Grandes villes (hors capitales) → pays
const capitalIds = new Set(countryList.flatMap((c) => [...c.caps.keys()]));
for (const city of cities) {
  const country = countries.get(city.country);
  if (!country || capitalIds.has(city.id) || !continentOf(country)) continue;
  if (cities.filter((x) => x.name === city.name).length > 1) continue;
  const pool = sameContinent(country);
  if (pool.length < 3) continue;
  const f = countryForms(country.name);
  const rand = rng(`city-${city.id}`);
  const others = nearestByFame(country, pool, 3, rand).map((o) => o.name);
  const de = /^[AEIOUÉÈÎaeiouéèî]/.test(city.name) ? `d'${city.name}` : `de ${city.name}`;
  add('geography', 'ville', {
    key: `wd-city-${city.id}`, concept: `geography.countries.city_${slug(city.en)}`, label: `Pays de ${city.name}`, type: 'mcq',
    difficulty: Math.round(clamp(100 - 12 * Math.log(city.sl) + (CONT_OFFSET[continentOf(country)] ?? 0) / 2, 22, 78)),
    prompt: vary(city.id, [`Dans quel pays se trouve la ville ${de} ?`, `La ville ${de} se trouve dans quel pays ?`, `${city.name} : dans quel pays ?`]),
    options: [`${country.name}*`, ...others],
    explanation: `${city.name} se trouve ${f.in}. La ville compte environ ${roundedPopulation(city.pop)} d'habitants (hors agglomération).`,
    fact_as_of: fetchedOn,
  });
}

// Classements : population et superficie (écarts nets pour rester vrais malgré les mises à jour)
function orderingSets(metric, minRatio, count, seed) {
  const sets = [];
  const pool = countryList.filter((c) => c[metric] > 0 && countryFame(c) < 45);
  const rand = rng(seed);
  for (let attempt = 0; attempt < 4000 && sets.length < count; attempt++) {
    const pick = shuffle(pool, rand).slice(0, 4).sort((a, b) => b[metric] - a[metric]);
    if (pick.every((c, i) => i === 0 || pick[i - 1][metric] / c[metric] >= minRatio)
        && !sets.some((s) => s.some((c) => pick.includes(c)))) {
      sets.push(pick);
    }
  }
  return sets;
}
orderingSets('pop', 1.6, 14, 'pop').forEach((set, i) => add('geography', 'classement population', {
  key: `wd-popord-${set.map((c) => c.id).join('-')}`, concept: `geography.countries.population_set_${i + 1}`,
  label: `Population : ${set.map((c) => c.name).join(', ')}`, type: 'ordering', difficulty: 58,
  prompt: 'Classe ces pays du plus peuplé au moins peuplé.', items: set.map((c) => c.name),
  explanation: `Populations approximatives : ${set.map((c) => `${c.name} ≈ ${roundedPopulation(c.pop)}`).join(' ; ')}.`,
  fact_as_of: fetchedOn,
}));
orderingSets('area', 1.6, 12, 'area').forEach((set, i) => add('geography', 'classement superficie', {
  key: `wd-areaord-${set.map((c) => c.id).join('-')}`, concept: `geography.countries.area_set_${i + 1}`,
  label: `Superficie : ${set.map((c) => c.name).join(', ')}`, type: 'ordering', difficulty: 60,
  prompt: 'Classe ces pays du plus grand au plus petit (superficie).', items: set.map((c) => c.name),
  explanation: `Superficies approximatives : ${set.map((c) => `${c.name} ≈ ${areaText(c.area)}`).join(' ; ')}.`,
}));

// ─────────────── Personnalités : siècle de naissance, classements chronologiques
const peopleFiles = ['painters', 'writers', 'composers', 'scientists', 'philosophers', 'explorers'];
const people = new Map();
for (const file of peopleFiles) {
  for (const r of load(file).rows) {
    const birth = yearOf(r.birth);
    if (!birth || birth < 1000 || birth > 1950 || /^Q\d+$/.test(r.pFr)) continue;
    const prev = people.get(r.p);
    people.set(r.p, { id: r.p, name: r.pFr, desc: r.desc, birth, death: yearOf(r.death), female: r.sex === 'Q6581072', sl: Number(r.sl) });
    if (prev && prev.birth !== birth) people.delete(r.p);  // dates contradictoires : on écarte
  }
}
const peopleList = [...people.values()].filter((p) => !alreadyCovered(p.name));
for (const p of peopleList) {
  const c = Math.floor((p.birth - 1) / 100) + 1;
  const rand = rng(`cent-${p.id}`);
  const candidates = [c - 2, c - 1, c + 1, c + 2].filter((x) => x >= 11 && x <= 20);
  const others = shuffle(candidates, rand).slice(0, 3).sort((a, b) => a - b);
  if (others.length < 3) continue;
  const options = [...others, c].sort((a, b) => a - b).map((x) => `${centuryLabel(x * 100)}${x === c ? '*' : ''}`);
  const ne = p.female ? 'née' : 'né';
  const mort = p.female ? 'morte' : 'mort';
  add('history', 'siècle de naissance', {
    key: `wd-cent-${p.id}`, concept: `history.${eraOf(p.birth)}.century_${slug(p.name)}`, label: `Époque de ${p.name}`, type: 'mcq',
    keep_order: true, difficulty: Math.round(clamp(100 - 12 * Math.log(p.sl) + 6, 25, 80)),
    prompt: vary(p.id, [`En quel siècle est ${ne} ${p.name} ?`, `${p.name} est ${ne} au…`, `À quel siècle remonte la naissance ${deName(p.name)} ?`]),
    options,
    explanation: `${p.name}${p.desc ? `, ${p.desc.replace(/\s*\(.*\)$/, '')},` : ''} est ${ne} en ${p.birth}${p.death ? ` et ${mort} en ${p.death}` : ''}.`,
  });
}
{
  const rand = rng('births');
  const pool = peopleList.filter((p) => p.sl >= 120);
  const used = new Set();
  let n = 0;
  for (let attempt = 0; attempt < 5000 && n < 16; attempt++) {
    const pick = shuffle(pool.filter((p) => !used.has(p.id)), rand).slice(0, 4).sort((a, b) => a.birth - b.birth);
    if (pick.length < 4 || !pick.every((p, i) => i === 0 || p.birth - pick[i - 1].birth >= 40)) continue;
    pick.forEach((p) => used.add(p.id));
    n++;
    add('history', 'classement naissances', {
      key: `wd-births-${pick.map((p) => p.id).join('-')}`, concept: `history.${eraOf(pick[1].birth)}.births_set_${n}`,
      label: `Naissances : ${pick.map((p) => p.name).join(', ')}`, type: 'ordering', difficulty: 55,
      prompt: 'Classe ces personnalités de la plus ancienne à la plus récente (année de naissance).',
      items: pick.map((p) => p.name),
      explanation: `${pick.map((p) => `${p.name} (${p.birth})`).join(', ')}.`,
    });
  }
}

// ─────────────── Batailles : année
{
  const rows = load('battles').rows;
  const byLabel = new Map();
  for (const r of rows) byLabel.set(r.eFr, new Set([...(byLabel.get(r.eFr) ?? []), r.e]));
  const seen = new Set();
  for (const r of rows) {
    const label = r.eFr;
    const iso = r.date ?? r.start;
    const year = yearOf(iso);
    if (seen.has(r.e) || !label.startsWith('bataille ') || label.includes('(') || byLabel.get(label).size > 1 || !year || year < 1000 || year > 1945) continue;
    if (alreadyCovered(label.replace('bataille ', ''))) continue;
    seen.add(r.e);
    const rand = rng(`battle-${r.e}`);
    const offsets = shuffle([-40, -25, -15, -9, -5, -3, 3, 5, 9, 15, 25, 40], rand);
    const years = [];
    for (const o of offsets) if (years.length < 3 && year + o <= 2020 && years.every((y) => Math.abs(y - (year + o)) >= 3)) years.push(year + o);
    const options = [...years, year].sort((a, b) => a - b).map((y) => `${y}${y === year ? '*' : ''}`);
    const date = frenchDate(iso);
    add('history', 'bataille', {
      key: `wd-battle-${r.e}`, concept: `history.${eraOf(year)}.${slug(label)}`, label: cap(label), type: 'mcq', keep_order: true,
      difficulty: Math.round(clamp(100 - 12 * Math.log(Number(r.sl)) + 10, 35, 85)),
      prompt: vary(r.e, [`En quelle année a eu lieu la ${label} ?`, `La ${label} s'est déroulée en…`, `Quand a eu lieu la ${label} ?`]),
      options,
      explanation: `La ${label} a eu lieu ${/^\d+$/.test(date) ? `en ${date}` : `le ${date}`}.`
        + (r.desc && !cleanDesc(r.desc).toLowerCase().startsWith(label.toLowerCase()) && cleanDesc(r.desc).length < 140 ? ` Contexte : ${cleanDesc(r.desc)}.` : ''),
    });
  }
}

// ─────────────── Éléments chimiques : symbole
{
  const LATIN = { Fe: 'ferrum', Na: 'natrium', K: 'kalium', Cu: 'cuprum', Ag: 'argentum', Sn: 'stannum', Hg: 'hydrargyrum', Pb: 'plumbum', W: 'wolfram', Sb: 'stibium' };
  const COMMON = ['H', 'He', 'Li', 'C', 'N', 'O', 'F', 'Ne', 'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca', 'Ti', 'Cr', 'Mn',
    'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Br', 'Ag', 'Sn', 'Sb', 'I', 'W', 'Pt', 'Hg', 'Pb', 'Ra', 'U'];
  const elements = new Map();
  for (const r of load('elements').rows) if (COMMON.includes(r.sym)) elements.set(r.sym, { sym: r.sym, name: r.eFr, z: Number(r.z) });
  const list = [...elements.values()];
  for (const e of list) {
    const rand = rng(`elem-${e.sym}`);
    const similar = list.filter((o) => o.sym !== e.sym).sort((a, b) =>
      (b.sym[0] === e.sym[0]) - (a.sym[0] === e.sym[0]) || (b.name[0] === e.name[0]) - (a.name[0] === e.name[0]) || rand() - 0.5);
    const latin = LATIN[e.sym] ? ` Il vient du latin ${LATIN[e.sym]}.` : '';
    const difficulty = LATIN[e.sym] ? 55 : e.z <= 20 ? 35 : 48;
    add('science', 'symbole chimique', {
      key: `wd-elem-${e.sym}`, concept: `science.chemistry.symbol_${e.sym.toLowerCase()}`, label: `Symbole ${partitiveOf(e.name)}`,
      type: 'mcq', difficulty,
      prompt: `Quel est le symbole chimique ${partitiveOf(e.name)} ?`, options: [`${e.sym}*`, ...similar.slice(0, 3).map((o) => o.sym)],
      explanation: `Le symbole ${partitiveOf(e.name)} est ${e.sym}, et son numéro atomique est ${e.z}.${latin}`,
    });
    add('science', 'élément du symbole', {
      key: `wd-elemr-${e.sym}`, concept: `science.chemistry.symbol_${e.sym.toLowerCase()}`, label: `Symbole ${partitiveOf(e.name)}`,
      type: 'mcq', difficulty: Math.max(difficulty - 5, 25),
      prompt: `Quel élément chimique a pour symbole ${e.sym} ?`, options: [`${cap(e.name)}*`, ...similar.slice(0, 3).map((o) => cap(o.name))],
      explanation: `${e.sym} est le symbole ${partitiveOf(e.name)} (numéro atomique ${e.z}).${latin}`,
    });
  }
}

// ─────────────── Œuvres : livres, tableaux, films → auteur
function works(file, bucket, template, conceptPrefix, promptOf, explain, extraDifficulty) {
  const rows = load(file).rows;
  const authorsOf = new Map();
  const labelCount = new Map();
  for (const r of rows) {
    authorsOf.set(r.w, new Set([...(authorsOf.get(r.w) ?? []), r.author]));
    labelCount.set(r.wFr, new Set([...(labelCount.get(r.wFr) ?? []), r.w]));
  }
  const items = new Map();
  for (const r of rows) {
    if (authorsOf.get(r.w).size !== 1 || labelCount.get(r.wFr).size !== 1 || /^Q\d+$/.test(r.wFr) || /^Q\d+$/.test(r.authorFr)) continue;
    const year = yearOf(r.date);
    const prev = items.get(r.w);
    if (!prev || (year && (!prev.year || year < prev.year))) {
      items.set(r.w, { id: r.w, title: r.wFr, author: r.authorFr, authorId: r.author, year, sl: Number(r.sl),
        authorDesc: r.authorDesc && cleanDesc(r.authorDesc).length <= 60 ? cleanDesc(r.authorDesc) : null });
    }
  }
  const list = [...items.values()].filter((w) => !alreadyCovered(w.title));
  for (const w of list) {
    if (w.title.toLowerCase().includes(w.author.toLowerCase()) || NOT_AUTHORS.has(w.author)) continue;
    const rand = rng(`${template}-${w.id}`);
    const pool = [...new Map([...items.values()].filter((o) => o.authorId !== w.authorId).map((o) => [o.authorId, o])).values()];
    const close = shuffle(pool, rand).sort((a, b) => Math.abs((a.year ?? 1900) - (w.year ?? 1900)) - Math.abs((b.year ?? 1900) - (w.year ?? 1900)));
    const others = [...new Set(close.map((o) => o.author))].slice(0, 3);
    if (others.length < 3) continue;
    add(bucket, template, {
      key: `wd-${template.split(' ')[0]}-${w.id}`, concept: `${conceptPrefix}_${slug(w.title).slice(0, 30)}_${w.id.toLowerCase()}`, label: `Auteur de « ${w.title} »`,
      type: 'mcq', difficulty: Math.round(clamp(100 - 12 * Math.log(w.sl) + extraDifficulty, 22, 82)),
      prompt: promptOf(w), options: [`${w.author}*`, ...others], explanation: explain(w),
    });
  }
}
works('books', 'arts', 'livre auteur', 'arts.literature.book',
  (w) => vary(w.id, [`Qui a écrit « ${w.title} » ?`, `« ${w.title} » est une œuvre de…`, `Quel auteur a signé « ${w.title} » ?`]),
  (w) => `« ${w.title} » est une œuvre ${deName(w.author)}${w.authorDesc ? ` (${w.authorDesc})` : ''}${w.year ? `, parue en ${w.year}` : ''}.`, 8);
works('paintings', 'arts', 'tableau peintre', 'arts.painting.work',
  (w) => vary(w.id, [`Qui a peint « ${w.title} » ?`, `« ${w.title} » est un tableau de…`, `De quel peintre est « ${w.title} » ?`]),
  (w) => `« ${w.title} » a été peint par ${w.author}${w.authorDesc ? ` (${w.authorDesc})` : ''}${w.year ? ` vers ${w.year}` : ''}.`, 4);
works('films', 'cinema', 'film réalisateur', 'cinema.directors.film',
  (w) => vary(w.id, [`Qui a réalisé le film « ${w.title} »${w.year ? ` (${w.year})` : ''} ?`,
    `« ${w.title} »${w.year ? ` (${w.year})` : ''} est un film de…`]),
  (w) => `« ${w.title} » a été réalisé par ${w.author}${w.authorDesc ? ` (${w.authorDesc})` : ''}${w.year ? ` et est sorti en ${w.year}` : ''}.`, 2);


// ─────────────── Carte : localiser une capitale parmi 4 points
{
  const coords = new Map();
  for (const r of load('capitalsGeo').rows) {
    const m = /Point\(([-\d.]+) ([-\d.]+)\)/.exec(r.coord);
    if (m) coords.set(r.cap, { lon: Number(m[1]), lat: Number(m[2]) });
  }
  const located = countryList.filter((c) => c.caps.size === 1 && !CONTESTED_CAPITAL.has(c.name) && continentOf(c)
    && !AMBIGUOUS_CONTINENT.has(c.name) && coords.has([...c.caps.keys()][0]));
  const pos = (c) => coords.get([...c.caps.keys()][0]);
  const dist = (a, b) => Math.hypot(a.lat - b.lat, (a.lon - b.lon) * Math.cos((a.lat * Math.PI) / 180));
  for (const c of located) {
    const here = pos(c);
    const rand = rng(`map-${c.id}`);
    // 3 autres capitales du continent, assez proches pour tenir sur une carte, assez loin pour être distinctes.
    const pool = shuffle(located.filter((o) => o !== c && continentOf(o) === continentOf(c)), rand)
      .filter((o) => dist(pos(o), here) > 3 && dist(pos(o), here) < 22);
    const chosen = [];
    for (const o of pool) if (chosen.length < 3 && chosen.every((x) => dist(pos(x), pos(o)) > 3)) chosen.push(o);
    if (chosen.length < 3) continue;
    const pts = [c, ...chosen].map(pos);
    const lat = (Math.min(...pts.map((p) => p.lat)) + Math.max(...pts.map((p) => p.lat))) / 2;
    const lon = (Math.min(...pts.map((p) => p.lon)) + Math.max(...pts.map((p) => p.lon))) / 2;
    const span = Math.max(Math.max(...pts.map((p) => p.lat)) - Math.min(...pts.map((p) => p.lat)),
      (Math.max(...pts.map((p) => p.lon)) - Math.min(...pts.map((p) => p.lon))) * 0.8) * 1.5 + 4;
    const capName = [...c.caps.values()][0];
    const f = countryForms(c.name);
    const others = chosen.map((o) => [...o.caps.values()][0]);
    add('geography', 'carte', {
      key: `wd-map-${c.id}`, concept: `geography.countries.map_${slug(c.en)}`, label: `Situer ${capName}`, type: 'map_pick',
      difficulty: Math.round(clamp(countryFame(c) + 6, 25, 85)),
      prompt: vary(`map-${c.id}`, [`Touche l'emplacement de ${capName}.`, `Où se trouve ${capName} ? Touche le bon point.`]),
      region: { lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100, span: Math.round(span * 10) / 10 },
      pins: [{ lat: here.lat, lon: here.lon, correct: true }, ...chosen.map((o) => ({ lat: pos(o).lat, lon: pos(o).lon }))],
      explanation: `${capName} est la capitale ${f.of}. Les autres points : ${others.slice(0, 2).join(', ')} et ${others[2]}.`,
    });
  }
}

// ─────────────── Monnaie et langue officielle (pays à une seule valeur, sinon ambigu)
{
  const cleanLabel = (l) => l.replace(/\s*\([^)]*\)\s*/g, ' ').trim();
  const single = (rows, key, labelKey) => {
    const m = new Map();
    for (const r of rows) m.set(r.c, new Map([...(m.get(r.c) ?? []), [r[key], cleanLabel(r[labelKey])]]));
    return new Map([...m].filter(([, v]) => v.size === 1).map(([k, v]) => [k, [...v.values()][0]]));
  };
  const currency = single(load('currencies').rows, 'cur', 'curFr');
  const language = single(load('languages').rows, 'lang', 'langFr');
  for (const c of countryList) {
    const f = countryForms(c.name);
    const fame = countryFame(c);
    const cont = continentOf(c);
    const cur = currency.get(c.id);
    if (cur && !/^Q\d+$/.test(cur)) {
      const rand = rng(`cur-${c.id}`);
      const pool = [...new Set([...currency.entries()].filter(([id, v]) => id !== c.id && v !== cur
        && !(v.startsWith('franc CFA') && cur.startsWith('franc CFA')) && !/^Q\d+$/.test(v)).map(([, v]) => v))];
      const near = [...new Set(countryList.filter((o) => o.id !== c.id && continentOf(o) === cont && currency.get(o.id)
        && currency.get(o.id) !== cur).map((o) => currency.get(o.id)))];
      const others = [...new Set([...shuffle(near, rand), ...shuffle(pool, rand)])].slice(0, 3);
      const euro = cur === 'euro';
      if (others.length === 3 && (fame >= 22 || !euro)) {
        add('geography', 'monnaie', {
          key: `wd-cur-${c.id}`, concept: `geography.countries.currency_${slug(c.en)}`, label: `Monnaie ${f.of}`, type: 'mcq',
          difficulty: Math.round(clamp(fame + (euro ? -4 : 8), 20, 85)),
          prompt: vary(`cur-${c.id}`, [`Quelle est la monnaie ${f.of} ?`, `Avec quelle monnaie paie-t-on ${f.in} ?`]),
          options: [`${cap(cur)}*`, ...others.map(cap)],
          explanation: `${cap(f.in)}, on paie en ${cur}.${euro ? ' Le pays fait partie de la zone euro.' : ''}`,
          fact_as_of: fetchedOn,
        });
      }
    }
    const lang = language.get(c.id);
    if (lang && !/^Q\d+$/.test(lang) && !/signes/.test(lang) && fame >= 25) {
      const rand = rng(`lang-${c.id}`);
      const near = countryList.filter((o) => o.id !== c.id && continentOf(o) === cont).map((o) => language.get(o.id))
        .filter((v) => v && v !== lang && !/^Q\d+$/.test(v) && !/signes/.test(v));
      const pool = [...language.values()].filter((v) => v !== lang && !/^Q\d+$/.test(v) && !/signes/.test(v));
      const CLOSE = { indonésien: 'malais', malais: 'indonésien', serbe: 'croate', croate: 'serbe', bosnien: 'serbe' };
      const others = [...new Set([...shuffle(near, rand), ...shuffle(pool, rand)])].filter((v) => v !== CLOSE[lang]).slice(0, 3);
      const art = /^[aeiouéh]/i.test(lang) ? `l'${lang}` : `le ${lang}`;
      if (others.length === 3) {
        add('geography', 'langue', {
          key: `wd-lang-${c.id}`, concept: `geography.countries.language_${slug(c.en)}`, label: `Langue ${f.of}`, type: 'mcq',
          difficulty: Math.round(clamp(fame + 6, 20, 85)),
          prompt: vary(`lang-${c.id}`, [`Quelle est la langue officielle ${f.of} ?`, `Quelle langue est officielle ${f.in} ?`]),
          options: [`${cap(lang)}*`, ...others.map(cap)],
          explanation: `La langue officielle ${f.of} est ${art}.`,
        });
      }
    }
  }
}

// ─────────────── Patrimoine mondial de l'UNESCO → pays
{
  const rows = load('unesco').rows;
  const countriesOf = new Map();
  for (const r of rows) countriesOf.set(r.s, new Set([...(countriesOf.get(r.s) ?? []), r.country]));
  const labelCount = new Map();
  for (const r of rows) labelCount.set(r.sFr, new Set([...(labelCount.get(r.sFr) ?? []), r.s]));
  const seen = new Set();
  for (const r of rows) {
    const country = countries.get(r.country);
    if (seen.has(r.s) || !country || countriesOf.get(r.s).size !== 1 || labelCount.get(r.sFr).size !== 1 || /^Q\d+$/.test(r.sFr)) continue;
    // Trop facile si le nom du site contient celui du pays (« Grande Muraille de Chine ») ; déjà couvert par la banque curée.
    if (r.sFr.toLowerCase().includes(country.name.toLowerCase()) || alreadyCovered(r.sFr) || !continentOf(country)) continue;
    if (/territoire|dépendance/i.test(r.desc ?? '') || Number(r.sl) < 55) continue;
    seen.add(r.s);
    const pool = sameContinent(country);
    if (pool.length < 3) continue;
    const rand = rng(`unesco-${r.s}`);
    const others = nearestByFame(country, pool, 3, rand).map((o) => o.name);
    const f = countryForms(country.name);
    const rawDesc = cleanDesc(r.desc);
    // Description utile seulement si elle n'est pas une redite du pays.
    const desc = rawDesc && !rawDesc.toLowerCase().includes(country.name.toLowerCase()) ? rawDesc.charAt(0).toLowerCase() + rawDesc.slice(1) : '';
    const site = cap(r.sFr);
    add('geography', 'unesco', {
      key: `wd-unesco-${r.s}`, concept: `geography.monuments.wd_${slug(r.sFr).slice(0, 30)}_${r.s.toLowerCase()}`,
      label: `Pays de « ${site} »`, type: 'mcq',
      difficulty: Math.round(clamp(100 - 12 * Math.log(Number(r.sl)) + 6, 25, 85)),
      prompt: vary(r.s, [`Dans quel pays se trouve « ${site} » ?`, `« ${site} » se trouve dans quel pays ?`]),
      options: [`${country.name}*`, ...others],
      explanation: `« ${site} » se trouve ${f.in}${desc && desc.length < 120 ? ` (${desc})` : ''}. Le site est inscrit au patrimoine mondial de l'UNESCO.`,
    });
  }
}

// ─────────────── Silhouette du pays (Natural Earth, domaine public)
{
  const shapes = load('shapes').shapes;
  for (const c of countryList) {
    const shape = shapes[c.iso];
    const cont = continentOf(c);
    if (!shape || shape.area < 1.5 || !cont) continue;  // micro-États : forme illisible
    const pool = sameContinent(c).filter((o) => shapes[o.iso]);
    if (pool.length < 3) continue;
    const rand = rng(`shape-${c.id}`);
    const others = nearestByFame(c, pool, 3, rand).map((o) => o.name);
    const f = countryForms(c.name);
    add('geography', 'silhouette', {
      key: `wd-shape-${c.id}`, concept: `geography.countries.shape_${slug(c.en)}`, label: `Silhouette ${f.of}`, type: 'mcq',
      difficulty: Math.round(clamp(countryFame(c) + 10, 22, 88)),
      prompt: vary(`shape-${c.id}`, ['Quel pays a cette forme ?', 'À quel pays correspond cette silhouette ?']),
      options: [`${c.name}*`, ...others], shape: { paths: shape.paths },
      explanation: `C'est la silhouette ${f.of} (${cont}), sans ses territoires éloignés. Contours : Natural Earth.`,
    });
  }
}


// ─────────────── Musique : familles d'instruments
{
  const FAM = { Q1798603: 'à cordes', Q173453: 'à vent', Q133163: 'de percussion' };
  // Hors sujet ou classement discutable (instruments à clavier, catégories, marques, objets).
  const SKIP = new Set(['instrument à cordes frottées', 'instrument à cordes pincées', 'cuivre', 'bois', 'diapason', 'Fender Stratocaster',
    'harmonica', 'accordéon', 'bandonéon', 'piano', 'guimbarde', 'cloche', 'sifflet', 'vuvuzela', 'chophar', 'guitare acoustique',
    'cymbalum', 'guitare classique', 'guitare électrique', 'guitare basse', 'batterie', 'orgue de Barbarie', 'tin whistle']);
  const fams = new Map();
  for (const r of load('instruments').rows) {
    if (/^Q\d+$/.test(r.iFr)) continue;
    fams.set(r.iFr, new Set([...(fams.get(r.iFr) ?? []), r.fam]));
  }
  const sl = new Map(load('instruments').rows.map((r) => [r.iFr, Number(r.sl)]));
  for (const [name, set] of fams) {
    if (SKIP.has(name) || set.size !== 1 || !FAM[[...set][0]]) continue;
    const fam = FAM[[...set][0]];
    const FEM = ['guitare', 'harpe', 'flûte', 'harpe', 'contrebasse', 'clarinette', 'trompette', 'mandoline', 'caisse claire', 'grosse caisse', 'cornemuse', 'viole de gambe',
      'flûte à bec', 'flûte de Pan', 'lyre', 'vielle à roue', 'maraca', 'bandoura', 'dombra', 'cithare', 'kora', 'balalaïka'];
    const H_ASPIRE = ['harpe', 'hautbois'];
    const PLURAL = ['timbales', 'castagnettes'];
    const art = PLURAL.includes(name) ? 'Les ' : /^[aeiouéèêh]/i.test(name) && !H_ASPIRE.includes(name) ? "L'" : FEM.includes(name) ? 'La ' : 'Le ';
    const verb = art === 'Les ' ? 'sont des instruments' : 'est un instrument';
    add('music', 'famille instrument', {
      key: `wd-instr-${slug(name)}`, concept: `music.instruments.family_${slug(name)}`, label: `Famille : ${name}`, type: 'mcq',
      difficulty: Math.round(clamp(100 - 12 * Math.log(sl.get(name) ?? 40) + 8, 18, 70)),
      prompt: `${art}${name} ${verb}…`,
      options: ['à cordes', 'à vent', 'de percussion'].map((f) => (f === fam ? `${f}*` : f)).concat(['à clavier']),
      keep_order: true,
      explanation: `${art}${name} ${verb} ${fam}${fam === 'à vent' ? ' : le son naît du souffle' : fam === 'à cordes' ? ' : le son naît de cordes pincées, frottées ou frappées' : ' : le son naît d\'un choc ou d\'une secousse'}.`,
    });
  }
}

// ─────────────── Musique : groupes → pays, décennie de formation
{
  const NORMALIZE = { Angleterre: 'Royaume-Uni', 'Écosse': 'Royaume-Uni', "Allemagne de l'Ouest": 'Allemagne' };
  const bands = new Map();
  for (const r of load('bands').rows) {
    if (/^Q\d+$/.test(r.bFr) || Number(r.sl) < 55) continue;
    const b = bands.get(r.b) ?? { id: r.b, name: r.bFr, countries: new Set(), year: yearOf(r.start), sl: Number(r.sl) };
    b.countries.add(NORMALIZE[r.countryFr] ?? r.countryFr);
    bands.set(r.b, b);
  }
  const list = [...bands.values()].filter((b) => b.countries.size === 1 && !['Union soviétique'].includes([...b.countries][0]));
  const COUNTRIES = ['États-Unis', 'Royaume-Uni', 'Suède', 'Allemagne', 'Canada', 'Australie', 'Irlande', 'France', 'Japon', 'Corée du Sud', 'Finlande', 'Norvège', 'Italie', 'Pays-Bas', 'Brésil'];
  const NEAR = { 'États-Unis': ['Royaume-Uni', 'Canada', 'Australie'], 'Royaume-Uni': ['États-Unis', 'Irlande', 'Australie'],
    Canada: ['États-Unis', 'Royaume-Uni', 'Australie'], Australie: ['Royaume-Uni', 'Nouvelle-Zélande', 'États-Unis'], Irlande: ['Royaume-Uni', 'États-Unis', 'Écosse'],
    'Suède': ['Norvège', 'Danemark', 'Finlande'], 'Norvège': ['Suède', 'Danemark', 'Finlande'], Finlande: ['Suède', 'Norvège', 'Danemark'],
    'Corée du Sud': ['Japon', 'Chine', 'Taïwan'], Japon: ['Corée du Sud', 'Chine', 'États-Unis'], Allemagne: ['Autriche', 'Pays-Bas', 'Suède'] };
  for (const b of list) {
    const country = [...b.countries][0];
    if (alreadyCovered(b.name)) continue;
    const rand = rng(`band-${b.id}`);
    const others = (NEAR[country] ?? shuffle(COUNTRIES.filter((c) => c !== country), rand)).filter((c) => c !== country).slice(0, 3);
    if (!COUNTRIES.includes(country) && !NEAR[country]) continue;
    add('music', 'groupe pays', {
      key: `wd-band-${b.id}`, concept: `music.popular.band_${slug(b.name)}_${b.id.toLowerCase()}`, label: `Groupe ${b.name}`, type: 'mcq',
      difficulty: Math.round(clamp(100 - 12 * Math.log(b.sl) + 14, 25, 80)),
      prompt: vary(b.id, [`De quel pays vient le groupe ${b.name} ?`, `Le groupe ${b.name} est originaire de quel pays ?`]),
      options: [`${country}*`, ...others],
      explanation: `${b.name} est un groupe originaire ${countryForms(country).of}.`,
    });
    if (b.year && b.year >= 1950 && b.sl >= 80) {
      const d = Math.floor(b.year / 10) * 10;
      const decades = [d - 20, d - 10, d, d + 10, d + 20].filter((x) => x >= 1950 && x <= 2020);
      const pick = shuffle(decades.filter((x) => x !== d), rng(`bandd-${b.id}`)).slice(0, 3);
      add('music', 'groupe décennie', {
        key: `wd-bandd-${b.id}`, concept: `music.popular.band_${slug(b.name)}_${b.id.toLowerCase()}`, label: `Groupe ${b.name}`, type: 'mcq',
        keep_order: true, difficulty: Math.round(clamp(100 - 12 * Math.log(b.sl) + 22, 30, 80)),
        prompt: `Dans quelle décennie le groupe ${b.name} s'est-il formé ?`,
        options: [...pick, d].sort((a, b2) => a - b2).map((x) => `Années ${x}${x === d ? '*' : ''}`),
        explanation: `${b.name} s'est formé en ${b.year}.`,
      });
    }
  }
}

// ─────────────── Sport : Coupe du monde de football (éditions jouées jusqu'en 2022)
{
  const eds = new Map();
  for (const r of load('worldcups').rows) {
    const m = /^Coupe du monde de football (\d{4})$/.exec(r.eFr);
    if (!m || Number(m[1]) > 2022) continue;
    const e = eds.get(m[1]) ?? { year: Number(m[1]), hosts: new Set(), winners: new Set() };
    if (r.hostFr) e.hosts.add(r.hostFr === 'Royaume-Uni' && m[1] === '1966' ? 'Angleterre' : r.hostFr);
    if (r.winnerFr) e.winners.add(r.winnerFr.replace(/^équipe (d'|de |du |des )/, (x) => '').replace(/ de football$/, ''));
    eds.set(m[1], e);
  }
  const team = (w) => ({ Uruguay: 'Uruguay', Italie: 'Italie', Allemagne: 'Allemagne', Brésil: 'Brésil', Angleterre: 'Angleterre', Argentine: 'Argentine',
    France: 'France', Espagne: 'Espagne' }[w] ?? w);
  const list = [...eds.values()].filter((e) => e.winners.size === 1 && e.hosts.size >= 1).sort((a, b) => a.year - b.year);
  const CONTENDERS = ['Brésil', 'Allemagne', 'Italie', 'Argentine', 'France', 'Uruguay', 'Angleterre', 'Espagne', 'Pays-Bas', 'Croatie', 'Hongrie', 'Tchécoslovaquie', 'Suède'];
  const hostsText = (e) => [...e.hosts].join(' et ');
  for (const e of list) {
    const winner = team([...e.winners][0]);
    const rand = rng(`wc-${e.year}`);
    const others = shuffle(CONTENDERS.filter((c) => c !== winner), rand).slice(0, 3);
    const recent = e.year >= 1990;
    add('sport', 'coupe du monde vainqueur', {
      key: `wd-wcw-${e.year}`, concept: `sport.football.world_cup_${e.year}`, label: `Coupe du monde ${e.year}`, type: 'mcq',
      difficulty: e.year === 2018 || e.year === 1998 || e.year === 2022 ? 22 : recent ? 42 : 62,
      prompt: vary(`wc-${e.year}`, [`Quelle équipe a remporté la Coupe du monde de football ${e.year} ?`, `Qui a gagné la Coupe du monde de football ${e.year} ?`]),
      options: [`${winner}*`, ...others],
      explanation: `En ${e.year}, la Coupe du monde, organisée par ${[...e.hosts].map((h) => countryForms(h).the).join(' et ')}, a été remportée par ${countryForms(winner).the}.`,
    });
    if (e.hosts.size === 1) {
      const host = [...e.hosts][0];
      const hostPool = [...new Set(list.flatMap((x) => [...x.hosts]))].filter((h) => h !== host);
      const nearHosts = shuffle(hostPool, rng(`wch-${e.year}`)).slice(0, 3);
      add('sport', 'coupe du monde hôte', {
        key: `wd-wch-${e.year}`, concept: `sport.football.world_cup_host_${e.year}`, label: `Pays hôte ${e.year}`, type: 'mcq',
        difficulty: e.year >= 1998 ? 38 : 60,
        prompt: `Quel pays a accueilli la Coupe du monde de football ${e.year} ?`,
        options: [`${host}*`, ...nearHosts],
        explanation: `La Coupe du monde ${e.year} s'est jouée ${countryForms(host).in} ; elle a été remportée par ${countryForms(winner).the}.`,
      });
    }
  }
}

// ─────────────── Sport : villes des Jeux olympiques (table relue : Wikidata mélange villes et stades)
{
  const SUMMER = { 1896: 'Athènes', 1900: 'Paris', 1904: 'Saint-Louis', 1908: 'Londres', 1912: 'Stockholm', 1920: 'Anvers', 1924: 'Paris',
    1928: 'Amsterdam', 1932: 'Los Angeles', 1936: 'Berlin', 1948: 'Londres', 1952: 'Helsinki', 1956: 'Melbourne', 1960: 'Rome', 1964: 'Tokyo',
    1968: 'Mexico', 1972: 'Munich', 1976: 'Montréal', 1980: 'Moscou', 1984: 'Los Angeles', 1988: 'Séoul', 1992: 'Barcelone', 1996: 'Atlanta',
    2000: 'Sydney', 2004: 'Athènes', 2008: 'Pékin', 2012: 'Londres', 2016: 'Rio de Janeiro', 2020: 'Tokyo', 2024: 'Paris' };
  const WINTER = { 1924: 'Chamonix', 1928: 'Saint-Moritz', 1932: 'Lake Placid', 1936: 'Garmisch-Partenkirchen', 1948: 'Saint-Moritz', 1952: 'Oslo',
    1956: "Cortina d'Ampezzo", 1960: 'Squaw Valley', 1964: 'Innsbruck', 1968: 'Grenoble', 1972: 'Sapporo', 1976: 'Innsbruck', 1980: 'Lake Placid',
    1984: 'Sarajevo', 1988: 'Calgary', 1992: 'Albertville', 1994: 'Lillehammer', 1998: 'Nagano', 2002: 'Salt Lake City', 2006: 'Turin',
    2010: 'Vancouver', 2014: 'Sotchi', 2018: 'Pyeongchang', 2022: 'Pékin' };
  // Contrôle croisé : chaque édition doit exister dans Wikidata avec ce lieu ou ce pays.
  const wd = load('olympics').rows;
  const seen = new Set(wd.filter((r) => r.date).map((r) => `${/hiver/.test(r.eFr) ? 'W' : 'S'}${yearOf(r.date)}`));
  for (const [season, table] of [['S', SUMMER], ['W', WINTER]]) {
    const years = Object.keys(table).map(Number);
    for (const y of years) {
      if (!seen.has(`${season}${y}`)) continue;
      const city = table[y];
      if (y < 1948 && season === 'W') continue;
      const nearby = years.filter((x) => x !== y && table[x] !== city).sort((a, b) => Math.abs(a - y) - Math.abs(b - y));
      const others = [...new Set(nearby.map((x) => table[x]))].slice(0, 3);
      const label = season === 'S' ? "d'été" : "d'hiver";
      const famous = season === 'S' && y >= 1984;
      add('sport', 'jo ville', {
        key: `wd-jo-${season}${y}`, concept: `sport.olympics.host_${season === 'S' ? 'summer' : 'winter'}_${y}`, label: `JO ${label} ${y}`, type: 'mcq',
        difficulty: y === 2024 ? 12 : famous ? 38 : season === 'S' ? 58 : 66,
        prompt: vary(`jo-${season}${y}`, [`Quelle ville a accueilli les Jeux olympiques ${label} de ${y} ?`, `Les Jeux olympiques ${label} de ${y} se sont tenus à…`]),
        options: [`${city}*`, ...others],
        explanation: `Les Jeux olympiques ${label} de ${y} ont eu lieu à ${city}.${[...years].filter((x) => x !== y && table[x] === city).length ? ` La ville les a aussi accueillis en ${years.filter((x) => x !== y && table[x] === city).join(' et ')}.` : ''}`,
      });
    }
  }
}

// ─────────────── Technologie : inventions (liste relue : l'attribution Wikidata est parfois discutable)
{
  // Les inventions qui portent le nom de leur inventeur (moteur Diesel, cage de Faraday…) sont écartées : réponse donnée.
  const KEEP = new Set(['clarinette', 'pile électrique', 'phonographe', 'gramophone', 'lave-vaisselle',
    'souris', 'courrier électronique', 'grande roue', 'gyroscope', 'dynamite', 'presse typographique', 'baromètre',
    'paratonnerre', 'stéthoscope', 'téléphone mobile', 'fermeture autoagrippante', 'machine à écrire',
    'four à micro-ondes', 'aéroglisseur', 'épingle de sûreté', 'lampe néon', 'aspirateur', 'Bluetooth', 'code QR', 'nouilles instantanées',
    'télescope', 'feu de circulation', 'fermeture éclair', 'synthétiseur',
    'compteur Geiger', 'tube cathodique', 'radar', 'lampe à incandescence', 'turboréacteur', 'téléphone', 'code Morse']);
  // Plusieurs inventeurs revendiqués : on ne pose pas « qui a inventé ».
  const byItem = new Map();
  for (const r of load('inventions').rows) {
    if (!KEEP.has(r.iFr)) continue;
    const it = byItem.get(r.i) ?? { id: r.i, name: r.iFr, inventors: new Map(), year: null, sl: Number(r.sl) };
    // Une description qui cite l'invention donnerait la réponse.
    const desc = r.invDesc && cleanDesc(r.invDesc).length <= 60 && !/invent|pionnier/i.test(r.invDesc) && !r.invDesc.toLowerCase().includes(r.iFr.toLowerCase()) ? cleanDesc(r.invDesc) : null;
    it.inventors.set(r.inv, { name: r.invFr, desc });
    const y = yearOf(r.date);
    if (y && (!it.year || y < it.year)) it.year = y;
    byItem.set(r.i, it);
  }
  const single = [...byItem.values()].filter((it) => it.inventors.size === 1);
  const inventorPool = [...new Set(single.map((it) => [...it.inventors.values()][0].name))];
  const YEARS = { 'pile électrique': 1800, phonographe: 1877, 'moteur Diesel': 1893, dynamite: 1867, 'presse typographique': 1450, baromètre: 1643,
    paratonnerre: 1752, stéthoscope: 1816, 'téléphone mobile': 1973, 'four à micro-ondes': 1945, 'aéroglisseur': 1955, 'courrier électronique': 1971,
    'grande roue': 1893, gyroscope: 1852, 'fermeture éclair': 1893, 'code QR': 1994, 'nouilles instantanées': 1958, pascaline: 1642, 'aspirateur': 1901 };
  const def = (name) => (['HTML', 'Bluetooth'].includes(name) ? `le ${name}` : /^[aeiouéèêh]/i.test(name) ? `l'${name}` : ['pile électrique', 'pascaline', 'souris', 'grande roue', 'lentille de Fresnel', 'dynamite',
    'presse typographique', 'machine à écrire', 'épingle de sûreté', 'lampe néon', 'fermeture autoagrippante', 'fermeture éclair', 'cage de Faraday', 'clarinette',
    'lampe à incandescence'].includes(name) ? `la ${name}` : ['nouilles instantanées'].includes(name) ? `les ${name}` : `le ${name}`);
  for (const it of single) {
    const inv = [...it.inventors.values()][0];
    const rand = rng(`inv-${it.id}`);
    const others = shuffle(inventorPool.filter((n) => n !== inv.name), rand).slice(0, 3);
    const year = YEARS[it.name] ?? null;
    const what = def(it.name);
    add('tech', 'invention inventeur', {
      key: `wd-inv-${it.id}`, concept: `tech.inventions.${slug(it.name)}`, label: `Inventeur : ${it.name}`, type: 'mcq',
      difficulty: Math.round(clamp(100 - 12 * Math.log(it.sl) + 12, 25, 80)),
      prompt: vary(it.id, [`Qui a inventé ${what} ?`, `À qui doit-on ${what} ?`]),
      options: [`${inv.name}*`, ...others],
      explanation: `On doit ${what} à ${inv.name}${inv.desc ? ` (${inv.desc})` : ''}${year ? `, vers ${year}` : ''}.`,
    });
    const otherItems = shuffle(single.filter((o) => o.id !== it.id), rng(`invr-${it.id}`)).slice(0, 3).map((o) => cap(o.name));
    add('tech', 'inventeur invention', {
      key: `wd-invr-${it.id}`, concept: `tech.inventions.${slug(it.name)}`, label: `Inventeur : ${it.name}`, type: 'mcq',
      difficulty: Math.round(clamp(100 - 12 * Math.log(it.sl) + 8, 22, 78)),
      prompt: `Qu'a inventé ${inv.name}${inv.desc ? `, ${inv.desc},` : ''} ?`.replace(', ?', ' ?'),
      options: [`${cap(it.name)}*`, ...otherItems],
      explanation: `${inv.name} a inventé ${what}${year ? ` vers ${year}` : ''}.`,
    });
  }
}


// ─────────────── Sciences : lunes → planète
{
  const PLANETS = ['Terre', 'Mars', 'Jupiter', 'Saturne', 'Uranus', 'Neptune'];
  const seenMoon = new Set();
  for (const r of load('moons').rows) {
    if (seenMoon.has(r.m) || /\d/.test(r.mFr) || r.mFr === 'Lune' || Number(r.sl) < 70) continue;
    seenMoon.add(r.m);
    const planet = r.pFr;
    if (!PLANETS.includes(planet)) continue;
    const rand = rng(`moon-${r.m}`);
    const others = shuffle(PLANETS.filter((p) => p !== planet && p !== 'Terre'), rand).slice(0, 3);
    const famous = ['Titan', 'Europe', 'Io', 'Ganymède', 'Callisto', 'Phobos', 'Déimos', 'Triton', 'Encelade'].includes(r.mFr);
    add('science', 'lune planète', {
      key: `wd-moon-${r.m}`, concept: `science.space.moon_${slug(r.mFr)}`, label: `Lune ${r.mFr}`, type: 'mcq',
      difficulty: famous ? 45 : Math.round(clamp(100 - 12 * Math.log(Number(r.sl)) + 20, 55, 85)),
      prompt: vary(`moon-${r.m}`, [`Autour de quelle planète tourne la lune ${r.mFr} ?`, `${r.mFr} est un satellite naturel de…`]),
      options: [`${planet}*`, ...others],
      explanation: `${r.mFr} est un satellite naturel ${deName(planet)}.${planet === 'Uranus' ? " Les lunes d'Uranus portent des noms de personnages de Shakespeare et de Pope." : planet === 'Jupiter' ? ' Les lunes de Jupiter portent surtout des noms de proches de Zeus (Jupiter chez les Romains).' : ''}`,
    });
  }
}

// ─────────────── Géographie : plus haut sommet du pays
{
  const peaks = new Map();
  for (const r of load('peaks').rows) {
    const c = countries.get(r.c);
    if (!c || /^Q\d+$/.test(r.hFr)) continue;
    const e = peaks.get(r.c) ?? { country: c, names: new Set(), elev: 0, sl: Number(r.hsl) };
    e.names.add(r.hFr);
    e.elev = Math.max(e.elev, Math.round(Number(r.elev ?? 0)));
    peaks.set(r.c, e);
  }
  const list = [...peaks.values()].filter((p) => p.names.size === 1 && p.elev > 0);
  for (const p of list) {
    const c = p.country;
    const name = [...p.names][0];
    const cont = continentOf(c);
    if (!cont || c.pop < 2e6) continue;
    // Le nom du sommet donnerait la réponse (mont Cameroun).
    if (name.toLowerCase().includes(c.name.toLowerCase().split(' ')[0])) continue;
    const pool = list.filter((o) => o !== p && continentOf(o.country) === cont && [...o.names][0] !== name);
    if (pool.length < 3) continue;
    const top = [...new Set(pool.sort((a, b) => b.sl - a.sl).map((o) => cap([...o.names][0])))].slice(0, 7);
    const others = shuffle(top, rng(`peak-${c.id}`)).slice(0, 3);
    const withArticle = /^(mont|pic|signal|djebel|cerro|puy)\b/i.test(name) ? `le ${name}` : /^pointe\b/i.test(name) ? `la ${name}` : name;
    const f = countryForms(c.name);
    add('geography', 'plus haut sommet', {
      key: `wd-peak-${c.id}`, concept: `geography.relief.highest_${slug(c.en)}`, label: `Point culminant ${f.of}`, type: 'mcq',
      difficulty: Math.round(clamp(countryFame(c) + 18 - Math.log(p.sl) * 3, 25, 85)),
      prompt: vary(`peak-${c.id}`, [`Quel est le point culminant ${f.of} ?`, `Quel est le plus haut sommet ${f.of} ?`]),
      options: [`${cap(name)}*`, ...others],
      explanation: `Le point culminant ${f.of} est ${withArticle}, à ${p.elev.toLocaleString('fr-FR').replace(/ /g, ' ')} m d'altitude.`,
    });
  }
}

// ─────────────── Cinéma : décennie de sortie, acteurs
{
  const films = new Map();
  for (const r of load('films').rows) {
    const year = yearOf(r.date);
    if (!year || /^Q\d+$/.test(r.wFr)) continue;
    const f = films.get(r.w) ?? { id: r.w, title: r.wFr, director: r.authorFr, year, sl: Number(r.sl), dirs: new Set() };
    f.dirs.add(r.author);
    f.year = Math.min(f.year, year);
    films.set(r.w, f);
  }
  const titles = new Map();
  for (const f of films.values()) titles.set(f.title, (titles.get(f.title) ?? 0) + 1);
  for (const f of films.values()) {
    if (titles.get(f.title) > 1 || f.dirs.size !== 1 || f.year < 1920 || alreadyCovered(f.title)) continue;
    const d = Math.floor(f.year / 10) * 10;
    const decades = [d - 20, d - 10, d + 10, d + 20].filter((x) => x >= 1920 && x <= 2020);
    const pick = shuffle(decades, rng(`filmd-${f.id}`)).slice(0, 3);
    add('cinema', 'film décennie', {
      key: `wd-filmd-${f.id}`, concept: `cinema.films.year_${slug(f.title).slice(0, 30)}_${f.id.toLowerCase()}`, label: `Sortie de « ${f.title} »`,
      type: 'mcq', keep_order: true, difficulty: Math.round(clamp(100 - 12 * Math.log(f.sl) + 16, 25, 80)),
      prompt: `Dans quelle décennie est sorti le film « ${f.title} », de ${f.director} ?`,
      options: [...pick, d].sort((a, b) => a - b).map((x) => `Années ${x}${x === d ? '*' : ''}`),
      explanation: `« ${f.title} » de ${f.director} est sorti en ${f.year}.`,
    });
  }

  const cast = new Map();
  for (const r of load('cast').rows) {
    if (/^Q\d+$/.test(r.wFr) || /^Q\d+$/.test(r.aFr)) continue;
    const f = cast.get(r.w) ?? { id: r.w, title: r.wFr, year: yearOf(r.date), sl: Number(r.sl), actors: new Map() };
    const y = yearOf(r.date);
    if (y && (!f.year || y < f.year)) f.year = y;
    f.actors.set(r.a, { name: r.aFr, sl: Number(r.asl) });
    cast.set(r.w, f);
  }
  // Caméos et non-acteurs (réalisateurs, musiciens de passage) : ni vedette ni leurre.
  const CAMEO = new Set(['Stan Lee', 'Alfred Hitchcock', 'Steven Spielberg', 'Keith Richards', 'Joan Rivers', 'Martin Scorsese', 'Quentin Tarantino']);
  for (const f of cast.values()) for (const [id, a] of [...f.actors]) if (CAMEO.has(a.name)) f.actors.delete(id);
  const allActors = new Map();
  for (const f of cast.values()) for (const [id, a] of f.actors) {
    const prev = allActors.get(id) ?? { ...a, years: [] };
    if (f.year) prev.years.push(f.year);
    allActors.set(id, prev);
  }
  const titleCount = new Map();
  for (const f of cast.values()) titleCount.set(f.title, (titleCount.get(f.title) ?? 0) + 1);
  for (const f of cast.values()) {
    if (titleCount.get(f.title) > 1 || !f.year || alreadyCovered(f.title)) continue;
    const star = [...f.actors.entries()].sort((a, b) => b[1].sl - a[1].sl)[0];
    if (!star) continue;
    const era = (a) => a.years.length ? a.years.reduce((x, y) => x + y, 0) / a.years.length : 1990;
    const pool = [...allActors.entries()].filter(([id]) => !f.actors.has(id))
      .sort((a, b) => Math.abs(era(a[1]) - f.year) - Math.abs(era(b[1]) - f.year)).slice(0, 12).map(([, a]) => a.name);
    const others = shuffle(pool, rng(`cast-${f.id}`)).slice(0, 3);
    if (others.length < 3) continue;
    add('cinema', 'film acteur', {
      key: `wd-cast-${f.id}`, concept: `cinema.actors.${slug(f.title).slice(0, 30)}_${f.id.toLowerCase()}`, label: `Casting de « ${f.title} »`,
      type: 'mcq', difficulty: Math.round(clamp(100 - 12 * Math.log(f.sl) + 12, 25, 80)),
      prompt: vary(`cast-${f.id}`, [`Lequel de ces acteurs joue dans « ${f.title} » (${f.year}) ?`, `Qui fait partie de la distribution de « ${f.title} » (${f.year}) ?`]),
      options: [`${star[1].name}*`, ...others],
      explanation: `${star[1].name} joue dans « ${f.title} », sorti en ${f.year}.`
        + (f.actors.size > 1 ? ` On y voit aussi ${[...f.actors.values()].filter((a) => a.name !== star[1].name).slice(0, 2).map((a) => a.name).join(' et ')}.` : ''),
    });
  }
}

// ─────────────── Écriture
for (const [bucket, list] of Object.entries(out)) {
  list.sort((a, b) => a.key.localeCompare(b.key));
  writeFileSync(join(root, 'content/questions', `wd_${bucket}.json`), JSON.stringify(list, null, 1) + '\n');
}
console.log('Questions générées par modèle :', stats);
console.log('Total :', Object.values(out).reduce((n, l) => n + l.length, 0));
