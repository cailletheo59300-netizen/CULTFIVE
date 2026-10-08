#!/usr/bin/env node
// Convertit content/taxonomy.json + content/questions/*.json en supabase/seed.sql.
// Valide le contenu (une seule bonne réponse, clés uniques, concepts cohérents…) et échoue au moindre problème.
// Usage : node scripts/build-seed.mjs [--check]
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const taxonomy = JSON.parse(readFileSync(join(root, 'content/taxonomy.json'), 'utf8'));
const errors = [];
const fail = (key, msg) => errors.push(`${key}: ${msg}`);

// Identifiants d'options opaques et stables : ne révèlent ni l'ordre ni la bonne réponse.
const oid = (key, text) => createHash('sha1').update(`${key}|${text}`).digest('hex').slice(0, 8);

const FLAG_NAMES = JSON.parse(readFileSync(join(root, 'content/daily_types/flag_names.json'), 'utf8'));

const subdomains = new Set();
for (const d of taxonomy.domains) for (const [s] of d.subdomains) subdomains.add(`${d.id}.${s}`);

// ─────────────── Indice automatique (aide « Indice », payée en graines) quand la question n'en a pas d'écrit à la main.
// QCM : aucun (les indices « initiale » donnaient la réponse, retirés en 0026).
// Nombre : une fourchette (siècle ou quart de siècle pour une année, ordre de grandeur sinon). Jamais la réponse elle-même.
const ARTICLE = /^(le |la |les |l'|l’|un |une |des |du |de la |de l'|en |au |aux )/i;
const letters = (t) => t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^A-Za-z]/g, '');
const fmt = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
export function autoHint(q) {
  // QCM : plus d'indice automatique (« commence par X » donnait souvent la réponse). Seuls les indices écrits comptent.
  if (q.type === 'mcq') return undefined;
  if (q.type === 'mcq' && Array.isArray(q.options)) {
    const texts = q.options.map((o) => o.replace(/\*$/, '').replace(ARTICLE, '').trim());
    const ci = q.options.findIndex((o) => o.endsWith('*'));
    const answer = texts[ci];
    // Options numériques (années, quantités) : l'initiale ne veut rien dire.
    if (!answer || /^[\d−-]/.test(answer) || texts.some((t) => /^\d/.test(t))) return undefined;
    // Siècles en chiffres romains, « Années 1960 »… : l'initiale ne distingue rien.
    if (texts.every((t) => /^([IVXL]+e|[IVXL]+er)\b/.test(t) || /^Ann[ée]es\b/i.test(t))) return undefined;
    const initial = letters(answer).charAt(0).toUpperCase();
    if (!initial) return undefined;
    const same = texts.filter((t, i) => i !== ci && letters(t).charAt(0).toUpperCase() === initial);
    if (same.length === 0) return `La réponse commence par « ${initial} ».`;
    const n = letters(answer).length;
    if (same.every((t) => letters(t).length !== n)) return `La réponse commence par « ${initial} » et compte ${n} lettres.`;
    return undefined;
  }
  if (q.type === 'numeric' && typeof q.answer === 'number' && q.answer > 0) {
    const v = q.answer;
    const isYear = Number.isInteger(v) && v >= 1000 && v <= 2100 && /(ann[ée]e|quand|en quelle|date)/i.test(q.prompt);
    if (isYear) {
      const lo = Math.floor(v / 25) * 25;
      return `Entre ${lo} et ${lo + 25}.`;
    }
    if (v <= 12 && Number.isInteger(v)) return `Un nombre ${v % 2 === 0 ? 'pair' : 'impair'}, ${v <= 6 ? 'entre 1 et 6' : 'entre 7 et 12'}.`;
    const mag = 10 ** Math.floor(Math.log10(v));
    const lo = Math.floor(v / mag) * mag;
    if (lo === v) return `Un nombre rond, entre ${fmt(lo / 2)} et ${fmt(lo * 2)}.`;
    return `Entre ${fmt(lo)} et ${fmt(lo + mag)}.`;
  }
  return undefined;
}

