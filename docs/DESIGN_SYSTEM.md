# Design system — CULT FIVE (direction « Pop », 0.5.0)

## Intention
Joyeux, vif, tactile, qui donne envie en deux secondes de vidéo TikTok. Fond clair, couleurs franches par domaine,
formes très arrondies, gros chiffres, petites animations qui rebondissent. Jamais criard sur les écrans de lecture :
la couleur habille, le texte reste lisible. Pas de carrés, pas d'aplats gris ternes. (Remplace la direction « éditoriale papier/encre » de 0.1–0.4, jugée vieillotte : D-021.)

## Élément signature : le **trait de cinq** (tally mark)
Le « 5 » de CULT FIVE : quatre traits verticaux barrés d'une diagonale. C'est aussi l'icône de l'app (blanc et jaune sur dégradé violet).
- Onglet central : bulle violette qui dépasse de la barre, trait de cinq blanc ; diagonale jaune soleil quand le Daily est disponible ; ensuite, les traits reflètent le résultat (trait plein = juste, trait court et estompé = raté : forme + couleur).
- Carte du jour à l'accueil, résultat, cartes de partage : le trait de cinq *est* le score.
Composant : `TallyMark(strokes:)` / `TallyMark(results:)`, `onInk: true` sur fond coloré.

## Couleurs (tokens, `DesignSystem/Tokens.swift`)
| Token | Clair | Sombre | Usage |
|---|---|---|---|
| `paper` | #F6F5FB | #0E0D16 | fond d'écran (blanc lavande) |
| `paperRaised` | #FFFFFF | #1C1A2A | cartes |
| `ink` | #1A1830 | #F4F3FA | texte |
| `inkSoft` | #6E6B85 | #A3A0B8 | texte secondaire |
| `hairline` | #E9E7F2 | #2C2940 | bordures légères |
| `brand` | #6A4CFF | #8469FF | violet électrique : boutons principaux, onglets actifs |
| `popGradient` | #7B5CFF → #3A1FB8 | idem | moments forts : carte du jour, résultat, onboarding, partage |
| `sun` | #FFD23F | idem | score, surlignage sur violet — toujours avec texte foncé |
| `correct` | #12B76A | #3DDC97 | juste |
| `wrong` | #FF4D5E | #FF6B7A | raté |
| `blush` | #FF8FB1 | idem | joues et langue de Léon, confettis |

**Domaines** (`DomainPalette`) : une couleur vive par domaine + `onColor` (texte blanc, sauf Musique en jaune → texte foncé) + un pictogramme SF Symbols (`symbol`).
Calcul #2F6BFF · Français #F0588F · Géographie #0CA678 · Histoire #F76707 · Sciences #1098AD · Logique #845EF7 · Arts #D6336C · Sport #E5383B · Cinéma #5F3DC4 · Musique #FCC419 · Tech #1C7ED6 · Nature #37B24D.
En question, un voile de la couleur du domaine descend du haut de l'écran ; les réponses, la jauge de progression et le bouton « Continuer » prennent la couleur du domaine.

## Typographie (`Typography.swift`)
SF Pro **Rounded** partout, gras à très gras. Tout en text styles (Dynamic Type).
| Rôle | Style |
|---|---|
| `cfDisplay` | largeTitle, heavy |
| `cfQuestion` / `cfHeadline` | title2, bold |
| `cfTitle3` | title3, bold |
| `cfReading` | body, medium (explications) |
| `cfLabel` (`labelCaps`) | caption, heavy, capitales |
| `numeral(size:)` | arrondi heavy, chiffres à chasse fixe, 40–150 pt |

## Formes et relief
- `Radius` : s 14 · m 20 · l 28. Tout est `continuous`. Aucune forme carrée.
- `popCard()` : carte blanche arrondie, ombre douce teintée violet. Remplace les listes à filets.
- Boutons (`InkButtonStyle`) : pilule pleine, texte heavy centré, ombre colorée, petit liseré plus sombre dessous qui « s'écrase » à l'appui (effet jouet). Variantes : `.ink` (violet), `.sun` (jaune, sur violet), `.inverted` (blanc), `.domain(id)`.
- `TextLinkStyle` : texte gras coloré, sans soulignement.
- `DomainTag` : pilule colorée du domaine, texte blanc.
- `ProgressPills` : progression d'une série (la pilule en cours s'allonge).

