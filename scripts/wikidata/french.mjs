// Formes françaises des noms de pays : article, « de », préposition de lieu.
// Règles générales + exceptions explicites (relues à la main). Aucune question n'est publiée sans relecture.

// Pas d'article (îles, cités-États) : « Cuba », « de Cuba », « à Cuba ».
const NO_ARTICLE = new Map([
  ['Cuba', 'à'], ['Chypre', 'à'], ['Malte', 'à'], ['Madagascar', 'à'], ['Singapour', 'à'], ['Monaco', 'à'],
  ['Haïti', 'en'], ['Oman', 'à'], ['Bahreïn', 'à'], ['Djibouti', 'à'], ['Nauru', 'à'], ['Saint-Marin', 'à'],
  ['Sao Tomé-et-Principe', 'à'], ['Maurice', 'à'], ['Trinité-et-Tobago', 'à'], ['Saint-Christophe-et-Niévès', 'à'],
  ['Sainte-Lucie', 'à'], ['Saint-Vincent-et-les-Grenadines', 'à'], ['Antigua-et-Barbuda', 'à'], ['Israël', 'en'],
  ['Brunei', 'à'],
]);

/** Noms usuels à la place des noms officiels de Wikidata. */
export const DISPLAY = new Map([
  ['Royaume des Pays-Bas', 'Pays-Bas'], ['république populaire de Chine', 'Chine'],
  ['États fédérés de Micronésie', 'Micronésie'], ['Vietnam', 'Viêt Nam'],
]);

/** Pays exclus des questions (statut politique discuté ou données ambiguës). */
export const EXCLUDED_COUNTRIES = new Set(['Taïwan']);

/** Préposition de lieu particulière : « à la Barbade ». */
const IN_OVERRIDE = new Map([['Barbade', 'à la Barbade'], ['Grenade', 'à la Grenade'], ['Dominique', 'à la Dominique']]);
const OF_OVERRIDE = new Map([['Haïti', "d'Haïti"]]);

// Pluriels : « les États-Unis », « des États-Unis », « aux États-Unis ».
const PLURAL = new Set(['États-Unis', 'Pays-Bas', 'Émirats arabes unis', 'Philippines', 'Comores', 'Maldives', 'Seychelles',
  'Fidji', 'Îles Marshall', 'Îles Salomon', 'Bahamas', 'Palaos', 'Samoa', 'Tonga', 'Tuvalu', 'Kiribati']);

// Masculins qui finissent par -e (ou dont le premier mot finit par -e).
const MASCULINE = new Set(['Mexique', 'Cambodge', 'Mozambique', 'Zimbabwe', 'Belize', 'Suriname', 'Royaume-Uni', 'Libéria']);
// Féminins qui ne finissent pas par -e.
const FEMININE = new Set(['Sierra Leone']);

const VOWEL = /^[AEIOUÉÈÊÎÏÔÂaeiouéèêîïôâ]/;

export function countryForms(name) {
  const forms = baseForms(name);
  if (IN_OVERRIDE.has(name)) forms.in = IN_OVERRIDE.get(name);
  if (OF_OVERRIDE.has(name)) forms.of = OF_OVERRIDE.get(name);
  return forms;
}

function baseForms(name) {
  if (PLURAL.has(name) && !NO_ARTICLE.has(name)) {
    return { the: `les ${name}`, of: `des ${name}`, in: `aux ${name}`, gender: 'p' };
  }
  if (NO_ARTICLE.has(name)) {
    const prep = NO_ARTICLE.get(name);
    return { the: name, of: VOWEL.test(name) ? `d'${name}` : `de ${name}`, in: `${prep} ${name}`, gender: 'n' };
  }
  const first = name.split(/[ -]/)[0];
  const feminine = FEMININE.has(name) || (!MASCULINE.has(name) && !MASCULINE.has(first) && first.endsWith('e'));
  if (VOWEL.test(name)) {
    return { the: `l'${name}`, of: `de l'${name}`, in: `en ${name}`, gender: feminine ? 'f' : 'm' };
  }
  return feminine
    ? { the: `la ${name}`, of: `de la ${name}`, in: `en ${name}`, gender: 'f' }
    : { the: `le ${name}`, of: `du ${name}`, in: `au ${name}`, gender: 'm' };
}

/** « de l'oxygène », « du fer » — pour les noms communs en minuscules. */
export function partitiveOf(noun) {
  return /^[aeiouyéèêhîô]/i.test(noun) ? `de l'${noun}` : `du ${noun}`;
}

export function centuryLabel(year) {
  const c = Math.floor((year - 1) / 100) + 1;
  return `${roman(c)}e siècle`;
}

export function roman(n) {
  const table = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'],
    [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']];
  let out = '';
  for (const [v, s] of table) while (n >= v) { out += s; n -= v; }
  return out;
}

const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/** Date Wikidata (« 1815-06-18T00:00:00Z ») → « 18 juin 1815 ». Les dates du 1er janvier sont souvent des années seules. */
export function frenchDate(iso) {
  const m = /^(-?\d+)-(\d\d)-(\d\d)/.exec(iso);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  if (mo === 1 && d === 1) return `${y}`;
  return `${d === 1 ? '1er' : d} ${MONTHS[mo - 1]} ${y}`;
}

export function yearOf(iso) {
  const m = /^(-?\d+)-/.exec(iso ?? '');
  return m ? Number(m[1]) : null;
}

/** Nombre arrondi lisible : 68 400 000 → « 68 millions », 1 430 000 000 → « 1,4 milliard ». */
export function roundedPopulation(n) {
  if (n >= 1e9) return `${(n / 1e9).toFixed(1).replace('.', ',').replace(',0', '')} milliard${n >= 2e9 ? 's' : ''}`;
  if (n >= 1e7) return `${Math.round(n / 1e6)} millions`;
  if (n >= 1e6) return `${(n / 1e6).toFixed(1).replace('.', ',').replace(',0', '')} million${n >= 2e6 ? 's' : ''}`;
  return `${Math.round(n / 1000) * 1000}`.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

export function slug(text) {
  return text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40);
}