function convert(q) {
  const k = q.key;
  const base = {
    external_key: k, concept_id: q.concept, concept_label: q.label, type: q.type, prompt: q.prompt,
    explanation: q.explanation, takeaway: q.takeaway, hint: q.hint ?? autoHint(q), context_note: q.context,
    source: q.source, fact_as_of: q.fact_as_of, difficulty: q.difficulty, status: q.status ?? 'published',
    origin: q.origin ?? 'human', family: q.family,
  };
  if (q.family && !/^[a-z_]+$/.test(q.family)) fail(k, `famille invalide « ${q.family} »`);
  if (!/^[a-z_]+\.[a-z_]+\.[a-z0-9_]+$/.test(q.concept ?? '')) fail(k, `concept invalide « ${q.concept} »`);
  else if (!subdomains.has(q.concept.split('.').slice(0, 2).join('.'))) fail(k, `sous-domaine inconnu pour ${q.concept}`);
  if (!(q.difficulty >= 5 && q.difficulty <= 95)) fail(k, 'difficulté hors [5, 95]');
  if (!q.explanation || q.explanation.length < 10 || q.explanation.length > 600) fail(k, 'explication manquante ou trop longue');
  if (!q.prompt || q.prompt.length < 5 || q.prompt.length > 400) fail(k, 'énoncé invalide');

  switch (q.type) {
    case 'mcq': {
      const correct = q.options.filter((o) => o.endsWith('*'));
      if (correct.length !== 1) fail(k, 'une et une seule option marquée *');
      if (q.options.length < 2 || q.options.length > 4) fail(k, '2 à 4 options');
      const options = q.options.map((o) => ({ id: oid(k, o.replace(/\*$/, '')), text: o.replace(/\*$/, '') }));
      if (new Set(options.map((o) => o.text)).size !== options.length) fail(k, 'options en double');
      if (q.shape && !(Array.isArray(q.shape.paths) && q.shape.paths.every((p) => Array.isArray(p) && p.length >= 3))) fail(k, 'silhouette invalide');
      return { ...base, payload: { options, ...(q.keep_order ? { keep_order: true } : {}), ...(q.shape ? { shape: q.shape } : {}) },
               answer: { option_id: oid(k, correct[0]?.replace(/\*$/, '')) } };
    }
    case 'true_false':
      if (typeof q.answer !== 'boolean') fail(k, 'réponse booléenne attendue');
      return { ...base, payload: {}, answer: { value: q.answer } };
    case 'numeric': {
      if (typeof q.answer !== 'number') fail(k, 'réponse numérique attendue');
      const decimals = (String(q.answer).split('.')[1] ?? '').length;
      return { ...base, payload: { decimals, ...(q.unit ? { unit: q.unit } : {}), allow_negative: q.answer < 0 },
               answer: { value: q.answer, tolerance: q.tolerance ?? 0 } };
    }
    case 'ordering': {
      if (!Array.isArray(q.items) || q.items.length < 3 || q.items.length > 5) fail(k, '3 à 5 éléments');
      const items = q.items.map((t) => ({ id: oid(k, t), text: t }));
      return { ...base, payload: { items }, answer: { order: items.map((i) => i.id) } };
    }
    case 'pairs': {
      if (!Array.isArray(q.pairs) || q.pairs.length < 3 || q.pairs.length > 5) fail(k, '3 à 5 paires');
      const left = q.pairs.map(([l]) => ({ id: oid(k, `L:${l}`), text: l }));
      const right = q.pairs.map(([, r]) => ({ id: oid(k, `R:${r}`), text: r }));
      return { ...base, payload: { left, right },
               answer: { pairs: Object.fromEntries(left.map((l, i) => [l.id, right[i].id])) } };
    }
    case 'map_pick': {
      const correct = q.pins.filter((p) => p.correct);
      if (correct.length !== 1 || q.pins.length < 2 || q.pins.length > 5) fail(k, 'map_pick : 2 à 5 points dont 1 correct');
      const options = q.pins.map((p) => ({ id: oid(k, `${p.lat},${p.lon}`), lat: p.lat, lon: p.lon }));
      return { ...base, payload: { region: q.region, options },
               answer: { option_id: oid(k, `${correct[0]?.lat},${correct[0]?.lon}`) } };
    }
    // ─── Nouveaux types (0038) : marge annoncée avant de répondre, donc publique dans le payload.
    case 'counter': {
      if (!Number.isInteger(q.answer) || !(q.min <= q.answer && q.answer <= q.max)) fail(k, 'compteur : réponse entière entre min et max');
      if (!(q.tolerance >= 0)) fail(k, 'compteur : marge invalide');
      return { ...base, payload: { min: q.min, max: q.max, start: q.start ?? q.min, tolerance: q.tolerance, ...(q.unit ? { unit: q.unit } : {}) },
               answer: { value: q.answer, tolerance: q.tolerance } };
    }
    case 'timeline': {
      if (!Number.isInteger(q.answer) || !(q.min < q.answer && q.answer < q.max)) fail(k, 'frise : année strictement entre min et max');
      if (!(q.tolerance >= 0)) fail(k, 'frise : marge invalide');
      return { ...base, payload: { min: q.min, max: q.max, tolerance: q.tolerance }, answer: { value: q.answer, tolerance: q.tolerance } };
    }
    case 'gauge': {
      if (!(q.answer >= 0 && q.answer <= 100) || !(q.tolerance > 0)) fail(k, 'jauge : pourcentage 0–100 et marge > 0');
      return { ...base, payload: { tolerance: q.tolerance, unit: '%' }, answer: { value: q.answer, tolerance: q.tolerance } };
    }
    case 'proportion': {
      if (!(q.answer > 0 && q.reference?.size > 0 && q.max > Math.max(q.answer, q.reference.size))) fail(k, 'proportion : tailles invalides');
      if (!(q.tolerance > 0 && q.tolerance < 0.3)) fail(k, 'proportion : marge relative entre 0 et 0,3');
      return { ...base, payload: { reference: q.reference, item: q.item, unit: q.unit, dimension: q.dimension, max: q.max, rel_tolerance: q.tolerance },
               answer: { value: q.answer, rel_tolerance: q.tolerance } };
    }
    case 'letters': {
      if (!/^[A-Z]{4,12}$/.test(q.word ?? '')) fail(k, 'lettres : 4 à 12 majuscules sans accents');
      const tiles = shuffled(k, [...(q.word ?? '')].map((t, i) => ({ id: oid(k, `${i}:${t}`), text: t })));
      return { ...base, payload: { tiles }, answer: { word: q.word, display: q.display ?? q.word } };
    }
    case 'word_order': {
      if (!Array.isArray(q.words) || q.words.length < 3 || q.words.length > 14) fail(k, 'mots dans l\'ordre : 3 à 14 mots');
      const tiles = shuffled(k, (q.words ?? []).map((t, i) => ({ id: oid(k, `${i}:${t}`), text: t })));
      return { ...base, payload: { tiles }, answer: { words: q.words, sentence: q.answer } };
    }
    case 'image_choice': {
      const opts = q.options ?? [];
      if (opts.length !== 4 || opts.filter((o) => o.correct).length !== 1) fail(k, 'choix d\'images : 4 options dont 1 correcte');
      if (q.kind === 'flag' && !opts.every((o) => /^[a-z]{2}$/.test(o.flag ?? '') && FLAG_NAMES[o.flag])) fail(k, 'drapeau : code inconnu');
      const id = (o) => oid(k, o.flag ?? o.title);
      const options = opts.map((o) => q.kind === 'flag' ? { id: id(o), flag: o.flag } : { id: id(o), image: o.image ?? null });
      const labels = Object.fromEntries(opts.map((o) => [id(o), q.kind === 'flag' ? (o.label ?? FLAG_NAMES[o.flag]) : `${o.title}, ${o.artist} (${o.year})`]));
      return { ...base,
               // Tableau sans image : pas encore jouable, gardé en brouillon.
               status: q.kind === 'painting' && opts.some((o) => !o.image) ? 'draft' : base.status,
               payload: { kind: q.kind, options: shuffled(k, options) },
               answer: { option_id: id(opts.find((o) => o.correct) ?? {}), labels } };
    }
    default:
      fail(k, `type inconnu ${q.type}`);
      return base;
  }
}

