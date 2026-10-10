// Vérifie les pages de l'album (content/album/*.json) : chaque notion du sous-thème est rangée dans une seule carte
// (ou listée « à déplacer »), et chaque notion citée existe dans le contenu.
// Usage : node scripts/check-album.mjs
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const concepts = new Set();
for (const dir of ['content/questions', 'content/daily_types']) {
  for (const file of readdirSync(join(root, dir)).filter((f) => f.endsWith('.json') && f !== 'flag_names.json')) {
    const data = JSON.parse(readFileSync(join(root, dir, file), 'utf8'));
    if (Array.isArray(data)) for (const q of data) if (q.concept) concepts.add(q.concept);
  }
}

let errors = 0;
const fail = (msg) => { console.error('✗ ' + msg); errors++; };
const pages = readdirSync(join(root, 'content/album')).filter((f) => f.endsWith('.json'));
for (const file of pages) {
  const page = JSON.parse(readFileSync(join(root, 'content/album', file), 'utf8'));
  const owner = new Map();
  page.cards.forEach((card, i) => {
    if (card.n !== i + 1) fail(`${file} : la carte « ${card.name} » devrait porter le numéro ${i + 1}`);
    for (const field of ['id', 'name', 'kind', 'subject', 'figure', 'phrase']) if (!card[field]) fail(`${file} : « ${card.name} » sans ${field}`);
    if (!card.concepts?.length) fail(`${file} : « ${card.name} » ne contient aucune notion`);
    for (const c of card.concepts ?? []) {
      if (!concepts.has(c)) fail(`${file} : notion inconnue ${c}`);
      if (owner.has(c)) fail(`${file} : ${c} est dans « ${owner.get(c)} » et « ${card.name} »`);
      owner.set(c, card.name);
    }
  });
  for (const c of page.to_move?.concepts ?? []) {
    if (owner.has(c)) fail(`${file} : ${c} est à la fois dans une carte et à déplacer`);
    owner.set(c, 'à déplacer');
  }
  const prefix = page.page + '.';
  for (const c of concepts) if (c.startsWith(prefix) && !owner.has(c)) fail(`${file} : notion ${c} rangée dans aucune carte`);
  console.log(`${page.title} : ${page.cards.length} cartes, ${[...owner.values()].filter((v) => v !== 'à déplacer').length} notions rangées`);
}
if (errors) { console.error(`${errors} erreur(s)`); process.exit(1); }
console.log(`${pages.length} page(s) vérifiée(s).`);
