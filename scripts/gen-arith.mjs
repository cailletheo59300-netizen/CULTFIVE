#!/usr/bin/env node
// Calculs « purs » générés (additions, soustractions, multiplications, divisions exactes, carrés, priorités, décimaux)
// → content/questions/gen_arith.json. Réponses exactes par construction ; difficulté calculée d'après la taille des nombres
// et les retenues (échelle 0–100 du niveau ; build-seed.mjs ajoute ensuite +5 comme pour toutes les questions neuves).
// Une famille par type de calcul : une partie n'enchaîne pas deux calculs du même genre. Déterministe : relancer
// produit le même fichier.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';

let seed = 20261014;
const rand = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const int = (a, b) => a + Math.floor(rand() * (b - a + 1));
const fr = (n) => {
  const [i, d] = String(n).split('.');
  return i.replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + (d ? ',' + d : '');
};
const round2 = (x) => Math.round(x * 100) / 100;
const digits = (n) => String(n).split('').map(Number).reverse();

// Retenues d'une addition, emprunts d'une soustraction (chiffre par chiffre).
function carries(a, b) {
  const x = digits(a), y = digits(b); let c = 0, n = 0;
  for (let i = 0; i < Math.max(x.length, y.length); i++) { c = ((x[i] ?? 0) + (y[i] ?? 0) + c) >= 10 ? 1 : 0; n += c; }
  return n;
}
function borrows(a, b) {
  const x = digits(a), y = digits(b); let c = 0, n = 0;
  for (let i = 0; i < x.length; i++) { c = ((x[i] ?? 0) - (y[i] ?? 0) - c) < 0 ? 1 : 0; n += c; }
  return n;
}
const clamp = (d) => Math.max(5, Math.min(90, Math.round(d)));

const out = [];
// Énoncés déjà présents ailleurs dans la banque : jamais repris.
const dir = new URL('../content/questions/', import.meta.url);
const bank = readdirSync(dir).filter((f) => f.endsWith('.json') && f !== 'gen_arith.json')
  .flatMap((f) => JSON.parse(readFileSync(new URL(f, dir), 'utf8')));
const seen = new Set(bank.map((q) => q.prompt));
// Les familles ne prennent que des lettres : « add_2d » → « add_cd ».
const familyId = (f) => f.replace(/[0-9]/g, (d) => 'abcdefghij'[d]);
const counts = {};
// Une notion par famille (calc.<thème>.arith_<famille>), rangée dans une carte de l'album (content/album/calc.*.json).
// Le contrôle de build-seed voit deux calculs de même résultat qui partagent un nombre comme des quasi-doublons
// (« 56 ÷ 7 » et « 64 − 56 », réponse 8) : on les évite dès la génération.
const numbersOf = (p) => new Set(p.match(/\d[\d ,]*/g)?.map((n) => n.trim()) ?? []);
const byAnswer = new Map();
for (const q of bank) if (typeof q.answer === 'number') byAnswer.set(q.answer, [...(byAnswer.get(q.answer) ?? []), numbersOf(q.prompt)]);
function add(family, theme, label, difficulty, prompt, answer, explanation, hint) {
  if (seen.has(prompt)) return false;
  const nums = numbersOf(prompt);
  if ((byAnswer.get(answer) ?? []).some((other) => [...nums].some((n) => other.has(n)))) return false;
  byAnswer.set(answer, [...(byAnswer.get(answer) ?? []), nums]);
  seen.add(prompt);
  counts[family] = (counts[family] ?? 0) + 1;
  out.push({ key: `arith-${family}-${String(counts[family]).padStart(3, '0')}`, concept: `calc.${theme}.arith_${family}`, label,
             type: 'numeric', difficulty: clamp(difficulty), family: `calc_arith_${familyId(family)}`, prompt, answer, explanation, hint });
  return true;
}
const make = (n, fn) => { let made = 0, tries = 0; while (made < n && tries++ < n * 40) if (fn()) made++; };

