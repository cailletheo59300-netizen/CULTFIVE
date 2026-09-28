#!/usr/bin/env node
// Questions de calcul générées (réponses exactes par construction) → content/questions/gen_calc.json.
// Chaque modèle a sa famille (pas deux fois de suite dans une partie), une explication qui montre la méthode et un indice.
// Déterministe : relancer produit le même fichier.
import { writeFileSync } from 'node:fs';

let seed = 20260929;
const rand = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const int = (a, b) => a + Math.floor(rand() * (b - a + 1));
const pick = (arr) => arr[int(0, arr.length - 1)];
const fr = (n) => String(n).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const gcd = (a, b) => (b ? gcd(b, a % b) : a);
const out = [];
const seenPrompts = new Set();
let id = 1;

function add(theme, family, label, difficulty, q) {
  if (seenPrompts.has(q.prompt)) return;
  seenPrompts.add(q.prompt);
  const n = id++;
  out.push({ key: `gcalc-${String(n).padStart(3, '0')}`, concept: `calc.${theme}.gen_${family}_${n}`, label: `${label} (${n})`,
             difficulty, family: `calc_${family}`, ...q });
}
const num = (prompt, answer, explanation, hint, unit) => ({ type: 'numeric', prompt, answer, explanation, hint, ...(unit ? { unit } : {}) });
const mcq = (prompt, correct, wrong, explanation, hint) => ({ type: 'mcq', prompt, options: [`${correct}*`, ...wrong], explanation, hint });
const frac = (a, b) => { const g = gcd(a, b); return b / g === 1 ? `${a / g}` : `${a / g}/${b / g}`; };

// ─────────────── Calcul mental
for (let i = 0; i < 4; i++) {
  const a = int(23, 89), b = int(6, 9);
  if (a % 10 === 0) continue;
  const t = Math.floor(a / 10) * 10, u = a % 10;
  add('mental', 'mult_split', 'Multiplication décomposée', 38, num(`Combien font ${a} × ${b} ?`, a * b,
    `${a} × ${b} = ${t} × ${b} + ${u} × ${b} = ${t * b} + ${u * b} = ${fr(a * b)}.`, `Décompose : ${t} × ${b} + ${u} × ${b}.`));
}
for (let i = 0; i < 3; i++) {
  const a = int(23, 81);
  const s = Math.floor(a / 10) + (a % 10);
  add('mental', 'times_eleven', 'Multiplier par 11', s >= 10 ? 55 : 45, num(`Combien font ${a} × 11 ?`, a * 11,
    `${a} × 11 = ${a} × 10 + ${a} = ${a * 10} + ${a} = ${fr(a * 11)}.`, `${a} × 11, c'est ${a} × 10 + ${a}.`));
}
for (const [base, d] of [[100, 3], [70, 2], [100, 4], [60, 1]]) {
  const x = base - d, y = base + d;
  add('mental', 'diff_squares', 'Produit autour d\'un nombre rond', 65, num(`Combien font ${x} × ${y} ?`, x * y,
    `(${base} − ${d})(${base} + ${d}) = ${base}² − ${d}² = ${fr(base * base)} − ${d * d} = ${fr(x * y)}.`,
    `Ces deux nombres encadrent ${base}.`));
}
for (const n of [35, 45, 65, 85]) {
  const k = Math.floor(n / 10);
  add('mental', 'square_five', 'Carré d\'un nombre en 5', n > 50 ? 60 : 52, num(`Combien vaut ${n}² ?`, n * n,
    `Astuce des nombres en 5 : ${k} × ${k + 1} = ${k * (k + 1)}, puis on écrit 25 : ${fr(n * n)}.`, `${k} × ${k + 1}, suivi de 25.`));
}
for (const [x, d] of [[475, 25], [650, 25], [1250, 50], [360, 15]]) {
  add('mental', 'div_round', 'Division astucieuse', 50, num(`Combien font ${fr(x)} ÷ ${d} ?`, x / d,
    d === 25 ? `Diviser par 25, c'est diviser par 100 puis multiplier par 4 : ${fr(x)} ÷ 100 × 4 = ${fr(x / d)}.`
      : d === 50 ? `Diviser par 50, c'est diviser par 100 puis multiplier par 2 : ${fr(x)} ÷ 100 × 2 = ${fr(x / d)}.`
        : `${x} ÷ 15 = ${x} ÷ 3 ÷ 5 = ${x / 3} ÷ 5 = ${x / d}.`,
    d === 15 ? 'Divise d\'abord par 3, puis par 5.' : `Pense à ${100 / d} × ${d} = 100.`));
}
for (const [a, b] of [[36, 25], [48, 25], [64, 50], [18, 50]]) {
  add('mental', 'times_quarter', 'Multiplier par 25 ou 50', 45, num(`Combien font ${a} × ${b} ?`, a * b,
    `× ${b}, c'est × 100 puis ÷ ${100 / b} : ${a} × 100 = ${fr(a * 100)}, ÷ ${100 / b} = ${fr(a * b)}.`, `Multiplie par 100, puis divise par ${100 / b}.`));
}

