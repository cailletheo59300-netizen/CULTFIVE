# Calibrage des difficultés (généré par `node scripts/build-seed.mjs --report`)

Difficulté initiale sur l'échelle du niveau (0–100). Un joueur de niveau μ a 50 % de chances sur une question de difficulté μ,
27 % à μ + 10 et 73 % à μ − 10. Le calibrage en ligne ajuste ensuite chaque question d'après les réponses.

## Thèmes importés étalés

| Thème | Questions | Avant (moyenne ± écart-type) | Après |
|---|---|---|---|
| arts.literature | 233 | 58 ± 3.9 | 58 ± 9.3 |
| arts.painting | 57 | 59 ± 1.9 | 59 ± 9.2 |
| cinema.actors | 142 | 59 ± 1.6 | 59 ± 8.8 |
| cinema.directors | 51 | 48 ± 1.3 | 48 ± 8.4 |
| cinema.films | 51 | 62 ± 1.3 | 62 ± 8.4 |
| geography.monuments | 185 | 55 ± 3.4 | 55 ± 9.6 |
| history.contemporary | 271 | 50 ± 6.7 | 50 ± 9.8 |
| history.modern | 120 | 49 ± 6.3 | 49 ± 9.8 |
| music.popular | 132 | 63 ± 3.5 | 63 ± 9.8 |
| music.instruments | 56 | 58 ± 4.7 | 58 ± 9.7 |
| tech.inventions | 58 | 57 ± 4.7 | 57 ± 9.8 |

## Répartition par thème

| Thème | Questions | < 35 | 35–54 | 55–69 | ≥ 70 | Max |
|---|---|---|---|---|---|---|
| arts.architecture | 22 | 8 | 6 | 6 | 2 | 72 |
| arts.literature | 239 | 3 | 86 | 95 | 55 | 78 |
| arts.mythology | 22 | 5 | 14 | 1 | 2 | 78 |
| arts.painting | 64 | 3 | 23 | 24 | 14 | 75 |
| calc.conversions | 23 | 7 | 8 | 5 | 3 | 80 |
| calc.fractions | 21 | 5 | 11 | 4 | 1 | 70 |
| calc.mental | 32 | 6 | 21 | 3 | 2 | 72 |
| calc.number_logic | 23 | 4 | 7 | 8 | 4 | 85 |
| calc.percent | 22 | 2 | 11 | 7 | 2 | 72 |
| cinema.actors | 144 | 1 | 31 | 111 | 1 | 78 |
| cinema.animation | 22 | 10 | 8 | 2 | 2 | 80 |
| cinema.directors | 57 | 5 | 24 | 26 | 2 | 80 |
| cinema.films | 57 | 1 | 18 | 36 | 2 | 85 |
| french.expressions | 24 | 14 | 7 | 2 | 1 | 78 |
| french.grammar | 22 | 1 | 8 | 11 | 2 | 80 |
| french.spelling | 26 | 5 | 5 | 14 | 2 | 80 |
| french.synonyms | 29 | 7 | 15 | 4 | 3 | 78 |
| french.vocabulary | 34 | 4 | 16 | 12 | 2 | 75 |
| geography.capitals | 296 | 89 | 191 | 13 | 3 | 80 |
| geography.countries | 854 | 94 | 596 | 159 | 5 | 78 |
| geography.flags | 198 | 13 | 143 | 36 | 6 | 82 |
| geography.monuments | 192 | 5 | 93 | 68 | 26 | 70 |
| geography.relief | 150 | 13 | 114 | 20 | 3 | 85 |
| history.antiquity | 24 | 3 | 12 | 8 | 1 | 72 |
| history.contemporary | 291 | 22 | 177 | 88 | 4 | 80 |
| history.middle_ages | 72 | 0 | 39 | 31 | 2 | 75 |
| history.modern | 133 | 10 | 85 | 32 | 6 | 75 |
| logic.puzzles | 22 | 2 | 4 | 14 | 2 | 72 |
| logic.reasoning | 21 | 3 | 10 | 6 | 2 | 80 |
| logic.sequences | 66 | 17 | 26 | 21 | 2 | 85 |
| music.classical | 23 | 8 | 12 | 2 | 1 | 75 |
| music.instruments | 64 | 3 | 22 | 32 | 7 | 81 |
| music.popular | 136 | 1 | 25 | 82 | 28 | 83 |
| nature.animals | 53 | 25 | 19 | 9 | 0 | 68 |
| nature.earth | 22 | 5 | 13 | 3 | 1 | 72 |
| nature.marine | 22 | 4 | 15 | 2 | 1 | 78 |
| nature.plants | 22 | 6 | 10 | 4 | 2 | 72 |
| science.biology | 20 | 6 | 9 | 3 | 2 | 75 |
| science.chemistry | 80 | 17 | 51 | 10 | 2 | 75 |
| science.human_body | 21 | 7 | 9 | 5 | 0 | 68 |
| science.physics | 21 | 7 | 11 | 2 | 1 | 72 |
| science.space | 39 | 7 | 13 | 17 | 2 | 75 |
| sport.champions | 20 | 12 | 6 | 0 | 2 | 78 |
| sport.football | 47 | 5 | 12 | 29 | 1 | 72 |
| sport.olympics | 53 | 2 | 11 | 38 | 2 | 78 |
| sport.rules | 21 | 5 | 13 | 2 | 1 | 78 |
| tech.brands | 23 | 9 | 10 | 2 | 2 | 82 |
| tech.computing | 23 | 3 | 12 | 6 | 2 | 80 |
| tech.inventions | 63 | 0 | 24 | 31 | 8 | 81 |