## Mouvement (`Motion`)
`press` (ressort court), `standard`, `moment`, `bounce` (rebond franc). Bonne réponse : la pastille passe au vert et grossit un instant ; mauvaise : corail + secousse (`Shake`). Score du résultat qui monte cran par cran. Confettis (`Confetti`) une seule salve : sans-faute, trophée, niveau passé. Tout se réduit à un fondu avec « Réduire les animations ».

## Léon (mascotte, `Leon.swift`)
Caméléon tout rond, grands yeux brillants, joues roses, queue en spirale. Dessiné en code (`Canvas` + `TimelineView`), aucun asset.
- Poses : `rest`, `curious`, `wave` (la queue s'agite), `tongue` (attrape la bonne réponse), `sad` (gris, paupière tombante), `proud` (yeux plissés, étoiles) ; `rainbow` sur un sans-faute.
- `curl` : la queue s'enroule avec la série de jours.
- Respiration, clignements ; `animated: false` pour les rendus d'image (partage).
- **Jamais pendant qu'on répond.** Il apparaît après la réponse (panneau d'explication), à l'accueil (`LeonSays` + bulle), au résultat, dans le bilan, l'onboarding, le profil, les cartes de partage et les états vides.

## Écrans
- **Accueil** : date + pastilles série/graines ; Léon qui parle ; grande carte « 5 du jour » en dégradé violet (trait de cinq, bouton soleil) ; cartes série / erreurs / terrain à conquérir / ligue.
- **Question** : pastille domaine + pilules de progression ; énoncé gros et gras ; réponses en pastilles blanches (lettre dans une bulle colorée) ; Vrai/Faux en deux grandes tuiles ; silhouettes de pays dans une carte blanche ; explication en carte avec Léon.
- **Résultat du Daily** : plein écran dégradé violet, score géant jaune qui monte, Léon (fier / salue / dépité ; arc-en-ciel sur 5/5), chiffres en cartes translucides, célébrations, bouton « Partager » soleil.
- **Jouer** (0.8.1, compact) : titre + cote globale à droite ; grande carte violette « Partie rapide » (éclair et bouton ▶ soleil) ; Surprise / Défi / Erreurs en 3 pastilles teintées sur une ligne (compteur d'erreurs) ; domaines en grille de **3 colonnes**, cases pleines de la couleur du domaine (pictogramme blanc, grand pictogramme en filigrane, nom, cote + rang ou « Placement ●●○○○ 2/5 » ou « à découvrir », ★ pour les centres d'intérêt). 4 rangées au lieu de 6 ; appui long : « Voir mes stats ».
- **Domaine** : bandeau couleur du domaine à coins arrondis, grand pictogramme en filigrane.
- **Profil** : Léon aux couleurs du meilleur domaine, 4 chiffres en cartes, **radar de culture** (`KnowledgeRadar`), domaines en cartes, calendrier, trophées.
- **Onboarding** : premier écran violet, Léon qui salue au centre d'une ronde de domaines.
- **Barre d'onglets** : capsule blanche flottante, icônes qui rebondissent, bulle centrale « 5 du jour ».

## Partage (9:16, 1080×1920)
Trois modèles : Violet, Soleil, Blanc. Trois cartes : résultat du Daily, profil (radar de culture), **question du jour** (sans la réponse, depuis la revue : « Défier mes amis »).

## Accessibilité
Contraste : texte blanc sur les couleurs de domaine (Musique en texte foncé). Juste/raté jamais par la couleur seule (icône ✓/✗, forme du trait). Cibles ≥ 44 pt. Dynamic Type sur tous les textes, chiffres géants plafonnés à ×1,4. Léon et confettis masqués à VoiceOver ou décrits sobrement.
