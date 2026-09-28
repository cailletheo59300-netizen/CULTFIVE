# Adaptation de la difficulté — modèle et choix

## Choix : modèle de Rasch (IRT 1PL) avec mise à jour bayésienne approchée façon Glicko
Chaque **utilisateur** a, par domaine et par sous-domaine, une compétence `μ` et une incertitude `σ²`.
Chaque **question** a une difficulté `b` et une incertitude `σ_b²`.
Les deux vivent sur la même échelle affichée 0–100 (50 = moyen).

Échelle : `S = 10` points par logit. Un écart de 10 points ⇒ 73 % de chances de réussite.

### Probabilité de réussite
```
g(v)  = 1 / sqrt(1 + 3·v / (π²·S²))          # atténuation par l'incertitude de l'adversaire
E     = 1 / (1 + exp(-g(σ_b²)·(μ − b) / S))   # probabilité attendue de bonne réponse
```

### Mise à jour après une réponse (y = 1 si correcte, 0 sinon)
Approximation de Laplace du postérieur (équivalent à Glicko-1) :
```
I       = g²·E·(1−E) / S²          # information apportée par cette réponse
σ²_new  = 1 / (1/σ² + I)
μ_new   = μ + σ²_new · g · (y − E) / S
```
Symétriquement pour la question (avec `E_q = 1 − E`, et `g(σ²_user)` : les réponses d'utilisateurs encore mal estimés pèsent moins).

### Pourquoi
- Elo pur : pas de notion de confiance → soit trop lent au début, soit instable ensuite.
- IRT complet (2PL/3PL, estimation MLE/EAP par lots) : plus précis mais demande beaucoup de données et un calcul hors-ligne ; prématuré en V1.
- Rasch + mise à jour bayésienne en ligne : une seule formule, symétrique utilisateurs/questions, calculable en O(1) dans une transaction SQL, confiance native via `σ²`. Évolutif vers une recalibration IRT par lots quand le volume le justifiera.

### Garde-fous (exigences du cahier des charges)
| Règle | Valeur |
|---|---|
| Prior utilisateur (domaine) | μ₀ selon le choix d'onboarding : Découverte 38 · Équilibre 50 · Challenge 60 · Expert 70 ; σ₀ = 10 |
| Prior sous-domaine | μ du domaine au moment de la création, σ = max(σ_domaine, 8) |
| Variation max par réponse | ±4 points |
| Plancher d'incertitude | σ ≥ 3 (le niveau reste capable d'évoluer) |
| Réinflation | σ² += 0,5/jour d'inactivité dans le domaine, plafonné à σ₀² |
| Prior question | b₀ = difficulté initiale ; σ_b = 10 (humaine), 12 (IA) |
| Plancher question | σ_b ≥ 2 |
| Plage effective | `b_effective = clamp(b_observed, min, max)` ; E se calcule avec `b_effective` |
| Élargissement de plage | seulement si n ≥ 300 réponses **et** `b_observed` hors plage de plus de 2σ_b : la borne bouge de 5 points, au plus une fois par tranche de 100 réponses |
| Question à revoir (admin) | n ≥ 50 et taux de réussite < 5 % ou > 99 %, ou élargissement demandé 3 fois |

Premières réponses d'un nouvel utilisateur (σ=10, E=0,5) : ≈ +4 points pour une bonne réponse, puis ≈ +3,5, +3… ; une question très facile réussie ne rapporte presque rien. Après ~30 réponses, σ ≈ 4 : une réponse bouge le niveau de ~1 point.

> Réglage (session 1) : σ₀ = 12 et ±6 donnaient +6 dès la première réponse difficile réussie — jugé trop brutal. Ramené à σ₀ = 10, ±4.

## Fiabilité affichée
`fiabilité = 1 − σ/σ₀` ∈ [0,1], affichée en mots : « à affiner » (<0,35), « correcte » (<0,65), « solide ».

## Sélection des questions (Jouer, Défi, Erreurs)
Pour chaque question à servir, on tire une **fenêtre de cote** autour de celle du joueur (0.8.1) : on ne vise pas un
pourcentage, on sert des questions qui correspondent à la cote, et la réussite en découle. Écart = cote de la question − cote
du joueur ; chances = 1 / (1 + 10^(écart/400)).
| Fenêtre | Proba | Écart de cote | Chances |
|---|---|---|---|
| Un peu en dessous | 50 % | −250 à −75 | 60–81 % |
| À ton niveau | 30 % | −100 à +25 | 46–64 % |
| Accessibles | 15 % | −400 à −250 | 81–91 % |
| Au-dessus | 5 % | +25 à +175 | 27–46 % |
Mode Défi : 60 % de −50 à +100, 25 % de +100 à +250, 15 % de −150 à −50 (≈ 45 %).
Réussite mesurée par simulation (4 domaines × 3 niveaux, 9 parties après placement) : **65 %** en moyenne. Elle varie selon
la banque (44–80 %) : un domaine qui manque de questions faciles ou difficiles pour un niveau donné élargit sa fenêtre.
(0.8.0 visait 55 % ; avant, ~70 % avec 20 % de questions « de consolidation » trop faciles.)
Conversion : `b = μ − S·ln(E/(1−E))`. Filtres : statut `published`, concept non vu depuis 3 jours (7 jours si réussi), pas deux fois le même concept dans une série, questions des Daily présents/futurs exclues. Si la bande est vide, élargissement progressif (±5 puis ±10) puis n'importe quelle question du filtre.

Chaque question du pack porte `difficulty` et `expected` (chances estimées pour ce joueur). L'app en tire une pastille
(Facile ≥ 0,70 · Moyen ≥ 0,50 · Difficile ≥ 0,35 · Très difficile) et un **ordre adaptatif** dans la partie : après 3 bonnes
réponses d'affilée, la question restante la plus dure passe devant ; après 2 erreurs, la plus accessible.