// ─────────────── Pourcentages
for (const [p, y] of [[15, 80], [30, 70], [12, 250], [75, 120], [5, 360]]) {
  add('percent', 'of', 'Pourcentage d\'un nombre', p === 12 || p === 5 ? 45 : 35, num(`Combien font ${p} % de ${y} ?`, p * y / 100,
    `${p} % de ${y} = ${y} × ${p} ÷ 100 = ${fr(p * y / 100)}.`, p === 75 ? 'Les trois quarts.' : p === 5 ? 'La moitié de 10 %.' : `Commence par 10 % : ${fr(y / 10)}.`));
}
for (const [price, p] of [[60, 15], [120, 30], [45, 20], [250, 40]]) {
  const r = price * (100 - p) / 100;
  add('percent', 'discount', 'Prix soldé', 40, num(`Un article à ${price} € est soldé à −${p} %. Combien coûte-t-il ?`, r,
    `La remise vaut ${p} % de ${price} = ${fr(price * p / 100)} €. ${price} − ${fr(price * p / 100)} = ${fr(r)} €.`, `Tu paies ${100 - p} % du prix.`, '€'));
}
for (const [price, p] of [[40, 15], [250, 8], [80, 35]]) {
  const r = price * (100 + p) / 100;
  add('percent', 'increase', 'Prix augmenté', 45, num(`Un prix de ${price} € augmente de ${p} %. Quel est le nouveau prix ?`, r,
    `${p} % de ${price} = ${fr(price * p / 100)} €. ${price} + ${fr(price * p / 100)} = ${fr(r)} €.`, `Nouveau prix = ${price} × ${fr((100 + p) / 100)}.`, '€'));
}
for (const [a, b] of [[18, 72], [42, 120], [9, 36], [27, 90]]) {
  add('percent', 'share', 'Quelle part en %', 45, num(`${a} élèves sur ${b} font du sport en club. Quel pourcentage cela représente-t-il ?`, a / b * 100,
    `${a} ÷ ${b} = ${fr(a / b)}, soit ${fr(a / b * 100)} %.`, `Simplifie la fraction ${a}/${b}.`, '%'));
}
for (const [p, r] of [[25, 60], [40, 90], [10, 45]]) {
  const o = r / (1 - p / 100);
  add('percent', 'reverse', 'Retrouver le prix de départ', 68, num(`Après une remise de ${p} %, un article coûte ${r} €. Quel était son prix de départ ?`, o,
    `Le prix payé représente ${100 - p} % du prix de départ : ${r} ÷ ${fr((100 - p) / 100)} = ${fr(o)} €. (Ajouter ${p} % à ${r} € serait faux.)`,
    `${r} €, c'est ${100 - p} % du prix de départ.`, '€'));
}
for (const [a, b] of [[20, 20], [50, 20], [10, 50]]) {
  const f = (1 + a / 100) * (1 - b / 100);
  const pct = Math.round((f - 1) * 1000) / 10;
  add('percent', 'successive', 'Hausse puis baisse', 72, num(`Un prix augmente de ${a} %, puis baisse de ${b} %. Quelle est la variation totale, en % ? (négatif si c'est une baisse)`, pct,
    `× ${fr(1 + a / 100)} puis × ${fr(1 - b / 100)} = × ${fr(Math.round(f * 1000) / 1000)}, soit ${pct > 0 ? '+' : ''}${fr(pct)} %. Les pourcentages ne s'additionnent pas.`,
    'Multiplie les coefficients.', '%'));
}