// ─────────────── Additions
make(25, () => {
  const a = int(12, 89), b = int(11, 89), c = carries(a, b);
  return add('add_2d', 'mental', 'Addition à 2 chiffres', 8 + 6 * c, `Combien font ${a} + ${b} ?`, a + b,
    `${a} + ${b} : ${Math.floor(a / 10) * 10} + ${Math.floor(b / 10) * 10} = ${Math.floor(a / 10) * 10 + Math.floor(b / 10) * 10}, puis ${a % 10} + ${b % 10} = ${a % 10 + b % 10}. Total ${fr(a + b)}.`,
    'Ajoute les dizaines, puis les unités.');
});
make(25, () => {
  const a = int(102, 899), b = int(101, 899), c = carries(a, b);
  return add('add_3d', 'mental', 'Addition à 3 chiffres', 16 + 5 * c, `Combien font ${a} + ${b} ?`, a + b,
    `Centaines : ${Math.floor(a / 100) * 100} + ${Math.floor(b / 100) * 100} = ${fr(Math.floor(a / 100) * 100 + Math.floor(b / 100) * 100)} ; reste : ${a % 100} + ${b % 100} = ${a % 100 + b % 100}. Total ${fr(a + b)}.`,
    'Ajoute les centaines d\'abord, puis le reste.');
});
make(15, () => {
  const a = int(1012, 8999), b = int(120, 4999), c = carries(a, b);
  return add('add_4d', 'mental', 'Grande addition', 30 + 4 * c, `Combien font ${fr(a)} + ${fr(b)} ?`, a + b,
    `${fr(a)} + ${fr(b)} = ${fr(a + b)}. Par milliers : ${fr(Math.floor(a / 1000) * 1000)} + ${fr(Math.floor(b / 1000) * 1000)}, puis ${a % 1000} + ${b % 1000}.`,
    'Découpe en milliers et en reste.');
});

// ─────────────── Soustractions
make(25, () => {
  const a = int(31, 98), b = int(11, a - 5), k = borrows(a, b);
  return add('sub_2d', 'mental', 'Soustraction à 2 chiffres', 12 + 8 * k, `Combien font ${a} − ${b} ?`, a - b,
    `${a} − ${b} = ${a} − ${Math.floor(b / 10) * 10} − ${b % 10} = ${a - Math.floor(b / 10) * 10} − ${b % 10} = ${a - b}.`,
    'Enlève d\'abord les dizaines, puis les unités.');
});
make(25, () => {
  const a = int(301, 999), b = int(102, a - 40), k = borrows(a, b);
  return add('sub_3d', 'mental', 'Soustraction à 3 chiffres', 22 + 6 * k, `Combien font ${a} − ${b} ?`, a - b,
    `${a} − ${b} : on peut compléter de ${b} à ${a}. ${b} + ${a - b} = ${a}, donc le résultat est ${fr(a - b)}.`,
    `Compte ce qu'il faut ajouter à ${b} pour arriver à ${a}.`);
});
make(15, () => {
  const a = int(2003, 9999), b = int(1004, a - 300), k = borrows(a, b);
  return add('sub_4d', 'mental', 'Grande soustraction', 36 + 4 * k, `Combien font ${fr(a)} − ${fr(b)} ?`, a - b,
    `${fr(a)} − ${fr(b)} = ${fr(a - b)}. Vérification : ${fr(b)} + ${fr(a - b)} = ${fr(a)}.`,
    'Vérifie en ajoutant ton résultat au nombre retiré.');
});

