# Écho : les règles et les réglages

Ce document explique le jeu tel qu'il est codé, et où changer chaque chiffre.
Tous les chiffres du jeu sont dans **un seul fichier** : `echo/Packages/EchoCore/Sources/EchoCore/Tuning.swift`.

## Le principe
**Chaque manche que tu joues devient un fantôme qui rejoue tes gestes dans les manches suivantes. Ne le touche pas.**

## Une partie
1. **Le départ** : le point est au centre et rien ne bouge. La manche commence au premier geste du doigt.
2. **Le geste** : le point suit le *mouvement* du doigt, pas sa position. On peut donc jouer n'importe où sur l'écran, et le doigt ne cache jamais le point.
   - **Sans retard** : le geste est appliqué tout de suite. Le point ne continue jamais à glisser après le doigt.
   - **Accélération douce**, comme une souris : doigt lent, le point suit exactement ; doigt rapide, il va jusqu'à 1,5 à 2,4 fois plus loin.
   - Le réglage « Précis ↔ Rapide » (au milieu par défaut) choisit la force de cette accélération. Les Réglages ont une zone d'essai.
   - Un coup de doigt extrême est raccourci (120 unités par image au plus) : le point ne se téléporte pas.
3. **Les orbes** : 3 par manche, 4 à partir de la manche 10, 5 à partir de la manche 18, l'un après l'autre. L'orbe à attraper brille. Le suivant est un cercle discret, pour qu'on puisse prévoir son trajet.
4. **Fin de manche** : une courte pause (0,75 s), puis le point revient au centre. Le trajet que tu viens de faire devient un fantôme.
5. **Les fantômes** :
   - Ils rejouent la manche enregistrée, image par image, en partant du centre en même temps que toi.
   - Pendant les 0,75 premières secondes, ils sont transparents et inoffensifs, le temps de quitter le centre.
   - Quand leur enregistrement est fini, ils repartent en arrière, puis en avant… (aller-retour) : ils ne disparaissent jamais. Attendre dans un coin ne sert donc à rien.
   - Seul le **point** du fantôme tue, pas sa traînée. La zone de contact est réduite à 75 % : un frôlement visuel ne tue pas.
   - **Les échos s'effacent** : un fantôme vit 4 manches. Pendant sa dernière manche, il pâlit et clignote doucement, puis il disparaît. Il y a donc au plus 4 fantômes à l'écran : un bon joueur peut aller très loin.
   - À partir de la manche 5, ils rejouent un peu plus vite (+5 % par manche, ×1,8 au maximum).
6. **Fin de partie** : toucher un fantôme.

## Les points
| Action | Points |
|---|---|
| Orbe attrapé | 10 |
| Manche finie | 20 |
| Rapidité | jusqu'à 30 (1 point par 0,2 s gagnée sous 6 s) |
| Frôler un fantôme sans le toucher | 5 |

**Le multiplicateur** : chaque frôlement le fait monter (×2, ×3… ×5 au plus). Il multiplie les orbes et la fin de manche. Une manche finie sans aucun frôlement le remet à ×1. Il s'affiche sous le score.

Les **pièces** d'une partie valent le score divisé par 8 (une partie moyenne en rapporte environ 25). Elles sont doublées avec la pub « Pièces ×2 ».