// ─────────────── Fractions
for (const [a, b, n] of [[3, 5, 40], [2, 7, 63], [5, 8, 96], [4, 9, 72], [7, 10, 130]]) {
  add('fractions', 'of', 'Fraction d\'un nombre', 35, num(`Combien font les ${a}/${b} de ${n} ?`, a * n / b,
    `${n} ÷ ${b} = ${n / b}, puis × ${a} = ${a * n / b}.`, `Divise d'abord par ${b}.`));
}
for (const [a, b, c, d] of [[1, 3, 1, 6], [2, 5, 1, 10], [3, 4, 1, 6], [1, 2, 2, 5]]) {
  const N = a * d + c * b, D = b * d;
  const right = frac(N, D), trap = frac(a + c, b + d);
  const w = [trap, frac(N + 1, D), frac(a * c, b * d)].filter((x) => x !== right);
  if (new Set(w).size < 3) continue;
  add('fractions', 'sum', 'Somme de fractions', 55, mcq(`Combien font ${a}/${b} + ${c}/${d} ?`, right, w,
    `Au même dénominateur ${D} : ${a * d}/${D} + ${c * b}/${D} = ${N}/${D} = ${right}. On n'additionne jamais les dénominateurs.`,
    `Mets les deux fractions sur ${D}.`));
}
for (const [x, f, w] of [[0.75, '3/4', ['7/5', '3/5', '2/3']], [0.6, '3/5', ['6/100', '2/3', '5/6']], [0.125, '1/8', ['1/6', '1/12', '1/25']], [0.35, '7/20', ['3/5', '7/10', '1/35']]]) {
  add('fractions', 'decimal', 'Décimal en fraction', f === '7/20' || f === '1/8' ? 55 : 40, mcq(`Quelle fraction est égale à ${fr(x)} ?`, f, w,
    `${fr(x)} = ${Math.round(x * 1000)}/1 000, qui se simplifie en ${f}.`, `Écris ${fr(x)} sur 100 ou 1 000, puis simplifie.`));
}
for (const [n, k] of [[5, 4], [7, 3], [12, 6]]) {
  add('fractions', 'div', 'Diviser par une fraction', 58, num(`Combien font ${n} ÷ 1/${k} ?`, n * k,
    `Diviser par 1/${k}, c'est multiplier par ${k} : ${n} × ${k} = ${n * k}. (Combien de ${({ 3: 'tiers', 4: 'quarts', 6: 'sixièmes' })[k]} dans ${n} ?)`, `Combien de « 1/${k} » tiennent dans 1 ?`));
}
for (const set of [['5/8', ['3/5', '4/7', '1/2']], ['7/9', ['3/4', '5/7', '2/3']], ['9/11', ['4/5', '7/9', '3/4']]]) {
  add('fractions', 'compare', 'La plus grande fraction', 55, mcq('Quelle est la plus grande de ces fractions ?', set[0], set[1],
    `En décimal : ${[set[0], ...set[1]].map((f) => { const [a, b] = f.split('/').map(Number); return `${f} ≈ ${fr(Math.round(a / b * 1000) / 1000)}`; }).join(' ; ')}.`,
    'Compare l\'écart de chaque fraction à 1.'));
}

