# Lumiligne : les règles et les réglages

Ce document explique le jeu tel qu'il est codé, et où changer chaque chiffre.

## Les 3 règles
Une grille carrée de N × N cases est découpée en N zones de couleur, numérotées de 1 à N.
1. **Une gemme par zone.**
2. **Les numéros qui se suivent sont alignés** : la gemme 1 est sur la même ligne ou la même colonne que la 2, la 2 avec la 3, et ainsi de suite (la N n'a pas besoin d'être alignée avec la 1).
3. **Deux gemmes ne se touchent jamais**, même en diagonale.

Code : `Layout.swift` (`conflict`, `blocked`).

## Les gestes
- Un appui : croix. Deux appuis : gemme. Trois : la case se vide.
- Glisser le doigt : croix sur toutes les cases vides traversées (une seule étape d'« Annuler »).
- **Croix automatiques** (réglage, activé par défaut) : les cases exclues par une gemme sont barrées en pâle.
- Une gemme qui enfreint une règle devient rouge, tremble, et la raison s'affiche sous la grille.
- Quand deux gemmes qui se suivent sont bien placées, le rayon les relie. Grille finie : le rayon parcourt toute la chaîne.

## Comment les grilles sont fabriquées
Aucune grille n'est faite à la main (`Generator.swift`) :
1. une chaîne de gemmes tirée au hasard, qui respecte les règles ;
2. une zone grandit autour de chaque gemme (au moins 2 cases par zone) ;
3. tant qu'il existe une autre solution, une case passe dans une zone voisine pour la casser ;
4. le solveur (`Solver.swift`) résout la grille **par déduction seule**, sinon elle est jetée ;
5. on recommence jusqu'à la difficulté demandée.

**Les déductions du solveur** (ce sont aussi les indices) :

| Niveau | Déduction | Points de difficulté |
|---|---|---|
| 0 | Une zone n'a plus qu'une case possible / cases exclues par une gemme posée | 0 |
| 2 | Où que tu mettes la gemme d'une zone, ces cases sont exclues | 1 |
| 3 | Une gemme ici ne laisserait aucune place à une autre zone | 2 |
| 4 | Une gemme ici mène à une impasse quelques coups plus loin | 6 |

Le score d'une grille est la somme des points. Facile, moyen ou difficile dépend du score et de la taille (`Difficulty.bounds`). Environ 1 grille sur 4 est facile, 1 sur 2 moyenne, 1 sur 4 difficile.

La même graine donne toujours la même grille, sur tous les iPhone : c'est ce qui rend la grille du jour identique pour tout le monde, sans serveur.

## Les grilles

| Sorte | Taille et difficulté | Code |
|---|---|---|
| **Niveaux** (dans l'ordre, sans fin) | 5 × 5 jusqu'au niveau 10, 6 × 6 jusqu'au 35, 7 × 7 jusqu'au 80, 8 × 8 jusqu'au 150, puis 9 × 9. Les 5 premiers faciles, puis un cycle facile, moyen, moyen, difficile. | `Puzzles.levelSize`, `levelDifficulty` |
| **Grille du jour** (la même pour tous, de minuit à minuit UTC) | lundi 6 × 6 moyen, mardi 6 × 6 difficile, mercredi 7 × 7 moyen, jeudi et vendredi 7 × 7 difficile, samedi 8 × 8 moyen, dimanche 8 × 8 difficile | `Puzzles.plan` |
| **Grille bonus** (après la grille du jour, avec une pub, 1 par jour) | 8 × 8 difficile | `Puzzles.plan` |

Une grille commencée est gardée : on la reprend là où on l'avait laissée (chronomètre compris).

## Les indices (la seule monnaie)
Tous les chiffres sont dans `Economy.swift`.

| Comment | Indices |
|---|---|
| Au premier lancement | 3 |
| Grille du jour finie (1 fois par jour) | 1, et 3 de plus tous les 7 jours de série |
| Tous les 5 niveaux finis | 1 |
| Grille bonus finie | 1 |
| Une pub récompensée | 1 (5 fois par jour au plus) |
| Achats | 10, 30 ou 100 ; 30 dans le pack de départ |

Un indice corrige d'abord une erreur (gemme mal placée, croix en trop), sinon il explique et applique la prochaine déduction. Montrer une règle enfreinte (gemme rouge) est gratuit.

**Grille du jour** : le temps envoyé au classement compte **+30 s par indice utilisé**. La **série** compte les jours d'affilée où la grille du jour a été finie.

## Les thèmes

| Thème | Comment l'avoir |
|---|---|
| Aube (clair) | gratuit, par défaut |
| Nuit (sombre) | gratuit |
| Menthe | niveau 15 |
| Corail | niveau 40 |
| Océan | niveau 80 |
| **Néon** | 1,99 € (ou pack de départ) |
| **Aurore** | 1,99 € (ou pack de départ) |

Un nouveau thème = une entrée dans `Catalog.swift` (couleurs + prix). Les couleurs des zones restent distinctes en luminosité ; le réglage **Symboles dans les zones** ajoute un symbole par zone (daltonisme), en plus des numéros.

## Les pubs
**Récompensées**, toujours au choix du joueur : un indice en plus, la grille bonus du jour.

**Entre les grilles** : quand on quitte l'écran de victoire, si toutes ces conditions sont vraies (`AdPacing` dans `Economy.swift`) :
- pas d'achat « Sans pub » (ni pack de départ) ;
- pas pendant les 24 premières heures après l'installation ;
- au moins 3 grilles finies depuis la dernière pub, et au moins 2 minutes ;
- pas de pub récompensée regardée pendant la grille.

Jamais de pub pendant une grille. Le consentement (RGPD puis demande de suivi d'Apple) est demandé après la première grille finie.

## La boutique
Tout s'achète directement, sans hasard. Pas de mur de paiement : tout le jeu (niveaux sans fin, grille du jour, grille bonus) se joue gratuitement.

| Offre | Prix conseillé |
|---|---|
| Pack de départ (Sans pub + 30 indices + Néon + Aurore) | 4,99 € |
| Sans pub | 3,99 € |
| Thème Néon / Aurore | 1,99 € |
| 10 / 30 / 100 indices | 0,99 € / 1,99 € / 4,99 € |

## ⚠️ Changer un réglage
Changer le générateur, le solveur, les bornes de difficulté ou `Puzzles.swift` change les grilles de tout le monde (niveaux et grille du jour). À faire avant la sortie, ou en acceptant que deux versions de l'app n'aient pas la même grille du jour le jour de la mise à jour.