// Mélange stable (même graine ⇒ même ordre), jamais identique à l'ordre d'origine quand c'est possible.
function shuffled(key, list) {
  const h = (x) => createHash('sha1').update(`${key}|mix|${x}`).digest('hex');
  let out = list.map((v, i) => [h(i), v]).sort((a, b) => (a[0] < b[0] ? -1 : 1)).map(([, v]) => v);
  if (list.length > 1 && JSON.stringify(out) === JSON.stringify(list)) out = [...out.slice(1), out[0]];
  return out;
}

const raw = [];
// Questions classiques, puis celles des nouveaux types (content/daily_types, hors noms de drapeaux).
for (const sub of ['questions', 'daily_types']) {
  const dir = join(root, 'content', sub);
  for (const file of readdirSync(dir).filter((f) => f.endsWith('.json') && f !== 'flag_names.json').sort()) {
    raw.push(...JSON.parse(readFileSync(join(dir, file), 'utf8')));
  }
}

// Calibrage initial. Les questions importées (Wikidata) reçoivent une difficulté tirée de la notoriété, juste dans l'ordre
// mais trop resserrée dans certains thèmes (ex. acteurs : tout entre 55 et 61). Dans un thème importé resserré (écart-type < 7),
// on étale par rang vers un écart-type de 10 autour de la même moyenne : l'ordre est gardé, les extrêmes deviennent vraiment
// faciles ou difficiles. Le calibrage en ligne (réponses des joueurs) prend ensuite le relais.
const themeOf = (q) => (q.concept ?? '').split('.').slice(0, 2).join('.');
const stats = (a) => {
  const m = a.reduce((x, y) => x + y, 0) / a.length;
  return { n: a.length, mean: m, sd: Math.sqrt(a.reduce((x, y) => x + (y - m) ** 2, 0) / a.length) };
};
// Inverse de la loi normale (approximation d'Acklam, largement suffisante ici).
function probit(p) {
  const a = [-39.6968302866538, 220.946098424521, -275.928510446969, 138.357751867269, -30.6647980661472, 2.50662827745924];
  const b = [-54.4760987982241, 161.585836858041, -155.698979859887, 66.8013118877197, -13.2806815528857];
  const c = [-0.00778489400243029, -0.322396458041136, -2.40075827716184, -2.54973253934373, 4.37466414146497, 2.93816398269878];
  const d = [0.00778469570904146, 0.32246712907004, 2.445134137143, 3.75440866190742];
  const lo = 0.02425;
  if (p < lo) { const q = Math.sqrt(-2 * Math.log(p)); return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1); }
  if (p > 1 - lo) return -probit(1 - p);
  const q = p - 0.5, r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}
