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

// ─────────────── Déduplication avec la banque curée (même énoncé ou même titre cité)
const curatedText = readdirSync(join(root, 'content/questions'))
  .filter((f) => f.endsWith('.json') && !f.startsWith('wd_'))
  .flatMap((f) => JSON.parse(readFileSync(join(root, 'content/questions', f), 'utf8')))
  .map((q) => `${q.prompt} ${(q.options ?? []).join(' ')}`.toLowerCase());
const alreadyCovered = (needle) => curatedText.some((t) => t.includes(needle.toLowerCase()));

const out = { geography: [], history: [], science: [], arts: [], cinema: [] };
const stats = {};
// Famille = « même moule » de question. Le serveur évite d'en enchaîner deux de la même famille.
const FAMILY = {
  'capitale': 'capital', 'capitale inverse': 'capital', 'drapeau': 'flag', 'continent': 'continent', 'ville': 'city',
  'classement population': 'country_ranking', 'classement superficie': 'country_ranking', 'siècle de naissance': 'person_era',
  'classement naissances': 'person_era', 'bataille': 'battle', 'symbole chimique': 'element', 'élément du symbole': 'element',
  'livre auteur': 'book', 'tableau peintre': 'painting', 'film réalisateur': 'film', 'carte': 'map', 'monnaie': 'currency',
  'langue': 'language', 'unesco': 'monument', 'silhouette': 'shape',
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
      key: `wd-cont-${c.id}`, concept: `geography.location.continent_${key}`, label: `Continent ${f.of}`, type: 'mcq',
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
    key: `wd-city-${city.id}`, concept: `geography.location.city_${slug(city.en)}`, label: `Pays de ${city.name}`, type: 'mcq',
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
    key: `wd-cent-${p.id}`, concept: `history.figures.century_${slug(p.name)}`, label: `Époque de ${p.name}`, type: 'mcq',
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
      key: `wd-births-${pick.map((p) => p.id).join('-')}`, concept: `history.figures.births_set_${n}`,
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
      key: `wd-battle-${r.e}`, concept: `history.dates.${slug(label)}`, label: cap(label), type: 'mcq', keep_order: true,
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
      key: `wd-map-${c.id}`, concept: `geography.location.map_${slug(c.en)}`, label: `Situer ${capName}`, type: 'map_pick',
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

// ─────────────── Écriture
for (const [bucket, list] of Object.entries(out)) {
  list.sort((a, b) => a.key.localeCompare(b.key));
  writeFileSync(join(root, 'content/questions', `wd_${bucket}.json`), JSON.stringify(list, null, 1) + '\n');
}
console.log('Questions générées par modèle :', stats);
console.log('Total :', Object.values(out).reduce((n, l) => n + l.length, 0));