// ─────────────── Multiplications
make(15, () => {
  const a = int(6, 9), b = int(6, 9);
  return add('mul_tables', 'mental', 'Table de multiplication', a * b >= 54 ? 14 : 10, `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${a * b}.`, `Pense à ${a} × ${b - 1} = ${a * (b - 1)}, puis ajoute ${a}.`);
});
make(25, () => {
  const a = int(13, 98), b = int(3, 9);
  if (a % 10 === 0) return false;
  const t = Math.floor(a / 10) * 10, u = a % 10;
  return add('mul_2x1', 'mental', 'Multiplication 2 chiffres × 1', 24 + (a > 50 ? 4 : 0) + (b >= 7 ? 4 : 0), `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${t} × ${b} + ${u} × ${b} = ${t * b} + ${u * b} = ${fr(a * b)}.`, `Décompose : ${t} × ${b} + ${u} × ${b}.`);
});
make(25, () => {
  const a = int(13, 98), b = int(12, 98);
  if (a % 10 === 0 || b % 10 === 0) return false;
  const t = Math.floor(b / 10) * 10, u = b % 10;
  return add('mul_2x2', 'mental', 'Multiplication 2 chiffres × 2', 46 + (a * b > 2500 ? 6 : 0), `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${a} × ${t} + ${a} × ${u} = ${fr(a * t)} + ${fr(a * u)} = ${fr(a * b)}.`, `Décompose ${b} en ${t} + ${u}.`);
});
make(20, () => {
  const a = int(112, 989), b = int(3, 9);
  if (a % 10 === 0) return false;
  const h = Math.floor(a / 100) * 100, r = a % 100;
  return add('mul_3x1', 'mental', 'Multiplication 3 chiffres × 1', 38 + (b >= 7 ? 4 : 0), `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${h} × ${b} + ${r} × ${b} = ${fr(h * b)} + ${fr(r * b)} = ${fr(a * b)}.`, `Décompose : ${h} × ${b} + ${r} × ${b}.`);
});
make(15, () => {
  const a = int(112, 989), b = int(12, 89);
  if (a % 10 === 0 || b % 10 === 0) return false;
  const t = Math.floor(b / 10) * 10, u = b % 10;
  return add('mul_3x2', 'mental', 'Multiplication 3 chiffres × 2', 62 + (a * b > 30000 ? 4 : 0), `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${a} × ${t} + ${a} × ${u} = ${fr(a * t)} + ${fr(a * u)} = ${fr(a * b)}.`, `Pose-la : ${a} × ${t}, puis ${a} × ${u}.`);
});
make(12, () => {
  const a = int(112, 989), b = int(112, 989);
  if (a % 10 === 0 || b % 10 === 0) return false;
  const h = Math.floor(b / 100) * 100, t = Math.floor((b % 100) / 10) * 10, u = b % 10;
  return add('mul_3x3', 'mental', 'Multiplication 3 chiffres × 3', 76 + (a * b > 400000 ? 4 : 0), `Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${a} × ${h} + ${a} × ${t} + ${a} × ${u} = ${fr(a * h)} + ${fr(a * t)} + ${fr(a * u)} = ${fr(a * b)}.`,
    `Pose-la en trois lignes : × ${h}, × ${t}, × ${u}.`);
});

// ─────────────── Divisions exactes
make(20, () => {
  const b = int(3, 9), q = int(4, 12), a = b * q;
  return add('div_2by1', 'mental', 'Division simple', 14 + (b >= 7 ? 4 : 0) + (q > 9 ? 2 : 0), `Combien font ${a} ÷ ${b} ?`, q,
    `${a} ÷ ${b} = ${q}, car ${b} × ${q} = ${a}.`, `Cherche dans la table de ${b}.`);
});
make(20, () => {
  const b = int(3, 9), q = int(13, 99), a = b * q;
  if (a < 100) return false;
  return add('div_3by1', 'mental', 'Division à 3 chiffres', 32 + (b >= 7 ? 4 : 0), `Combien font ${a} ÷ ${b} ?`, q,
    `${a} ÷ ${b} = ${q}, car ${b} × ${q} = ${a}. Astuce : ${b} × ${Math.floor(q / 10) * 10} = ${b * Math.floor(q / 10) * 10}, reste ${a - b * Math.floor(q / 10) * 10}.`,
    `Combien de fois ${b} dans ${Math.floor(a / 10)} dizaines ?`);
});
make(15, () => {
  const b = int(12, 39), q = int(12, 99), a = b * q;
  if (b % 10 === 0) return false;
  return add('div_4by2', 'mental', 'Grande division', 52 + (b > 25 ? 6 : 0), `Combien font ${fr(a)} ÷ ${b} ?`, q,
    `${fr(a)} ÷ ${b} = ${q}, car ${b} × ${q} = ${fr(a)}.`, `Essaie ${b} × ${Math.round(a / b / 10) * 10}, puis ajuste.`);
});

