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
| Prior utilisateur (domaine) | μ₀ selon le choix d'onboarding : Découverte 38 · Équilibre 50 · Challenge 60 · Expert 70 ; σ₀ = 12 |
| Prior sous-domaine | μ du domaine au moment de la création, σ = max(σ_domaine, 10) |
| Variation max par réponse | ±6 points |
| Plancher d'incertitude | σ ≥ 3 (le niveau reste capable d'évoluer) |
| Réinflation | σ² += 0,5/jour d'inactivité dans le domaine, plafonné à σ₀² |
| Prior question | b₀ = difficulté initiale ; σ_b = 10 (humaine), 12 (IA) |
| Plancher question | σ_b ≥ 2 |
| Plage effective | `b_effective = clamp(b_observed, min, max)` ; E se calcule avec `b_effective` |
| Élargissement de plage | seulement si n ≥ 300 réponses **et** `b_observed` hors plage de plus de 2σ_b : la borne bouge de 5 points, au plus une fois par tranche de 100 réponses |
| Question à revoir (admin) | n ≥ 50 et taux de réussite < 5 % ou > 99 %, ou élargissement demandé 3 fois |

Premières réponses d'un nouvel utilisateur (σ=12, E=0,5) : ≈ +5 points pour une bonne réponse, puis ≈ +4, +3,5… Après ~30 réponses, σ ≈ 4 : une réponse bouge le niveau de ~1 point.

## Fiabilité affichée
`fiabilité = 1 − σ/σ₀` ∈ [0,1], affichée en mots : « à affiner » (<0,35), « correcte » (<0,65), « solide ».

## Sélection des questions (Jouer, Défi, Erreurs)
Pour chaque question à servir, on tire une **bande** :
| Bande | Proba | Réussite visée E |
|---|---|---|
| Cœur | 60 % | 0,60–0,80 |
| Consolidation | 20 % | 0,80–0,93 |
| Mesure (plus dur) | 15 % | 0,40–0,60 |
| Exploration | 5 % | aléatoire, priorité aux questions peu calibrées |
Défi : bandes décalées (Cœur 0,45–0,65, Mesure 0,30–0,45).
Conversion : `b = μ − S·ln(E/(1−E))`. Filtres : statut `published`, concept non vu depuis 3 jours (7 jours si réussi), pas deux fois le même concept dans une série, questions des Daily présents/futurs exclues. Si la bande est vide, élargissement progressif (±5 puis ±10) puis n'importe quelle question du filtre.

## Daily (non individuel)
Série commune du jour : 5 emplacements (calc, french, geo, history, surprise), ordre mélangé, profil de difficulté cible `[35, 45, 50, 55, 65]` réparti aléatoirement, en évitant : question utilisée dans un Daily depuis 180 j, concept utilisé depuis 60 j. Types variés (au plus 2 fois le même type).
Chaque réponse au Daily met aussi à jour compétences et calibration (contexte `daily`).

## Percentile du Daily
- N participants terminés pour la date ≥ **100** : réel. `TOP = ceil(100 · (meilleurs + 1) / N)` où « meilleur » = score supérieur, ou score égal et temps inférieur. Seuil 100 : erreur-type d'un percentile médian ≈ 5 points, résolution 1 %.
- N < 100 : **estimation de référence** = population simulée μ ~ N(50, 15²) (quadrature 9 points) répondant aux 5 questions avec leurs difficultés effectives ; distribution de Poisson-binomiale du score ; `TOP = 100·(P(score > s) + ½·P(score = s))`. Toujours renvoyée avec `source = 'estimate'` et affichée « estimation ».

## Erreurs (par concept)
États : `failed` (raté, actif) → `to_review` (re-raté en révision, actif) → `correct_once` (corrigée : « ERREUR CORRIGÉE ✓ », sort des actives) → `mastered` (re-réussie un autre jour ≥ 3 j plus tard). Un nouvel échec, quel que soit l'état, renvoie en `failed`/`to_review`. L'historique complet reste dans `question_attempts`.
