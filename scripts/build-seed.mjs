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

const subdomains = new Set();
for (const d of taxonomy.domains) for (const [s] of d.subdomains) subdomains.add(`${d.id}.${s}`);

function convert(q) {
  const k = q.key;
  const base = {
    external_key: k, concept_id: q.concept, concept_label: q.label, type: q.type, prompt: q.prompt,
    explanation: q.explanation, takeaway: q.takeaway, hint: q.hint, context_note: q.context,
    source: q.source, fact_as_of: q.fact_as_of, difficulty: q.difficulty, status: 'published',
  };
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
      return { ...base, payload: { options, ...(q.keep_order ? { keep_order: true } : {}) },
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
    default:
      fail(k, `type inconnu ${q.type}`);
      return base;
  }
}

const dir = join(root, 'content/questions');
const questions = [];
const keys = new Set();
const concepts = new Map();
for (const file of readdirSync(dir).filter((f) => f.endsWith('.json')).sort()) {
  for (const q of JSON.parse(readFileSync(join(dir, file), 'utf8'))) {
    if (keys.has(q.key)) fail(q.key, 'clé en double');
    keys.add(q.key);
    if (concepts.has(q.concept) && concepts.get(q.concept) !== q.label) fail(q.key, `libellé de concept incohérent pour ${q.concept}`);
    concepts.set(q.concept, q.label);
    questions.push(convert(q));
  }
}

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
lines.push(`select public._upsert_question(q, 'human', null) from jsonb_array_elements(${lit(JSON.stringify(questions))}::jsonb) q;`);
lines.push('commit;', '');

if (process.argv.includes('--check')) {
  console.log(`✓ ${questions.length} questions valides`);
} else {
  writeFileSync(join(root, 'supabase/seed.sql'), lines.join('\n'));
  const byDomain = {};
  for (const q of questions) { const d = q.concept_id.split('.')[0]; byDomain[d] = (byDomain[d] ?? 0) + 1; }
  console.log(`✓ supabase/seed.sql : ${questions.length} questions`, byDomain);
}
