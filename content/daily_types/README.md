# Nouveaux types de réponses (5 du jour)

Questions prêtes pour les nouveaux types validés (maquette v2). **Pas encore lues par l'app ni par `build-seed.mjs`** : elles n'ont aucun effet sur la base ni sur la version en test. À brancher après la publication de la 1.0 (voir `docs/IMPLEMENTATION_STATUS.md`, partie B).

## Fichiers

| Fichier | Type | Contenu |
|---|---|---|
| `new_counter.json` | `counter` | Compteur : nouvelles questions |
| `new_timeline.json` | `timeline` | Frise : nouvelles questions |
| `new_gauge.json` | `gauge` | Jauge de pourcentage |
| `new_proportion.json` | `proportion` | Proportions (étirer à la vraie taille) |
| `new_letters.json` | `letters` | Lettres mélangées |
| `new_word_order.json` | `word_order` | Mots dans l'ordre |
| `new_flags.json` | `image_choice` (`kind: flag`) | Drapeaux « jumeaux » |
| `new_paintings.json` | `image_choice` (`kind: painting`) | Tableaux du domaine public |
| `conv_timeline.json` | `timeline` | Conversions d'anciennes questions (années) |
| `conv_flags.json` | `image_choice` | Conversions des questions drapeaux (on montre 4 drapeaux, on cherche le pays) |
| `conv_counter.json` | `counter` | Conversions des petits nombres |

`from` : clé de la question classique d'origine (conversions). Le concept reste le même, pour ne pas poser les deux versions le même jour.

## Champs communs

`key`, `concept` (`domaine.sous_domaine.slug`), `label`, `type`, `difficulty` (0–100), `prompt`, `explanation`.

## Par type

- **counter** : `answer` (entier), `tolerance` (0 = « nombre exact », sinon marge ±), `min`, `max`, `start`, `unit` (facultatif).
- **timeline** : `answer` (année), `tolerance` (± années : 3 après 1900, 5 de 1500 à 1899, 10 de 1000 à 1499, 20 avant), `min`, `max` (bornes de la frise ; la bonne année n'est jamais au centre). Années négatives = avant J.-C. (afficher « 44 av. J.-C. »).
- **gauge** : `answer` (%), `tolerance` (± points), `unit: "%"`.
- **proportion** : `reference` `{label, size, icon}`, `item` `{label, icon}`, `answer` (vraie taille, même unité), `tolerance` (fraction : 0,15 = ± 15 %), `dimension`, `unit`, `max` (fin du curseur).
- **letters** : `word` (tuiles, majuscules sans accents), `display` (mot affiché à la correction), indice dans `prompt`.
- **word_order** : `answer` (phrase complète), `words` (tuiles dans le bon ordre, à mélanger). Certains mots se répètent (« un pour tous ») : comparer le texte, pas l'identité des tuiles.
- **image_choice** : 4 `options`, une seule avec `correct: true`.
  - `kind: flag` : `flag` = code ISO à 2 lettres (drapeaux dessinés dans l'app), `label` pour les conversions.
  - `kind: painting` : `title`, `artist`, `year`, `image` (à remplir : reproduction du domaine public, Wikimedia Commons ; tous les peintres sont morts depuis plus de 70 ans).

## Règles de jeu (rappel)

Toujours juste ou faux. Marge annoncée avant de répondre (🎯) et zone visée affichée en direct. Correction : « Pile ! » (+5 graines), « Juste, dans la marge », « Presque… hors de la marge », « Raté », avec la bonne réponse, la réponse donnée et l'écart.