// ─────────────── Conversions
for (const [v, u, t, f] of [[3.4, 'km', 'm', 1000], [0.75, 'm', 'cm', 100], [2.3, 'kg', 'g', 1000], [45, 'cl', 'ml', 10], [1.8, 'l', 'cl', 100]]) {
  add('conversions', 'units', 'Conversion d\'unités', 25, num(`Combien de ${t} dans ${fr(v)} ${u} ?`, Math.round(v * f * 1000) / 1000,
    `1 ${u} = ${fr(f)} ${t}, donc ${fr(v)} ${u} = ${fr(Math.round(v * f * 1000) / 1000)} ${t}.`, `1 ${u} = ${fr(f)} ${t}.`, t));
}
for (const m of [150, 195, 84, 255]) {
  const h = m / 60;
  add('conversions', 'hours', 'Minutes en heures', 38, num(`Combien d'heures font ${m} minutes ? (en décimal)`, Math.round(h * 100) / 100,
    `${m} min = ${Math.floor(h)} h ${m % 60} min = ${fr(Math.round(h * 100) / 100)} h (${m % 60} min = ${fr((m % 60) / 60)} h).`, `${m % 60} minutes, c'est quelle fraction d'heure ?`, 'h'));
}
for (const kmh of [54, 72, 90, 18]) {
  add('conversions', 'speed', 'km/h en m/s', 58, num(`${kmh} km/h, cela fait combien de mètres par seconde ?`, kmh / 3.6,
    `${kmh} km/h = ${fr(kmh * 1000)} m en 3 600 s = ${fr(kmh / 3.6)} m/s. Astuce : on divise par 3,6.`, 'Divise par 3,6.', 'm/s'));
}
for (const [v, d] of [[80, 100], [90, 45], [120, 200], [75, 25]]) {
  const min = d / v * 60;
  add('conversions', 'travel', 'Temps de trajet', 50, num(`À ${v} km/h, combien de minutes faut-il pour parcourir ${d} km ?`, min,
    `Temps = distance ÷ vitesse = ${d} ÷ ${v} h = ${fr(Math.round(d / v * 1000) / 1000)} h, soit ${fr(min)} minutes.`, `En 1 minute, on parcourt ${fr(v / 60)} km.`, 'min'));
}
for (const [q, a, e, h] of [
  ['Combien de mètres carrés dans 1 km² ?', 1000000, '1 km² = 1 000 m × 1 000 m = 1 000 000 m².', 'Un carré de 1 000 m de côté.'],
  ['Combien d\'hectares dans 1 km² ?', 100, '1 ha = 10 000 m² et 1 km² = 1 000 000 m², donc 100 ha.', '1 ha = un carré de 100 m de côté.'],
  ['Combien de litres contient un cube de 50 cm de côté ?', 125, '50 cm = 5 dm ; 5 × 5 × 5 = 125 dm³ = 125 litres.', '1 dm³ = 1 litre.'],
  ['Combien de millilitres dans 1 dm³ ?', 1000, '1 dm³ = 1 litre = 1 000 ml.', 'Un litre.'],
]) add('conversions', 'area_volume', 'Aires et volumes', 64, num(q, a, e, h));

