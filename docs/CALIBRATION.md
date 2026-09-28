# Calibrage des difficultés (généré par `node scripts/build-seed.mjs --report`)

Difficulté initiale sur l'échelle du niveau (0–100). Un joueur de niveau μ a 50 % de chances sur une question de difficulté μ,
27 % à μ + 10 et 73 % à μ − 10. Le calibrage en ligne ajuste ensuite chaque question d'après les réponses.

## Thèmes importés étalés

| Thème | Questions | Avant (moyenne ± écart-type) | Après |
|---|---|---|---|
| arts.literature | 224 | 58 ± 4.0 | 58 ± 9.3 |
| arts.painting | 55 | 59 ± 2.0 | 58 ± 9.1 |
| cinema.actors | 139 | 59 ± 1.7 | 59 ± 8.9 |
| cinema.directors | 51 | 48 ± 1.3 | 47 ± 8.4 |
| cinema.films | 51 | 62 ± 1.3 | 61 ± 8.4 |
| geography.monuments | 178 | 55 ± 3.2 | 54 ± 9.5 |
| history.contemporary | 258 | 50 ± 6.8 | 50 ± 9.9 |
| history.modern | 119 | 49 ± 6.2 | 49 ± 9.8 |
| music.popular | 128 | 63 ± 3.4 | 63 ± 9.8 |
| music.instruments | 56 | 58 ± 4.7 | 58 ± 9.7 |
| tech.inventions | 58 | 57 ± 4.7 | 57 ± 9.8 |

## Répartition par thème

| Thème | Questions | < 35 | 35–54 | 55–69 | ≥ 70 | Max |
|---|---|---|---|---|---|---|
| arts.architecture | 22 | 8 | 6 | 6 | 2 | 72 |
| arts.literature | 230 | 3 | 84 | 90 | 53 | 78 |
| arts.mythology | 22 | 5 | 14 | 1 | 2 | 78 |
| arts.painting | 62 | 3 | 22 | 23 | 14 | 75 |
| calc.conversions | 39 | 11 | 15 | 12 | 1 | 80 |
| calc.fractions | 38 | 5 | 18 | 14 | 1 | 70 |
| calc.mental | 55 | 6 | 38 | 9 | 2 | 72 |
| calc.number_logic | 45 | 4 | 9 | 26 | 6 | 85 |
| calc.percent | 40 | 1 | 25 | 9 | 5 | 72 |
| cinema.actors | 141 | 1 | 32 | 107 | 1 | 78 |
| cinema.animation | 22 | 10 | 8 | 2 | 2 | 80 |
| cinema.directors | 57 | 6 | 24 | 25 | 2 | 80 |
| cinema.films | 57 | 1 | 19 | 35 | 2 | 85 |
| french.expressions | 23 | 13 | 7 | 2 | 1 | 78 |
| french.grammar | 22 | 1 | 8 | 11 | 2 | 80 |
| french.spelling | 26 | 5 | 5 | 14 | 2 | 80 |
| french.synonyms | 27 | 7 | 14 | 4 | 2 | 78 |
| french.vocabulary | 33 | 4 | 16 | 11 | 2 | 75 |
| geography.capitals | 285 | 87 | 184 | 11 | 3 | 80 |
| geography.countries | 745 | 89 | 510 | 141 | 5 | 78 |
| geography.flags | 193 | 12 | 141 | 34 | 6 | 82 |
| geography.monuments | 185 | 5 | 86 | 68 | 26 | 70 |
| geography.relief | 150 | 13 | 114 | 20 | 3 | 85 |
| history.antiquity | 24 | 3 | 12 | 8 | 1 | 72 |
| history.contemporary | 278 | 22 | 167 | 85 | 4 | 80 |
| history.middle_ages | 69 | 0 | 37 | 30 | 2 | 75 |
| history.modern | 132 | 11 | 81 | 34 | 6 | 75 |
| logic.puzzles | 20 | 2 | 4 | 13 | 1 | 72 |
| logic.reasoning | 21 | 3 | 10 | 6 | 2 | 80 |
| logic.sequences | 63 | 16 | 25 | 21 | 1 | 85 |
| music.classical | 22 | 7 | 12 | 2 | 1 | 75 |
| music.instruments | 64 | 3 | 22 | 32 | 7 | 81 |
| music.popular | 132 | 1 | 24 | 80 | 27 | 83 |
| nature.animals | 53 | 25 | 19 | 9 | 0 | 68 |
| nature.earth | 22 | 5 | 13 | 3 | 1 | 72 |
| nature.marine | 21 | 4 | 15 | 1 | 1 | 78 |
| nature.plants | 22 | 6 | 10 | 4 | 2 | 72 |
| science.biology | 20 | 6 | 9 | 3 | 2 | 75 |
| science.chemistry | 80 | 17 | 51 | 10 | 2 | 75 |
| science.human_body | 20 | 7 | 9 | 4 | 0 | 68 |
| science.physics | 21 | 7 | 11 | 2 | 1 | 72 |
| science.space | 38 | 6 | 13 | 17 | 2 | 75 |
| sport.champions | 20 | 12 | 6 | 0 | 2 | 78 |
| sport.football | 47 | 5 | 12 | 29 | 1 | 72 |
| sport.olympics | 52 | 2 | 11 | 38 | 1 | 78 |
| sport.rules | 21 | 5 | 13 | 2 | 1 | 78 |
| tech.brands | 22 | 9 | 10 | 1 | 2 | 82 |
| tech.computing | 23 | 3 | 12 | 6 | 2 | 80 |
| tech.inventions | 63 | 0 | 24 | 31 | 8 | 81 |