const calibration = [];
const byTheme = new Map();
for (const q of raw) if (q.origin === 'import') byTheme.set(themeOf(q), [...(byTheme.get(themeOf(q)) ?? []), q]);
for (const [theme, group] of byTheme) {
  const before = stats(group.map((q) => q.difficulty));
  if (group.length < 30 || before.sd >= 7) continue;
  const sorted = [...group].sort((x, y) => x.difficulty - y.difficulty);
  // Rang moyen des ex æquo : même difficulté d'origine → même difficulté calibrée.
  const rank = new Map();
  for (let i = 0; i < sorted.length;) {
    let j = i;
    while (j < sorted.length && sorted[j].difficulty === sorted[i].difficulty) j++;
    rank.set(sorted[i].difficulty, (i + j - 1) / 2);
    i = j;
  }
  for (const q of group) {
    const z = probit((rank.get(q.difficulty) + 0.5) / group.length);
    q.difficulty = Math.round(Math.min(88, Math.max(15, before.mean + 10 * z)));
  }
  calibration.push({ theme, n: group.length, before, after: stats(group.map((q) => q.difficulty)) });
}

const questions = [];
const keys = new Set();
const concepts = new Map();
for (const q of raw) {
  if (keys.has(q.key)) fail(q.key, 'clé en double');
  keys.add(q.key);
  if (concepts.has(q.concept) && concepts.get(q.concept) !== q.label) fail(q.key, `libellé de concept incohérent pour ${q.concept}`);
  concepts.set(q.concept, q.label);
  questions.push(convert(q));
}

