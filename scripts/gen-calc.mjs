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

let keyPrefix = 'gcalc';

function add(theme, family, label, difficulty, q) {
  if (seenPrompts.has(q.prompt)) return;
  seenPrompts.add(q.prompt);
  const n = id++;
  out.push({ key: `${keyPrefix}-${String(n).padStart(3, '0')}`, concept: `calc.${theme}.gen_${family}_${n}`, label: `${label} (${n})`,
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
const diffSquares = (list) => { for (const [base, d] of list) {
  const x = base - d, y = base + d;
  add('mental', 'diff_squares', 'Produit autour d\'un nombre rond', 65, num(`Combien font ${x} × ${y} ?`, x * y,
    `(${base} − ${d})(${base} + ${d}) = ${base}² − ${d}² = ${fr(base * base)} − ${d * d} = ${fr(x * y)}.`,
    `Ces deux nombres encadrent ${base}.`));
} };
diffSquares([[100, 3], [70, 2], [100, 4], [60, 1]]);
const squareFive = (list) => { for (const n of list) {
  const k = Math.floor(n / 10);
  add('mental', 'square_five', 'Carré d\'un nombre en 5', n > 50 ? 60 : 52, num(`Combien vaut ${n}² ?`, n * n,
    `Astuce des nombres en 5 : ${k} × ${k + 1} = ${k * (k + 1)}, puis on écrit 25 : ${fr(n * n)}.`, `${k} × ${k + 1}, suivi de 25.`));
} };
squareFive([35, 45, 65, 85]);
const divRound = (list) => { for (const [x, d] of list) {
  add('mental', 'div_round', 'Division astucieuse', 50, num(`Combien font ${fr(x)} ÷ ${d} ?`, x / d,
    d === 25 ? `Diviser par 25, c'est diviser par 100 puis multiplier par 4 : ${fr(x)} ÷ 100 × 4 = ${fr(x / d)}.`
      : d === 50 ? `Diviser par 50, c'est diviser par 100 puis multiplier par 2 : ${fr(x)} ÷ 100 × 2 = ${fr(x / d)}.`
        : `${x} ÷ 15 = ${x} ÷ 3 ÷ 5 = ${x / 3} ÷ 5 = ${x / d}.`,
    d === 15 ? 'Divise d\'abord par 3, puis par 5.' : `Pense à ${100 / d} × ${d} = 100.`));
} };
divRound([[475, 25], [650, 25], [1250, 50], [360, 15]]);
const timesQuarter = (list) => { for (const [a, b] of list) {
  add('mental', 'times_quarter', 'Multiplier par 25 ou 50', 45, num(`Combien font ${a} × ${b} ?`, a * b,
    `× ${b}, c'est × 100 puis ÷ ${100 / b} : ${a} × 100 = ${fr(a * 100)}, ÷ ${100 / b} = ${fr(a * b)}.`, `Multiplie par 100, puis divise par ${100 / b}.`));
} };
timesQuarter([[36, 25], [48, 25], [64, 50], [18, 50]]);

// ─────────────── Pourcentages
const percentOf = (list) => { for (const [p, y] of list) {
  add('percent', 'of', 'Pourcentage d\'un nombre', p === 12 || p === 5 ? 45 : 35, num(`Combien font ${p} % de ${y} ?`, p * y / 100,
    `${p} % de ${y} = ${y} × ${p} ÷ 100 = ${fr(p * y / 100)}.`, p === 75 ? 'Les trois quarts.' : p === 5 ? 'La moitié de 10 %.' : `Commence par 10 % : ${fr(y / 10)}.`));
} };
percentOf([[15, 80], [30, 70], [12, 250], [75, 120], [5, 360]]);
const discount = (list) => { for (const [price, p] of list) {
  const r = price * (100 - p) / 100;
  add('percent', 'discount', 'Prix soldé', 40, num(`Un article à ${price} € est soldé à −${p} %. Combien coûte-t-il ?`, r,
    `La remise vaut ${p} % de ${price} = ${fr(price * p / 100)} €. ${price} − ${fr(price * p / 100)} = ${fr(r)} €.`, `Tu paies ${100 - p} % du prix.`, '€'));
} };
discount([[60, 15], [120, 30], [45, 20], [250, 40]]);
const increase = (list) => { for (const [price, p] of list) {
  const r = price * (100 + p) / 100;
  add('percent', 'increase', 'Prix augmenté', 45, num(`Un prix de ${price} € augmente de ${p} %. Quel est le nouveau prix ?`, r,
    `${p} % de ${price} = ${fr(price * p / 100)} €. ${price} + ${fr(price * p / 100)} = ${fr(r)} €.`, `Nouveau prix = ${price} × ${fr((100 + p) / 100)}.`, '€'));
} };
increase([[40, 15], [250, 8], [80, 35]]);
const share = (list) => { for (const [a, b] of list) {
  add('percent', 'share', 'Quelle part en %', 45, num(`${a} élèves sur ${b} font du sport en club. Quel pourcentage cela représente-t-il ?`, a / b * 100,
    `${a} ÷ ${b} = ${fr(a / b)}, soit ${fr(a / b * 100)} %.`, `Simplifie la fraction ${a}/${b}.`, '%'));
} };
share([[18, 72], [42, 120], [9, 36], [27, 90]]);
const reversePrice = (list) => { for (const [p, r] of list) {
  const o = r / (1 - p / 100);
  add('percent', 'reverse', 'Retrouver le prix de départ', 68, num(`Après une remise de ${p} %, un article coûte ${r} €. Quel était son prix de départ ?`, o,
    `Le prix payé représente ${100 - p} % du prix de départ : ${r} ÷ ${fr((100 - p) / 100)} = ${fr(o)} €. (Ajouter ${p} % à ${r} € serait faux.)`,
    `${r} €, c'est ${100 - p} % du prix de départ.`, '€'));
} };
reversePrice([[25, 60], [40, 90], [10, 45]]);
const successive = (list) => { for (const [a, b] of list) {
  const f = (1 + a / 100) * (1 - b / 100);
  const pct = Math.round((f - 1) * 1000) / 10;
  add('percent', 'successive', 'Hausse puis baisse', 72, num(`Un prix augmente de ${a} %, puis baisse de ${b} %. Quelle est la variation totale, en % ? (négatif si c'est une baisse)`, pct,
    `× ${fr(1 + a / 100)} puis × ${fr(1 - b / 100)} = × ${fr(Math.round(f * 1000) / 1000)}, soit ${pct > 0 ? '+' : ''}${fr(pct)} %. Les pourcentages ne s'additionnent pas.`,
    'Multiplie les coefficients.', '%'));
} };
successive([[20, 20], [50, 20], [10, 50]]);

// ─────────────── Fractions
const fractionOf = (list) => { for (const [a, b, n] of list) {
  add('fractions', 'of', 'Fraction d\'un nombre', 35, num(`Combien font les ${a}/${b} de ${n} ?`, a * n / b,
    `${n} ÷ ${b} = ${n / b}, puis × ${a} = ${a * n / b}.`, `Divise d'abord par ${b}.`));
} };
fractionOf([[3, 5, 40], [2, 7, 63], [5, 8, 96], [4, 9, 72], [7, 10, 130]]);
const fractionSum = (list) => { for (const [a, b, c, d] of list) {
  const N = a * d + c * b, D = b * d;
  const right = frac(N, D), trap = frac(a + c, b + d);
  const w = [trap, frac(N + 1, D), frac(a * c, b * d)].filter((x) => x !== right);
  if (new Set(w).size < 3) continue;
  add('fractions', 'sum', 'Somme de fractions', 55, mcq(`Combien font ${a}/${b} + ${c}/${d} ?`, right, w,
    `Au même dénominateur ${D} : ${a * d}/${D} + ${c * b}/${D} = ${N}/${D} = ${right}. On n'additionne jamais les dénominateurs.`,
    `Mets les deux fractions sur ${D}.`));
} };
fractionSum([[1, 3, 1, 6], [2, 5, 1, 10], [3, 4, 1, 6], [1, 2, 2, 5]]);
const decimalToFraction = (list) => { for (const [x, f, w] of list) {
  add('fractions', 'decimal', 'Décimal en fraction', f === '7/20' || f === '1/8' ? 55 : 40, mcq(`Quelle fraction est égale à ${fr(x)} ?`, f, w,
    `${fr(x)} = ${Math.round(x * 1000)}/1 000, qui se simplifie en ${f}.`, `Écris ${fr(x)} sur 100 ou 1 000, puis simplifie.`));
} };
decimalToFraction([[0.75, '3/4', ['7/5', '3/5', '2/3']], [0.6, '3/5', ['6/100', '2/3', '5/6']], [0.125, '1/8', ['1/6', '1/12', '1/25']], [0.35, '7/20', ['3/5', '7/10', '1/35']]]);
const divideByFraction = (list) => { for (const [n, k] of list) {
  add('fractions', 'div', 'Diviser par une fraction', 58, num(`Combien font ${n} ÷ 1/${k} ?`, n * k,
    `Diviser par 1/${k}, c'est multiplier par ${k} : ${n} × ${k} = ${n * k}. (Combien de ${({ 2: 'demis', 3: 'tiers', 4: 'quarts', 5: 'cinquièmes', 6: 'sixièmes' })[k]} dans ${n} ?)`, `Combien de « 1/${k} » tiennent dans 1 ?`));
} };
divideByFraction([[5, 4], [7, 3], [12, 6]]);
const compareFractions = (list) => { for (const set of list) {
  add('fractions', 'compare', 'La plus grande fraction', 55, mcq('Quelle est la plus grande de ces fractions ?', set[0], set[1],
    `En décimal : ${[set[0], ...set[1]].map((f) => { const [a, b] = f.split('/').map(Number); return `${f} ≈ ${fr(Math.round(a / b * 1000) / 1000)}`; }).join(' ; ')}.`,
    'Compare l\'écart de chaque fraction à 1.'));
} };
compareFractions([['5/8', ['3/5', '4/7', '1/2']], ['7/9', ['3/4', '5/7', '2/3']], ['9/11', ['4/5', '7/9', '3/4']]]);

const simplifyFraction = (list) => { for (const [a, b, r, w] of list) {
  add('fractions', 'simplify', 'Fraction irréductible', 50, mcq(`Quelle est la forme irréductible de ${a}/${b} ?`, r, w,
    `On divise haut et bas par ${gcd(a, b)} : ${a}/${b} = ${r}. Les autres fractions valent la même chose sans être simplifiées au bout, ou valent autre chose.`,
    `Cherche le plus grand diviseur commun de ${a} et ${b}.`));
} };
simplifyFraction([[24, 36, '2/3', ['4/6', '3/4', '8/12']], [45, 60, '3/4', ['9/12', '5/6', '15/20']], [28, 42, '2/3', ['4/7', '7/12', '14/21']]]);

// ─────────────── Conversions
const units = (list) => { for (const [v, u, t, f] of list) {
  add('conversions', 'units', 'Conversion d\'unités', 25, num(`Combien de ${t} dans ${fr(v)} ${u} ?`, Math.round(v * f * 1000) / 1000,
    `1 ${u} = ${fr(f)} ${t}, donc ${fr(v)} ${u} = ${fr(Math.round(v * f * 1000) / 1000)} ${t}.`, `1 ${u} = ${fr(f)} ${t}.`, t));
} };
units([[3.4, 'km', 'm', 1000], [0.75, 'm', 'cm', 100], [2.3, 'kg', 'g', 1000], [45, 'cl', 'ml', 10], [1.8, 'l', 'cl', 100]]);
const minutesToHours = (list) => { for (const m of list) {
  const h = m / 60;
  add('conversions', 'hours', 'Minutes en heures', 38, num(`Combien d'heures font ${m} minutes ? (en décimal)`, Math.round(h * 100) / 100,
    `${m} min = ${Math.floor(h)} h ${m % 60} min = ${fr(Math.round(h * 100) / 100)} h (${m % 60} min = ${fr((m % 60) / 60)} h).`, `${m % 60} minutes, c'est quelle fraction d'heure ?`, 'h'));
} };
minutesToHours([150, 195, 84, 255]);
const kmhToMs = (list) => { for (const kmh of list) {
  add('conversions', 'speed', 'km/h en m/s', 58, num(`${kmh} km/h, cela fait combien de mètres par seconde ?`, kmh / 3.6,
    `${kmh} km/h = ${fr(kmh * 1000)} m en 3 600 s = ${fr(kmh / 3.6)} m/s. Astuce : on divise par 3,6.`, 'Divise par 3,6.', 'm/s'));
} };
kmhToMs([54, 72, 90, 18]);
const travelTime = (list) => { for (const [v, d] of list) {
  const min = d / v * 60;
  add('conversions', 'travel', 'Temps de trajet', 50, num(`À ${v} km/h, combien de minutes faut-il pour parcourir ${d} km ?`, min,
    `Temps = distance ÷ vitesse = ${d} ÷ ${v} h = ${fr(Math.round(d / v * 1000) / 1000)} h, soit ${fr(min)} minutes.`, `En 1 minute, on parcourt ${fr(v / 60)} km.`, 'min'));
} };
travelTime([[80, 100], [90, 45], [120, 200], [75, 25]]);
const areaVolume = (list) => { for (const [q, a, e, h] of list) add('conversions', 'area_volume', 'Aires et volumes', 64, num(q, a, e, h)); };
areaVolume([
  ['Combien de mètres carrés dans 1 km² ?', 1000000, '1 km² = 1 000 m × 1 000 m = 1 000 000 m².', 'Un carré de 1 000 m de côté.'],
  ['Combien d\'hectares dans 1 km² ?', 100, '1 ha = 10 000 m² et 1 km² = 1 000 000 m², donc 100 ha.', '1 ha = un carré de 100 m de côté.'],
  ['Combien de litres contient un cube de 50 cm de côté ?', 125, '50 cm = 5 dm ; 5 × 5 × 5 = 125 dm³ = 125 litres.', '1 dm³ = 1 litre.'],
  ['Combien de millilitres dans 1 dm³ ?', 1000, '1 dm³ = 1 litre = 1 000 ml.', 'Un litre.'],
]);

const durations = (list) => { for (const [q, v, e, h] of list) add('conversions', 'time', 'Conversion de durées', 45, num(q, v, e, h)); };
durations([
  ['Combien de secondes font 1 h 15 min ?', 4500, '1 h 15 = 75 minutes, et 75 × 60 = 4 500 secondes.', '1 heure = 3 600 secondes.'],
  ['Combien de minutes compte une semaine ?', 10080, '7 × 24 × 60 = 10 080 minutes.', '7 jours de 1 440 minutes.'],
]);

// ─────────────── Logique numérique
const gcdOf = (list) => { for (const [a, b] of list) {
  const g = gcd(a, b);
  add('number_logic', 'gcd', 'Plus grand diviseur commun', 58, num(`Quel est le plus grand diviseur commun de ${a} et ${b} ?`, g,
    `${a} = ${g} × ${a / g} et ${b} = ${g} × ${b / g}, et ${a / g} et ${b / g} n'ont plus de diviseur commun.`, `Essaie de diviser les deux par ${g > 10 ? 'un multiple de ' + (g % 6 === 0 ? 6 : g % 5 === 0 ? 5 : 2) : 2}.`));
} };
gcdOf([[48, 180], [84, 126], [45, 75]]);
const lcmOf = (list) => { for (const [a, b] of list) {
  const l = a * b / gcd(a, b);
  add('number_logic', 'lcm', 'Plus petit multiple commun', 55, num(`Un bus passe toutes les ${a} minutes, un tram toutes les ${b} minutes. Ils partent ensemble à 8 h. Dans combien de minutes repartent-ils ensemble ?`, l,
    `Il faut le plus petit multiple commun de ${a} et ${b} : ${l}.`, `Liste les multiples de ${b}.`, 'min'));
} };
lcmOf([[6, 8], [4, 10], [9, 12]]);
const gaussSum = (list) => { for (const n of list) {
  add('number_logic', 'gauss', 'Somme des entiers', 60, num(`Combien fait 1 + 2 + 3 + … + ${n} ?`, n * (n + 1) / 2,
    `Astuce de Gauss : on associe 1 et ${n}, 2 et ${n - 1}… ${n / 2} paires valant ${n + 1} : ${n / 2} × ${n + 1} = ${fr(n * (n + 1) / 2)}.`, `Associe le premier et le dernier : 1 + ${n}.`));
} };
gaussSum([50, 20, 40]);
const countMultiples = (list) => { for (const [k, N] of list) {
  add('number_logic', 'multiples', 'Compter des multiples', 55, num(`Combien de nombres entre 1 et ${N} sont divisibles par ${k} ?`, Math.floor(N / k),
    `${N} ÷ ${k} = ${fr(Math.round(N / k * 100) / 100)} : on garde la partie entière, ${Math.floor(N / k)} (le dernier est ${Math.floor(N / k) * k}).`, `Calcule ${N} ÷ ${k}.`));
} };
countMultiples([[6, 100], [9, 200], [13, 100]]);
const handshakes = (list) => { for (const n of list) {
  add('number_logic', 'handshakes', 'Poignées de main', 65, num(`${n} personnes se serrent toutes la main une fois. Combien de poignées de main en tout ?`, n * (n - 1) / 2,
    `Chacun serre ${n - 1} mains : ${n} × ${n - 1} = ${n * (n - 1)}, mais chaque poignée est comptée deux fois : ${n * (n - 1) / 2}.`, 'Attention à ne pas compter deux fois la même poignée.'));
} };
handshakes([6, 8, 10]);
const clockAngle = (list) => { for (const [h, m] of list) {
  const hand = (h % 12) * 30 + m * 0.5, minute = m * 6;
  let angle = Math.abs(hand - minute); if (angle > 180) angle = 360 - angle;
  add('number_logic', 'clock', 'Angle des aiguilles', m ? 75 : 55, num(`Quel angle (le plus petit) forment les aiguilles d'une horloge à ${h} h${m ? ` ${m}` : ''} ?`, angle,
    `La petite aiguille est à ${fr(hand)}° (30° par heure${m ? ', plus 0,5° par minute' : ''}), la grande à ${minute}°. Écart : ${fr(angle)}°.`,
    m ? 'À la demie, la petite aiguille est entre deux chiffres.' : 'Chaque heure vaut 30°.', '°'));
} };
clockAngle([[9, 0], [2, 30], [4, 0], [7, 30]]);
const roman = (list) => { for (const [n, r, w, e] of list) {
  add('number_logic', 'roman', 'Chiffres romains', n === 49 ? 60 : 50, mcq(`Comment écrit-on ${n} en chiffres romains ?`, r, w,
    `${r} : ${e}`,
    n === 49 ? 'On ne peut soustraire I qu\'à V ou X.' : 'M = 1 000, D = 500, C = 100, L = 50, X = 10, V = 5.'));
} };
roman([
  [2024, 'MMXXIV', ['MMXIV', 'MMXXVI', 'MCMXXIV'], 'MM = 2 000, XX = 20, IV = 4.'],
  [1515, 'MDXV', ['MVXV', 'MDXX', 'MCDXV'], 'M = 1 000, D = 500, X = 10, V = 5.'],
  [49, 'XLIX', ['IL', 'XXXXIX', 'LXIX'], 'XL = 40 et IX = 9 ; « IL » n\'est pas permis (on ne soustrait I qu\'à V et X).'],
]);

// ─────────────── Extension 0.9.4 (clés gcalb-*) : nouvelles valeurs pour les modèles ci-dessus et nouveaux modèles.
// La première série (gcalc-*) reste strictement identique.
keyPrefix = 'gcalb';

// Calcul mental
diffSquares([[80, 2], [40, 3], [90, 1], [200, 5], [30, 4]]);
squareFive([55, 75, 95, 105]);
divRound([[725, 25], [1100, 25], [1750, 50], [480, 15], [2250, 50]]);
timesQuarter([[28, 25], [44, 25], [86, 50], [124, 25], [38, 50]]);
for (const [a, b] of [[398, 257], [499, 376], [1998, 745], [697, 288], [299, 468]]) {
  const r = Math.ceil(a / 100) * 100, d = r - a;
  add('mental', 'add_round', 'Addition autour d\'un nombre rond', 35, num(`Combien font ${fr(a)} + ${b} ?`, a + b,
    `${fr(a)} = ${fr(r)} − ${d} : ${fr(r)} + ${b} = ${fr(r + b)}, puis − ${d} = ${fr(a + b)}.`, `${fr(a)}, c'est ${fr(r)} − ${d}.`));
}
for (const [a, b] of [[1000, 423], [500, 178], [2000, 1234], [1000, 58]]) {
  add('mental', 'sub_round', 'Soustraction depuis un nombre rond', 40, num(`Combien font ${fr(a)} − ${fr(b)} ?`, a - b,
    `On complète ${fr(b)} jusqu'à ${fr(a)} : ${fr(b)} + ${fr(a - b)} = ${fr(a)}.`, `Combien faut-il ajouter à ${fr(b)} pour atteindre ${fr(a)} ?`));
}
for (const a of [16, 24, 32, 48, 56]) {
  add('mental', 'times_eighth', 'Multiplier par 125', 55, num(`Combien font ${a} × 125 ?`, a * 125,
    `125 = 1 000 ÷ 8 : ${a} ÷ 8 = ${a / 8}, puis × 1 000 = ${fr(a * 125)}.`, '125, c\'est 1 000 divisé par 8.'));
}
for (const [a, k] of [[47, 9], [68, 9], [83, 99], [56, 99], [34, 999]]) {
  const t = k + 1;
  add('mental', 'times_nines', 'Multiplier par 9, 99, 999', k === 9 ? 40 : 55, num(`Combien font ${a} × ${k} ?`, a * k,
    `${a} × ${k} = ${a} × ${fr(t)} − ${a} = ${fr(a * t)} − ${a} = ${fr(a * k)}.`, `${k} = ${fr(t)} − 1.`));
}
for (const [a, b] of [[25, 52], [15, 14], [45, 22], [35, 18]]) {
  const h = a % 5 === 0 && b % 2 === 0;
  add('mental', 'double_halve', 'Doubler et diviser par deux', 45, num(`Combien font ${a} × ${b} ?`, a * b,
    `On double l'un et on divise l'autre par 2 : ${a * 2} × ${b / 2} = ${fr(a * b)}.`, h ? `Double ${a}, divise ${b} par 2.` : 'Double l\'un, divise l\'autre par 2.'));
}

// Pourcentages
percentOf([[20, 85], [25, 160], [40, 35], [60, 45], [35, 300], [2, 450], [150, 40]]);
discount([[80, 25], [35, 20], [150, 15], [90, 10]]);
increase([[60, 5], [120, 25], [500, 12]]);
share([[12, 48], [35, 140], [14, 56], [33, 110]]);
reversePrice([[20, 48], [50, 35], [30, 56]]);
successive([[30, 30], [25, 20], [10, 10]]);
for (const [x, p] of [[15, 20], [36, 30], [18, 12], [45, 75], [9, 15]]) {
  add('percent', 'base', 'Retrouver le total', 55, num(`${x} représente ${p} % d'un nombre. Quel est ce nombre ?`, x * 100 / p,
    `Si ${p} % valent ${x}, 1 % vaut ${fr(Math.round(x / p * 1000) / 1000)} et 100 % valent ${fr(x * 100 / p)}.`, `Cherche d'abord ce que vaut 1 %.`));
}
for (const [a, b] of [[80, 100], [50, 65], [200, 150], [40, 30], [120, 150], [25, 40]]) {
  const v = Math.round((b - a) / a * 1000) / 10;
  add('percent', 'evolution', 'Taux d\'évolution', 55, num(`Un prix passe de ${a} € à ${b} €. De quel pourcentage a-t-il varié ? (négatif si c'est une baisse)`, v,
    `Variation = (${b} − ${a}) ÷ ${a} = ${(b - a) < 0 ? '−' : ''}${fr(Math.abs(b - a))} ÷ ${a} = ${(b - a) < 0 ? '−' : ''}${fr(Math.abs(Math.round((b - a) / a * 1000) / 1000))}, soit ${v > 0 ? '+' : '−'}${fr(Math.abs(v))} %. On divise toujours par la valeur de départ.`,
    `Divise l'écart par la valeur de départ, ${a}.`, '%'));
}
for (const ht of [75, 35, 120, 8.5]) {
  add('percent', 'vat', 'Prix TTC', 42, num(`Un article coûte ${fr(ht)} € hors taxes. Quel est son prix avec 20 % de TVA ?`, Math.round(ht * 1.2 * 100) / 100,
    `20 % de ${fr(ht)} = ${fr(Math.round(ht * 0.2 * 100) / 100)} €. ${fr(ht)} + ${fr(Math.round(ht * 0.2 * 100) / 100)} = ${fr(Math.round(ht * 1.2 * 100) / 100)} €.`, 'Multiplie par 1,2.', '€'));
}

// Fractions
fractionOf([[2, 3, 45], [3, 8, 64], [5, 6, 54], [3, 10, 250], [4, 5, 35], [7, 12, 84]]);
fractionSum([[1, 4, 1, 3], [2, 3, 1, 4], [1, 5, 3, 10], [5, 6, 1, 4]]);
decimalToFraction([[0.25, '1/4', ['2/5', '1/25', '4/10']], [0.45, '9/20', ['4/5', '9/10', '45/10']], [0.875, '7/8', ['8/7', '7/9', '5/6']], [0.4, '2/5', ['4/100', '1/4', '5/2']]]);
divideByFraction([[3, 5], [8, 4], [9, 2], [10, 3]]);
compareFractions([['4/5', ['3/4', '5/7', '2/3']], ['11/12', ['9/10', '5/6', '7/8']], ['3/7', ['2/5', '1/3', '3/8']]]);
simplifyFraction([[21, 28, '3/4', ['6/8', '7/9', '9/12']], [35, 49, '5/7', ['7/9', '5/8', '15/21']], [16, 40, '2/5', ['4/10', '1/4', '8/20']], [27, 72, '3/8', ['9/24', '1/3', '3/7']]]);
for (const [a, b] of [[3, 4], [2, 5], [7, 20], [1, 8], [3, 25], [9, 10]]) {
  add('fractions', 'to_percent', 'Fraction en pourcentage', b === 8 || b === 20 ? 50 : 35, num(`Combien vaut ${a}/${b} en pourcentage ?`, a * 100 / b,
    `${a}/${b} = ${fr(a / b)} = ${fr(a * 100 / b)} %.${100 % b === 0 ? ` (On multiplie haut et bas par ${100 / b} : ${a * 100 / b}/100.)` : ''}`, `Écris la fraction sur 100 si tu peux.`, '%'));
}
for (const [a, b, c, d] of [[4, 7, 7, 8], [5, 9, 3, 10], [2, 5, 5, 8], [3, 4, 8, 9]]) {
  const r = frac(a * c, b * d);
  const w = [frac(a + c, b + d), frac(a * d, b * c), frac(a * c + 1, b * d)].filter((x) => x !== r);
  if (new Set(w).size < 3) continue;
  add('fractions', 'product', 'Produit de fractions', 50, mcq(`Combien font ${a}/${b} × ${c}/${d} ?`, r, w,
    `On multiplie les numérateurs entre eux et les dénominateurs entre eux : ${a * c}/${b * d} = ${r}.`, 'Haut × haut, bas × bas, puis simplifie.'));
}

// Conversions
units([[0.6, 'km', 'm', 1000], [4.5, 'm', 'mm', 1000], [2.75, 'l', 'cl', 100], [0.8, 'kg', 'g', 1000], [12, 'cm', 'mm', 10], [3.2, 't', 'kg', 1000]]);
minutesToHours([90, 135, 210, 45, 270]);
kmhToMs([162, 108, 126, 144]);
travelTime([[60, 75], [100, 150], [50, 20], [120, 90], [80, 20]]);
areaVolume([
  ['Combien de centimètres carrés dans 1 m² ?', 10000, '1 m² = 100 cm × 100 cm = 10 000 cm².', 'Un carré de 100 cm de côté.'],
  ['Combien de litres dans 1 m³ ?', 1000, '1 m³ = 10 × 10 × 10 dm³ = 1 000 dm³ = 1 000 litres.', '1 m = 10 dm.'],
  ['Combien de mètres carrés mesure 1 hectare ?', 10000, '1 ha = 100 m × 100 m = 10 000 m².', 'Un carré de 100 m de côté.'],
  ['Combien de mètres cubes font 5 000 litres ?', 5, '1 m³ = 1 000 litres, donc 5 000 litres = 5 m³.', '1 m³ = 1 000 litres.'],
]);
durations([
  ['Combien de secondes font 10 minutes ?', 600, '10 × 60 = 600 secondes.', '1 minute = 60 secondes.'],
  ['Combien d\'heures compte une semaine ?', 168, '7 × 24 = 168 heures.', '7 jours de 24 heures.'],
  ['Combien de minutes font 2 h 45 ?', 165, '2 × 60 + 45 = 165 minutes.', '2 heures = 120 minutes.'],
  ['Combien de jours compte une année bissextile ?', 366, 'Une année bissextile a un 29 février en plus : 366 jours.', 'Elle a un 29 février.'],
]);
for (const [price, g] of [[2.4, 750], [3.6, 250], [12, 1500], [8, 125], [4.5, 200]]) {
  const r = Math.round(price * g / 1000 * 100) / 100;
  add('conversions', 'unit_price', 'Prix au kilo', 45, num(`Un produit coûte ${fr(price)} € le kilo. Combien coûtent ${fr(g)} g ?`, r,
    `${fr(g)} g = ${fr(g / 1000)} kg ; ${fr(price)} × ${fr(g / 1000)} = ${fr(r)} €.`, `${fr(g)} g, c'est quelle fraction du kilo ?`, '€'));
}

// Logique numérique
gcdOf([[42, 70], [56, 98], [72, 120]]);
lcmOf([[4, 6], [8, 12], [5, 15], [10, 15]]);
gaussSum([10, 30, 60, 80]);
countMultiples([[7, 150], [8, 150], [11, 200], [12, 500]]);
handshakes([4, 7, 12, 20]);
clockAngle([[3, 0], [6, 0], [1, 0], [3, 30], [10, 30]]);
roman([
  [1999, 'MCMXCIX', ['MIM', 'MCMIC', 'MDCCCCXCIX'], 'M = 1 000, CM = 900, XC = 90, IX = 9.'],
  [2026, 'MMXXVI', ['MMXXIV', 'MMXVI', 'MMXXXVI'], 'MM = 2 000, XX = 20, VI = 6.'],
  [90, 'XC', ['LXXXX', 'XXC', 'CX'], 'XC = 100 − 10 ; on n\'écrit pas quatre X à la suite.'],
  [444, 'CDXLIV', ['CCCCXLIV', 'CDXLVI', 'DXLIV'], 'CD = 400, XL = 40, IV = 4.'],
]);
for (const [x, y, s] of [[3, 5, 'somme 8, différence 2'], [7, 4, 'somme 11, différence 3'], [12, 9, 'somme 21, différence 3']]) {
  add('number_logic', 'sum_diff', 'Somme et différence', 60, num(`Deux nombres ont pour ${s}. Quel est le plus grand ?`, Math.max(x, y),
    `Le plus grand = (somme + différence) ÷ 2 = (${x + y} + ${Math.abs(x - y)}) ÷ 2 = ${Math.max(x, y)}.`, 'Ajoute la somme et la différence, puis divise par 2.'));
}
for (const [n, d] of [[7, 3], [10, 4], [15, 2]]) {
  add('number_logic', 'fence', 'Piquets de clôture', 58, num(`On plante un piquet tous les ${d} m le long d'une allée droite de ${n * d} m, avec un piquet à chaque bout. Combien de piquets ?`, n + 1,
    `${n * d} ÷ ${d} = ${n} intervalles, donc ${n + 1} piquets : il y a toujours un piquet de plus que d'intervalles.`, 'Compte les intervalles, puis ajoute 1.'));
}

writeFileSync(new URL('../content/questions/gen_calc.json', import.meta.url), JSON.stringify(out, null, 1) + '\n');
const count = {};
for (const q of out) { const t = q.concept.split('.')[1]; count[t] = (count[t] ?? 0) + 1; }
console.log(`${out.length} questions`, count);