// ─────────────── Carrés
make(15, () => {
  const n = int(13, 99);
  if (n % 10 === 0) return false;
  return add('square', 'mental', 'Carré d\'un nombre', 42 + (n > 40 ? 6 : 0) + (n % 10 === 5 ? -8 : 0), `Combien vaut ${n}² ?`, n * n,
    `${n}² = ${n} × ${n} = ${fr(n * n)}.${n % 10 === 5 ? ` Astuce des nombres en 5 : ${Math.floor(n / 10)} × ${Math.floor(n / 10) + 1} = ${Math.floor(n / 10) * (Math.floor(n / 10) + 1)}, puis on écrit 25.` : ''}`,
    n % 10 === 5 ? 'Les carrés des nombres en 5 finissent toujours par 25.' : `${n} × ${n}, en décomposant ${n}.`);
});

// ─────────────── Priorités de calcul
make(20, () => {
  const a = int(2, 30), b = int(2, 9), c = int(2, 9), kind = int(0, 2);
  if (kind === 0) return add('priority', 'number_logic', 'Priorités de calcul', 26, `Combien font ${a} + ${b} × ${c} ?`, a + b * c,
    `La multiplication passe d'abord : ${b} × ${c} = ${b * c}, puis ${a} + ${b * c} = ${a + b * c}.`, 'La multiplication avant l\'addition.');
  if (kind === 1) {
    const x = int(3, 9), y = int(3, 9), z = int(2, x * y - 1);
    return add('priority', 'number_logic', 'Priorités de calcul', 24, `Combien font ${x} × ${y} − ${z} ?`, x * y - z,
      `D'abord ${x} × ${y} = ${x * y}, puis ${x * y} − ${z} = ${x * y - z}.`, 'La multiplication avant la soustraction.');
  }
  return add('priority', 'number_logic', 'Priorités de calcul', 28, `Combien font (${a} + ${b}) × ${c} ?`, (a + b) * c,
    `Les parenthèses d'abord : ${a} + ${b} = ${a + b}, puis ${a + b} × ${c} = ${(a + b) * c}.`, 'Les parenthèses d\'abord.');
});

// ─────────────── Décimaux
make(15, () => {
  const a = round2(int(11, 199) / 10), b = round2(int(101, 999) / 100), s = round2(a + b);
  return add('dec_add', 'mental', 'Addition de décimaux', 28 + (String(s).length > 5 ? 4 : 0), `Combien font ${fr(a)} + ${fr(b)} ?`, s,
    `On aligne les virgules : ${fr(a)} = ${fr(a.toFixed(2))} ; ${fr(a.toFixed(2))} + ${fr(b.toFixed(2))} = ${fr(s)}.`,
    'Écris les deux nombres avec deux chiffres après la virgule.');
});
make(12, () => {
  const a = round2(int(11, 99) / 10), b = int(2, 9), p = round2(a * b);
  if (Number.isInteger(a)) return false;
  return add('dec_mul', 'mental', 'Multiplier un décimal', 32 + (b >= 7 ? 4 : 0), `Combien font ${fr(a)} × ${b} ?`, p,
    `${fr(a)} × ${b} = ${Math.round(a * 10)} × ${b} ÷ 10 = ${Math.round(a * 10) * b} ÷ 10 = ${fr(p)}.`,
    `Calcule ${Math.round(a * 10)} × ${b}, puis divise par 10.`);
});

writeFileSync(new URL('../content/questions/gen_arith.json', import.meta.url), JSON.stringify(out, null, 1) + '\n');
const byFamily = Object.entries(counts).map(([f, n]) => `${f} ${n}`).join(' · ');
console.log(`${out.length} calculs · ${byFamily}`);
