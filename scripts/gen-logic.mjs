#!/usr/bin/env node
// Suites logiques calculées (réponses exactes par construction) → content/questions/gen_logic.json.
// Déterministe : relancer produit le même fichier.
import { writeFileSync } from 'node:fs';

let seed = 20260926;
const rand = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const int = (a, b) => a + Math.floor(rand() * (b - a + 1));
const out = [];
const seen = new Set();
const add = (id, family, label, difficulty, terms, answer, explanation) => !seen.has(terms.join()) && seen.add(terms.join()) && out.push({
  key: `glog-${String(id).padStart(3, '0')}`, concept: `logic.sequences.gen_${family}_${id}`, label, type: 'numeric', difficulty,
  prompt: `Quel nombre suit : ${terms.join(', ')}, … ?`, answer, explanation,
});

let id = 1;
// Arithmétiques
for (let i = 0; i < 12; i++) {
  const a = int(2, 40), r = [3, 4, 6, 7, 8, 9, 11, 12, 15, 25][int(0, 9)] * (i % 4 === 3 ? -1 : 1);
  const t = [0, 1, 2, 3, 4].map((k) => a + (r < 0 ? 100 : 0) + k * r);
  add(id++, 'arith', 'Suite régulière', r < 0 ? 30 : 20, t, t[4] + r, `On ${r > 0 ? 'ajoute' : 'retire'} ${Math.abs(r)} à chaque fois : ${t[4]} ${r > 0 ? '+' : '−'} ${Math.abs(r)} = ${t[4] + r}.`);
}
// Géométriques
for (let i = 0; i < 8; i++) {
  const a = int(1, 5), q = [2, 3, 4, 5][i % 4];
  const t = [0, 1, 2, 3].map((k) => a * q ** k);
  add(id++, 'geom', 'Suite multipliée', 30 + q * 3, t, t[3] * q, `On multiplie par ${q} : ${t[3]} × ${q} = ${t[3] * q}.`);
}
// Écarts croissants
for (let i = 0; i < 8; i++) {
  const a = int(1, 20), d0 = int(1, 4), s = int(1, 3);
  const t = [a]; for (let k = 0; k < 4; k++) t.push(t[k] + d0 + k * s);
  const next = t[4] + d0 + 4 * s;
  add(id++, 'growing', 'Écarts qui grandissent', 50, t, next,
    `Les écarts augmentent de ${s} à chaque fois : +${[0, 1, 2, 3].map((k) => d0 + k * s).join(', +')}, puis +${d0 + 4 * s}. ${t[4]} + ${d0 + 4 * s} = ${next}.`);
}
// Deux suites entrelacées
for (let i = 0; i < 6; i++) {
  const a = int(1, 9), r = int(2, 5), b = int(20, 60), s = int(2, 6);
  const t = [a, b, a + r, b - s, a + 2 * r, b - 2 * s];
  add(id++, 'interleaved', 'Deux suites mêlées', 60, t, a + 3 * r,
    `Deux suites alternent : ${a}, ${a + r}, ${a + 2 * r}… (+${r}) et ${b}, ${b - s}, ${b - 2 * s}… (−${s}). Le suivant appartient à la première : ${a + 3 * r}.`);
}
// Double puis ajoute
for (let i = 0; i < 6; i++) {
  const a = int(1, 6), c = [1, 2, 3, -1][i % 4];
  const t = [a]; for (let k = 0; k < 4; k++) t.push(t[k] * 2 + c);
  add(id++, 'double', 'Doubler et ajuster', 60, t, t[4] * 2 + c, `On double puis on ${c > 0 ? `ajoute ${c}` : `retire ${-c}`} : ${t[4]} × 2 ${c > 0 ? '+' : '−'} ${Math.abs(c)} = ${t[4] * 2 + c}.`);
}
// Carrés décalés
for (let i = 0; i < 5; i++) {
  const n0 = int(1, 5), c = int(1, 9) * (i % 2 ? -1 : 1);
  const t = [0, 1, 2, 3, 4].map((k) => (n0 + k) ** 2 + c);
  const n = n0 + 5;
  add(id++, 'squares', 'Carrés décalés', 65, t, n * n + c, `Ce sont les carrés ${c > 0 ? 'plus' : 'moins'} ${Math.abs(c)} : ${n0}², ${n0 + 1}²… donc ${n}² ${c > 0 ? '+' : '−'} ${Math.abs(c)} = ${n * n + c}.`);
}
writeFileSync(new URL('../content/questions/gen_logic.json', import.meta.url), JSON.stringify(out, null, 1) + '\n');
console.log(`${out.length} suites`);
