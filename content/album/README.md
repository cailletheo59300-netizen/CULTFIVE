# Album de cartes : fiches des pages

Un fichier par page de l'album, nommé d'après le sous-thème (`history.middle_ages.json`). Une page = un sous-thème (49 en tout) ; une carte regroupe plusieurs notions du contenu, et **chaque notion du sous-thème appartient à une seule carte**. Répondre juste à n'importe quelle question d'une notion peut donc faire gagner la carte.

Champs d'une carte :

- `n` : numéro dans la page (1, 2, 3…) ; `id` : identifiant stable (`page.nom`).
- `name` : nom affiché ; `phrase` : une ligne qui donne envie d'en savoir plus.
- `figure` et `unit` : le chiffre clé écrit en grand sur la carte (1429, 8 849 m) et sa précision.
- `kind` : composition de l'image — `trait` (sujet au trait), `carte` (contour géographique), `typo` (chiffre ou mot seul).
- `subject` : ce que représente le dessin (drakkar, Saturne et ses anneaux…).
- `rarity` : laissé vide. La rareté se calcule à partir du **taux de réussite réel** des questions de la carte, après le recalibrage de la banque (D-039, D-042), jamais d'après une estimation.
- `concepts` : les notions (`concept` des questions) rangées dans la carte.

`to_move` liste les notions rangées dans le mauvais sous-thème, à déplacer dans le contenu.

Vérification : `node scripts/check-album.mjs` (chaque notion rangée une seule fois, aucune notion inconnue).
