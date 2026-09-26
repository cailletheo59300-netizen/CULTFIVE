# Design system — CULT FIVE

## Intention
Éditorial, chaud, tactile, mature. Un magazine de culture qui se touche. Beaucoup de papier, de l'encre, une seule couleur vive. Pas de cartes empilées, pas de dégradés, pas de glassmorphism, pas d'icônes « IA ».

## Élément signature : le **trait de cinq** (tally mark)
Le « 5 » de CULT FIVE est dessiné comme une marque de comptage : quatre traits verticaux barrés d'une diagonale.
- Onglet central : le trait de cinq, sur pastille d'encre. Quand le Daily est disponible, la diagonale est en chlorophylle ; une fois terminé, les traits reflètent le résultat (traits pleins = bonnes réponses, trait court et estompé = raté (forme + couleur)).
- Progression dans le Daily : chaque question remplit un trait.
- Résultat et cartes de partage : le trait de cinq *est* le score.
Composant : `TallyMark(results:, style:)`.

## Couleurs (tokens, `DesignSystem/Tokens.swift`)
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `paper` | #F5F1E8 | #14120F | fond principal |
| `paperRaised` | #FFFDF8 | #1E1B17 | zones surélevées (rares) |
| `ink` | #16140F | #F2EDE3 | texte, pastilles fortes |
| `inkSoft` | #5E574C | #A39B8D | texte secondaire |
| `hairline` | #E3DCCD | #2E2A24 | filets de séparation |
| `chloro` | #C6F432 | #C6F432 | couleur de marque — **uniquement sur fond encre** ou comme aplat avec texte encre |
| `correct` | #1E7A4C | #5BC48A | juste (+ icône ✓ + mot « Juste ») |
| `wrong` | #B8382A | #F07A6A | raté (+ icône ✕ + mot « Raté ») |

Couleurs de domaine (aplats sobres, jamais en dégradé) — la couleur n'envahit l'écran qu'**à l'intérieur** d'un domaine (entraînement, stats) :
Calcul #2F4BD8 · Français #8E2A43 · Géographie #C8612F · Histoire #B8872B · Sciences #1F6F78 · Logique #4A4E57 · Arts & culture #C0567E · Sport #3B8B3F · Cinéma #5B3A6E · Musique #34357A · Technologie #3F6E9A · Nature #6C7F2E.

Règle : l'information n'est jamais portée par la couleur seule (icône + mot).

## Typographie
- **Display / questions** : New York (`Font.system(.., design: .serif)`) — la voix éditoriale.
- **Interface** : SF Pro (`.default`).
- **Chiffres** : SF Pro `monospacedDigit()` ; scores géants en New York Bold.
- **Étiquettes** : SF Pro semibold, petites capitales simulées (`.uppercased()` + tracking 1,2).
Tous les styles passent par `Typography.swift` et s'appuient sur les text styles (Dynamic Type).

| Style | Base | Taille (Large) |
|---|---|---|
| `display` | serif bold | 44 (largeTitle scaled) |
| `question` | serif medium | 28 (title) |
| `headline` | serif semibold | 22 |
| `body` | sans regular | 17 |
| `label` | sans semibold, caps, tracking | 12 |
| `numeral` | serif bold, mono digits | 64–160 |

## Espacements & formes
Grille de 4 : `xs 4 · s 8 · m 16 · l 24 · xl 40 · xxl 64`. Marges latérales 20.
Rayons : 6 (boutons de réponse), 14 (sheets internes), 999 (pastilles). Pas d'ombres portées sauf l'onglet central (ombre douce unique).

## Composants
- `AnswerRow` : ligne pleine largeur, lettre-clé (A B C D) en New York, filet en dessous ; pressé = aplat encre, texte papier ; résultat = icône + mot.
- `NumericKeypad` : pavé interne 3×4, touches sans bordure sur papier, retour haptique léger, virgule locale.
- `InkButton` : bouton primaire = texte + flèche sur aplat encre, pas de CTA géant arrondi.
- `TextLink` : action secondaire soulignée.
- `DomainTag` : pastille de couleur + libellé en capitales.
- `SkillBar` : barre fine (2 pt) + chiffre ; zone d'incertitude en hachures claires.
- `TallyMark`.
- `Léon` (mascotte) : caméléon vectoriel dessiné en `Shape` SwiftUI, 3 poses (repos, curieux, fier). Prend la couleur du domaine. Apparitions rares.

## Mouvement & haptique
- Durées : 0,18 s (press), 0,28 s (transition), 0,6 s max (moment résultat). Ressorts amortis, jamais de rebond cartoon.
- `accessibilityReduceMotion` → fondus uniquement.
- Haptique : `.selection` au choix, `.success` / `.error` au verdict, `.impact(.soft)` au pavé.

## Compositions par écran (chacun a sa forme)
- **Accueil / 5 du jour** : papier ; salut en serif ; le trait de cinq en grand, décentré à gauche ; « Ton rendez-vous est prêt. » ; une seule action. En dessous, une colonne éditoriale (pas de cartes) : série, erreurs à revoir, ligue — séparées par des filets.
- **Question** : concentration. Rien d'autre que catégorie (petite), progression (trait), question (grande), réponses.
- **Explication** : bande de verdict pleine largeur (icône + mot), bonne réponse en gras, « Pourquoi ? », « À retenir » en marge avec filet vertical de la couleur du domaine.
- **Résultat** : plein écran encre. Score géant en chlorophylle, trait de cinq, TOP %, temps, série. XP/graines en ligne discrète. Partager / Revoir / Continuer.
- **Jouer** : exploration — liste typographique des domaines (grands titres serif colorés), pas de grille de tuiles.
- **Profil** : portrait — Léon, pseudo, puis « Ce que tu sais » : barres de niveau par domaine façon sommaire de magazine.
- **Amis** : conversation — liste de personnes avec leur trait de cinq du jour.