// ─────────────── Logique numérique
for (const [a, b] of [[48, 180], [84, 126], [45, 75]]) {
  const g = gcd(a, b);
  add('number_logic', 'gcd', 'Plus grand diviseur commun', 58, num(`Quel est le plus grand diviseur commun de ${a} et ${b} ?`, g,
    `${a} = ${g} × ${a / g} et ${b} = ${g} × ${b / g}, et ${a / g} et ${b / g} n'ont plus de diviseur commun.`, `Essaie de diviser les deux par ${g > 10 ? 'un multiple de ' + (g % 6 === 0 ? 6 : g % 5 === 0 ? 5 : 2) : 2}.`));
}
for (const [a, b] of [[6, 8], [4, 10], [9, 12]]) {
  const l = a * b / gcd(a, b);
  add('number_logic', 'lcm', 'Plus petit multiple commun', 55, num(`Un bus passe toutes les ${a} minutes, un tram toutes les ${b} minutes. Ils partent ensemble à 8 h. Dans combien de minutes repartent-ils ensemble ?`, l,
    `Il faut le plus petit multiple commun de ${a} et ${b} : ${l}.`, `Liste les multiples de ${b}.`, 'min'));
}
for (const n of [50, 20, 40]) {
  add('number_logic', 'gauss', 'Somme des entiers', 60, num(`Combien fait 1 + 2 + 3 + … + ${n} ?`, n * (n + 1) / 2,
    `Astuce de Gauss : on associe 1 et ${n}, 2 et ${n - 1}… ${n / 2} paires valant ${n + 1} : ${n / 2} × ${n + 1} = ${fr(n * (n + 1) / 2)}.`, `Associe le premier et le dernier : 1 + ${n}.`));
}
for (const [k, N] of [[6, 100], [9, 200], [13, 100]]) {
  add('number_logic', 'multiples', 'Compter des multiples', 55, num(`Combien de nombres entre 1 et ${N} sont divisibles par ${k} ?`, Math.floor(N / k),
    `${N} ÷ ${k} = ${fr(Math.round(N / k * 100) / 100)} : on garde la partie entière, ${Math.floor(N / k)} (le dernier est ${Math.floor(N / k) * k}).`, `Calcule ${N} ÷ ${k}.`));
}
for (const n of [6, 8, 10]) {
  add('number_logic', 'handshakes', 'Poignées de main', 65, num(`${n} personnes se serrent toutes la main une fois. Combien de poignées de main en tout ?`, n * (n - 1) / 2,
    `Chacun serre ${n - 1} mains : ${n} × ${n - 1} = ${n * (n - 1)}, mais chaque poignée est comptée deux fois : ${n * (n - 1) / 2}.`, 'Attention à ne pas compter deux fois la même poignée.'));
}
for (const [h, m] of [[9, 0], [2, 30], [4, 0], [7, 30]]) {
  const hand = (h % 12) * 30 + m * 0.5, minute = m * 6;
  let angle = Math.abs(hand - minute); if (angle > 180) angle = 360 - angle;
  add('number_logic', 'clock', 'Angle des aiguilles', m ? 75 : 55, num(`Quel angle (le plus petit) forment les aiguilles d'une horloge à ${h} h${m ? ` ${m}` : ''} ?`, angle,
    `La petite aiguille est à ${fr(hand)}° (30° par heure${m ? ', plus 0,5° par minute' : ''}), la grande à ${minute}°. Écart : ${fr(angle)}°.`,
    m ? 'À la demie, la petite aiguille est entre deux chiffres.' : 'Chaque heure vaut 30°.', '°'));
}
for (const [n, r, w, e] of [
  [2024, 'MMXXIV', ['MMXIV', 'MMXXVI', 'MCMXXIV'], 'MM = 2 000, XX = 20, IV = 4.'],
  [1515, 'MDXV', ['MVXV', 'MDXX', 'MCDXV'], 'M = 1 000, D = 500, X = 10, V = 5.'],
  [49, 'XLIX', ['IL', 'XXXXIX', 'LXIX'], 'XL = 40 et IX = 9 ; « IL » n\'est pas permis (on ne soustrait I qu\'à V et X).'],
]) {
  add('number_logic', 'roman', 'Chiffres romains', n === 49 ? 60 : 50, mcq(`Comment écrit-on ${n} en chiffres romains ?`, r, w,
    `${r} : ${e}`,
    n === 49 ? 'On ne peut soustraire I qu\'à V ou X.' : 'M = 1 000, D = 500, C = 100, L = 50, X = 10, V = 5.'));
}

writeFileSync(new URL('../content/questions/gen_calc.json', import.meta.url), JSON.stringify(out, null, 1) + '\n');
const count = {};
for (const q of out) { const t = q.concept.split('.')[1]; count[t] = (count[t] ?? 0) + 1; }
console.log(`${out.length} questions`, count);