## Hasard, thèmes, révisions (0.8.2, migration 0016)
- **Hasard** (modèle à 3 paramètres, c fixé) : P(juste) = c + (1 − c) · logistique, c = 1/n pour un QCM ou une carte à n choix,
  1/2 pour un Vrai/Faux, 0 pour numérique, ordre, paires (`questions.guess_rate`). Mise à jour : information de Fisher et pas de
  Newton de la vraisemblance à 3 paramètres (c = 0 redonne exactement l'ancien modèle). Une bonne réponse devinable fait moins
  monter, une erreur devinable fait plus baisser ; la calibration des questions suit la même règle. La fenêtre de sélection
  vise des **chances réelles** (hasard compris), question par question (`_b_for_p`).
- **Thèmes équilibrés** : chaque question d'une partie de domaine tire d'abord un thème (le moins servi dans la partie, léger
  bonus aux thèmes où la cote est la moins sûre), puis la question dans la fenêtre du niveau de ce thème. Partie de 10 en
  Géographie : 2 questions par thème. Quand un petit thème est épuisé (anti-répétition), on complète dans tout le domaine.
- **Révision espacée** : une erreur revient après 1 j ; une fois corrigée, à 3 j, 7 j puis 21 j ; maîtrisée à la 4e bonne
  réponse « à l'heure » (réussir avant l'échéance ne fait pas avancer). Une révision due est glissée dans les parties
  adaptatives du domaine (au plus une, jamais en 1re question) et dans « Mes erreurs ».
- Simulation (joueurs qui devinent quand ils ne savent pas, 4 domaines × 3 niveaux, 14 parties) : réussite **66 %**,
  écart moyen entre niveau estimé et vrai niveau **1,8 point** (≈ 31 points de cote).

## Elo (0.8.0, ex-« Cote CULT »)
Lecture du niveau μ sur une échelle façon échecs : **cote = 1000 + 17,37 × (μ − 50)** (17,37 = 400 / (S · ln 10) : 400 points
d'écart = 10 contre 1). 1000 = niveau médian ; μ ∈ [0, 100] → cote ∈ [131, 1869].
| Rang | Cote |
|---|---|
| Curieux | < 900 |
| Amateur | 900–1049 |
| Éclairé | 1050–1199 |
| Érudit | 1200–1349 |
| Expert | 1350–1499 |
| Encyclopédie | ≥ 1500 |
- **Placement** : tant qu'un domaine a moins de 50 réponses classées (≈ 5 parties), la cote est cachée (« Placement 2/5 ») et le pas
  maximal par réponse est doublé (±8 au lieu de ±4) pour converger vite. Un thème est placé dès 15 réponses.
- **Cote globale** : moyenne des domaines pondérée par le nombre de réponses (calculée dans l'app), placée dès 50 réponses.
- **Points de partie** (bonne réponse seulement) : 50 + 100 × (1 − E) + bonus de vitesse (≤ 30 sous 15 s ; rien sous 0,8 s).
  Une question « à 30 % » juste et rapide ≈ 150 pts. Même formule côté serveur (`_attempt_points`) et app (`GamePoints`).
- `play_submit` renvoie `points` et `ratings` (cote avant/après par domaine, placement).
- **Simulation** (`supabase/tests/70_rating.sql`) : trois joueurs de vrai niveau 30, 50 et 72 jouent 8 parties classées ; ils
  répondent juste avec la probabilité du modèle. Résultat : μ 28,6 / 50,1 / 71,3 (cotes 627 / 1002 / 1370), ordre respecté,
  et le joueur moyen réussit 52 % de ses questions après placement.

## Calibrage initial du contenu
`node scripts/build-seed.mjs --report` écrit `docs/CALIBRATION.md` (répartition des difficultés par thème). Les thèmes importés
de Wikidata trop resserrés (écart-type < 7) sont étalés par rang vers un écart-type de 10 autour de la même moyenne ; 105
questions expertes (difficulté 66–85) écrites à la main couvrent les thèmes qui n'avaient rien de difficile.

## Daily (non individuel)
Série commune du jour : 5 emplacements (calc, french, geo, history, surprise), ordre mélangé, profil de difficulté cible `[35, 45, 50, 55, 65]` réparti aléatoirement, en évitant : question utilisée dans un Daily depuis 180 j, concept utilisé depuis 60 j. Types variés (au plus 2 fois le même type).
Chaque réponse au Daily met aussi à jour compétences et calibration (contexte `daily`).

## Percentile du Daily
- N participants terminés pour la date ≥ **100** : réel. `TOP = ceil(100 · (meilleurs + 1) / N)` où « meilleur » = score supérieur, ou score égal et temps inférieur. Seuil 100 : erreur-type d'un percentile médian ≈ 5 points, résolution 1 %.
- N < 100 : **estimation de référence** = population simulée μ ~ N(50, 15²) (quadrature 9 points) répondant aux 5 questions avec leurs difficultés effectives ; distribution de Poisson-binomiale du score ; `TOP = 100·(P(score > s) + ½·P(score = s))`. Toujours renvoyée avec `source = 'estimate'` et affichée « estimation ».

## Erreurs (par concept)
États : `failed` (raté, actif) → `to_review` (re-raté en révision, actif) → `correct_once` (corrigée : « ERREUR CORRIGÉE ✓ », sort des actives) → `mastered` (re-réussie un autre jour ≥ 3 j plus tard). Un nouvel échec, quel que soit l'état, renvoie en `failed`/`to_review`. L'historique complet reste dans `question_attempts`.