// ─────────────── Contrôle qualité
// 1. Doublons : même énoncé et même réponse ; ou même thème, même réponse et énoncés très proches (hors même famille).
const norm = (t) => t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const answerOf = (q) => q.type === 'mcq' ? q.options.find((o) => o.endsWith('*')) ?? ''
  : ['true_false', 'numeric', 'counter', 'timeline', 'gauge', 'proportion', 'word_order'].includes(q.type) ? String(q.answer)
  : q.type === 'letters' ? q.word
  : q.type === 'image_choice' ? JSON.stringify(q.options.find((o) => o.correct) ?? '')
  : JSON.stringify(q.items ?? q.pairs ?? q.pins ?? '');
// Mots de plus de 3 lettres et tous les nombres (« 36 km/h » et « 36 km/h » se ressemblent ; deux suites différentes non).
const wordSet = (t) => new Set(norm(t).split(' ').filter((w) => w.length > 3 || /\d/.test(w)));
const exact = new Map();
const byAnswer = new Map();
const NEAR = Number(process.env.NEAR ?? 0.6);
for (const q of raw) {
  const a = norm(answerOf(q));
  const e = `${norm(q.prompt)}#${a}`;
  if (exact.has(e) && !q.from) fail(q.key, `doublon de ${exact.get(e)}`);
  else exact.set(e, q.key);
  if (a.length >= 1) byAnswer.set(`${themeOf(q)}#${a}`, [...(byAnswer.get(`${themeOf(q)}#${a}`) ?? []), q]);
}
for (const group of byAnswer.values()) {
  if (group.length > 40) continue;
  for (let i = 0; i < group.length; i++) for (let j = i + 1; j < group.length; j++) {
    const [x, y] = [group[i], group[j]];
    if (x.family && x.family === y.family) continue;
    if (x.origin === 'import' && y.origin === 'import') continue;
    // Conversion d'une question classique vers un nouveau type : variante voulue, même notion.
    if (x.from || y.from) continue;
    const A = wordSet(x.prompt), B = wordSet(y.prompt);
    const inter = [...A].filter((w) => B.has(w)).length;
    if (inter / ((A.size + B.size - inter) || 1) >= NEAR && norm(x.prompt) !== norm(y.prompt)) fail(y.key, `quasi-doublon de ${x.key}`);
  }
}
// 2. Vrai/Faux équilibré (sinon « toujours Vrai » devient une stratégie).
const tf = raw.filter((q) => q.type === 'true_false');
const trueShare = tf.filter((q) => q.answer === true).length / Math.max(tf.length, 1);
if (tf.length >= 20 && (trueShare < 0.4 || trueShare > 0.6)) fail('vrai/faux', `${Math.round(trueShare * 100)} % de « vrai » (attendu 40–60 %)`);

if (errors.length) {
  console.error(`✗ ${errors.length} problème(s) dans le contenu :\n  ` + errors.join('\n  '));
  process.exit(1);
}

