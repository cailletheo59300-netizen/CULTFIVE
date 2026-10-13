// Ajoute à ios/AlbumData/cards.json l'identifiant serveur de chaque carte (« history.antiquity.la_prehistoire »),
// lu dans content/album/<page>.json par page et numéro. L'app s'en sert pour parler au serveur (album_overview…).
// Usage : node scripts/album/card-ids.mjs   (à relancer après scripts/album/export-app.mjs)
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const file = join(root, 'ios/AlbumData/cards.json');
const app = JSON.parse(readFileSync(file, 'utf8'));
const ids = new Map();
for (const f of readdirSync(join(root, 'content/album')).filter((f) => f.endsWith('.json'))) {
  const page = JSON.parse(readFileSync(join(root, 'content/album', f), 'utf8'));
  for (const c of page.cards ?? []) ids.set(`${page.page}#${c.n}`, c.id);
}
let missing = 0;
for (const page of app.pages) {
  for (const c of page.cards) {
    const id = ids.get(`${page.key}#${c.n}`);
    if (!id) { console.error(`carte sans fiche : ${page.key} n° ${c.n}`); missing++; }
    c.id = id;
  }
}
if (missing) process.exit(1);
writeFileSync(file, JSON.stringify(app, null, 0));
console.log(app.pages.reduce((n, p) => n + p.cards.length, 0), 'cartes reliées au serveur');