## Les deux modes
- **Classique** : des orbes différents à chaque partie. Ton meilleur score part dans le classement Game Center « Meilleur score ».
- **Défi du jour** :
  - les mêmes orbes pour tout le monde, tirés de la date ;
  - un jour va de minuit à minuit en heure universelle (UTC), soit 1 h ou 2 h du matin en France ;
  - 1 essai gratuit, et jusqu'à 2 essais en plus avec une pub ;
  - pas de « Continuer » (c'est plus juste pour le classement) ;
  - le meilleur score du jour part dans le classement Game Center « Défi du jour » ;
  - la **série** compte les jours d'affilée où tu as joué le défi. Le premier essai du jour rapporte 20 pièces par jour de série (140 au plus).

## Les pubs
**Récompensées**, toujours au choix du joueur :
- **Continuer** : le fantôme qui t'a touché disparaît pour de bon et la manche recommence. Une fois par partie, en classique seulement. Les points de la manche ratée ne sont pas comptés deux fois.
- **Pièces ×2** à la fin de la partie.
- **Réessayer** le défi du jour (2 fois par jour au plus).

**Entre les parties** : quand on quitte l'écran de fin (Rejouer ou Accueil), si toutes ces conditions sont vraies :
- pas d'achat « Sans pub » ;
- pas pendant les 24 premières heures après l'installation ;
- au moins 3 parties depuis la dernière pub, et au moins 90 secondes ;
- pas de pub récompensée regardée pendant la partie.

Ces règles sont dans `AdPacing.swift`. Le consentement (RGPD puis demande de suivi d'Apple) est demandé après la première partie, pas au tout premier lancement.

## La boutique
Tout s'achète directement, sans hasard.

**Traînées** (le point du joueur) :
| Nom | Prix |
|---|---|
| Écho | gratuit |
| Menthe | 200 pièces |
| Corail | 300 pièces |
| Or | 500 pièces |
| Glace | 700 pièces |
| Arc-en-ciel | 1 200 pièces |
| Feu | 1,99 € |
| Galaxie | 1,99 € |

**Décors** (fond, fantômes, orbes) :
| Nom | Prix |
|---|---|
| Nuit | gratuit |
| Océan | 400 pièces |
| Forêt | 600 pièces |
| Encre | 900 pièces |
| Synthwave | 1,99 € |

**Offres** :
| Offre | Prix conseillé |
|---|---|
| Sans pub | 3,99 € |
| Pack de départ (Sans pub + Feu + Galaxie + Synthwave) | 4,99 € |
| 600 pièces | 0,99 € |
| 2 000 pièces | 2,99 € |
| 8 000 pièces | 9,99 € |

Les prix en euros se règlent dans App Store Connect. Les prix en pièces et les couleurs sont dans `Catalog.swift` : une nouvelle apparence = une ligne.

## Régler la sensation de jeu
Les valeurs à tester en premier sur TestFlight, toutes dans `Tuning.swift` :

| Si… | Changer… |
|---|---|
| Le jeu est trop dur au début | `ghostArmTicks` (plus grand = fantômes inoffensifs plus longtemps), `hitboxFactor` (plus petit = contact plus tolérant) |
| Les parties sont trop longues | `ghostLifetime` (plus grand = plus de fantômes à l'écran), `speedUpFromRound`, `speedUpPerRound`, `extraOrbRounds` |
| Les parties sont trop courtes | `ghostLifetime` plus petit, `maxGhostRate` plus petit |
| Le point est trop lent ou trop rapide | `pointerGain` (accélération), `slowFingerSpeed` / `fastFingerSpeed`, ou `controlSetting` par défaut dans `Profile.swift` |
| Le multiplicateur monte trop vite | `maxMultiplier`, `nearMissMargin` (plus petit = frôlement plus exigeant) |
| Les orbes sont trop proches ou trop loin | `orbMinSpacing`, `orbMinFromCenter` |

⚠️ Changer un réglage change aussi le défi du jour : il faut le faire avant la sortie, ou accepter que deux versions de l'app n'aient pas tout à fait le même défi le jour de la mise à jour.

## L'écran de fin
Il s'affiche vite (0,35 s après l'explosion). En mode classique, toucher n'importe où en dehors de la carte relance une partie, après 0,9 s, pour qu'un doigt encore posé ne relance pas par erreur.

## Ce qui n'est pas encore là (prévu plus tard)
- Orbe Gomme (rare, efface le fantôme le plus ancien).
- Niveau du joueur avec récompenses, record affiché pendant la partie.
- Missions quotidiennes (« Frôle 10 fantômes »…).
- Pass mensuel.
- Pub récompensée « Essayer une apparence ».
- Sauvegarde iCloud des pièces : pour l'instant, la progression reste sur le téléphone. Les achats en euros, eux, se restaurent toujours.
- Version Android.