const lit = (v) => `'${String(v).replace(/'/g, "''")}'`;
const lines = [
  '-- GÉNÉRÉ par scripts/build-seed.mjs — ne pas éditer à la main.',
  '-- Source : content/taxonomy.json, content/questions/*.json',
  'begin;',
];
taxonomy.domains.forEach((d, i) => {
  lines.push(`insert into public.domains (id, name, daily_slot, sort) values (${lit(d.id)}, ${lit(d.name)}, ${d.daily_slot ? lit(d.daily_slot) : 'null'}, ${i})
  on conflict (id) do update set name = excluded.name, daily_slot = excluded.daily_slot, sort = excluded.sort;`);
  d.subdomains.forEach(([s, name], j) => {
    lines.push(`insert into public.subdomains (id, domain_id, name, sort) values (${lit(`${d.id}.${s}`)}, ${lit(d.id)}, ${lit(name)}, ${j})
  on conflict (id) do update set name = excluded.name, sort = excluded.sort;`);
  });
});
// Thèmes retirés de la taxonomie : conservés (historique des joueurs) mais inactifs.
const activeSubdomains = taxonomy.domains.flatMap((d) => d.subdomains.map(([s]) => lit(`${d.id}.${s}`)));
lines.push(`update public.subdomains set is_active = (id in (${activeSubdomains.join(', ')}));`);
for (const origin of ['human', 'import']) {
  const group = questions.filter((q) => q.origin === origin).map(({ origin: _o, ...q }) => q);
  if (group.length) lines.push(`select public._upsert_question(q, '${origin}', null) from jsonb_array_elements(${lit(JSON.stringify(group))}::jsonb) q;`);
}
lines.push('commit;', '');

if (process.argv.includes('--report')) {
  // Rapport de difficulté par thème (après calibrage) : repère les thèmes sans questions difficiles.
  const rows = [];
  const themes = [...new Set(questions.map((q) => themeOf({ concept: q.concept_id })))].sort();
  for (const t of themes) {
    const d = questions.filter((q) => themeOf({ concept: q.concept_id }) === t).map((q) => q.difficulty);
    const c = (lo, hi) => d.filter((x) => x >= lo && x < hi).length;
    rows.push(`| ${t} | ${d.length} | ${c(0, 35)} | ${c(35, 55)} | ${c(55, 70)} | ${c(70, 101)} | ${Math.max(...d)} |`);
  }
  const cal = calibration.map((c) => `| ${c.theme} | ${c.n} | ${c.before.mean.toFixed(0)} ± ${c.before.sd.toFixed(1)} | ${c.after.mean.toFixed(0)} ± ${c.after.sd.toFixed(1)} |`);
  writeFileSync(join(root, 'docs/CALIBRATION.md'), [
    '# Calibrage des difficultés (généré par `node scripts/build-seed.mjs --report`)', '',
    'Difficulté initiale sur l\'échelle du niveau (0–100). Un joueur de niveau μ a 50 % de chances sur une question de difficulté μ,',
    '27 % à μ + 10 et 73 % à μ − 10. Le calibrage en ligne ajuste ensuite chaque question d\'après les réponses.', '',
    '## Thèmes importés étalés', '', '| Thème | Questions | Avant (moyenne ± écart-type) | Après |', '|---|---|---|---|', ...cal, '',
    '## Répartition par thème', '', '| Thème | Questions | < 35 | 35–54 | 55–69 | ≥ 70 | Max |', '|---|---|---|---|---|---|---|', ...rows, '',
  ].join('\n'));
  console.log(`✓ docs/CALIBRATION.md (${calibration.length} thème(s) étalé(s))`);
  const withHint = questions.filter((q) => q.hint).length;
  console.log(`  indices : ${withHint}/${questions.length} (${raw.filter((q) => q.hint).length} écrits à la main) · vrai/faux : ${Math.round(trueShare * 100)} % de « vrai »`);
}

if (process.argv.includes('--check')) {
  console.log(`✓ ${questions.length} questions valides`);
} else {
  writeFileSync(join(root, 'supabase/seed.sql'), lines.join('\n'));
  const byDomain = {};
  for (const q of questions) { const d = q.concept_id.split('.')[0]; byDomain[d] = (byDomain[d] ?? 0) + 1; }
  console.log(`✓ supabase/seed.sql : ${questions.length} questions`, byDomain);
}
