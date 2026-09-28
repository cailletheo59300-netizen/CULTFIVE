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
| arts.architecture | 41 | 9 | 14 | 15 | 3 | 72 |
| arts.literature | 230 | 3 | 84 | 90 | 53 | 78 |
| arts.mythology | 41 | 9 | 26 | 4 | 2 | 78 |
| arts.painting | 62 | 3 | 22 | 23 | 14 | 75 |
| calc.conversions | 41 | 11 | 17 | 12 | 1 | 80 |
| calc.fractions | 41 | 5 | 21 | 14 | 1 | 70 |
| calc.mental | 55 | 6 | 38 | 9 | 2 | 72 |
| calc.number_logic | 45 | 4 | 9 | 26 | 6 | 85 |
| calc.percent | 40 | 1 | 25 | 9 | 5 | 72 |
| cinema.actors | 141 | 1 | 32 | 107 | 1 | 78 |
| cinema.animation | 41 | 18 | 16 | 5 | 2 | 80 |
| cinema.directors | 57 | 6 | 24 | 25 | 2 | 80 |
| cinema.films | 57 | 1 | 19 | 35 | 2 | 85 |
| french.expressions | 40 | 17 | 15 | 7 | 1 | 78 |
| french.grammar | 42 | 4 | 21 | 15 | 2 | 80 |
| french.spelling | 41 | 6 | 12 | 19 | 4 | 80 |
| french.synonyms | 44 | 8 | 21 | 13 | 2 | 78 |
| french.vocabulary | 51 | 5 | 23 | 19 | 4 | 75 |
| geography.capitals | 285 | 87 | 184 | 11 | 3 | 80 |
| geography.countries | 745 | 89 | 510 | 141 | 5 | 78 |
| geography.flags | 193 | 12 | 141 | 34 | 6 | 82 |
| geography.monuments | 185 | 5 | 86 | 68 | 26 | 70 |
| geography.relief | 150 | 13 | 114 | 20 | 3 | 85 |
| history.antiquity | 40 | 5 | 19 | 15 | 1 | 72 |
| history.contemporary | 278 | 22 | 167 | 85 | 4 | 80 |
| history.middle_ages | 69 | 0 | 37 | 30 | 2 | 75 |
| history.modern | 132 | 11 | 81 | 34 | 6 | 75 |
| logic.puzzles | 42 | 4 | 14 | 18 | 6 | 80 |
| logic.reasoning | 41 | 8 | 19 | 12 | 2 | 80 |
| logic.sequences | 63 | 16 | 25 | 21 | 1 | 85 |
| music.classical | 40 | 9 | 23 | 7 | 1 | 75 |
| music.instruments | 64 | 3 | 22 | 32 | 7 | 81 |
| music.popular | 132 | 1 | 24 | 80 | 27 | 83 |
| nature.animals | 53 | 25 | 19 | 9 | 0 | 68 |
| nature.earth | 41 | 10 | 20 | 10 | 1 | 72 |
| nature.marine | 41 | 10 | 23 | 6 | 2 | 78 |
| nature.plants | 41 | 10 | 20 | 10 | 1 | 72 |
| science.biology | 42 | 8 | 19 | 11 | 4 | 75 |
| science.chemistry | 80 | 17 | 51 | 10 | 2 | 75 |
| science.human_body | 41 | 11 | 19 | 11 | 0 | 68 |
| science.physics | 41 | 10 | 22 | 8 | 1 | 72 |
| science.space | 52 | 9 | 22 | 19 | 2 | 75 |
| sport.champions | 40 | 14 | 19 | 5 | 2 | 78 |
| sport.football | 47 | 5 | 12 | 29 | 1 | 72 |
| sport.olympics | 52 | 2 | 11 | 38 | 1 | 78 |
| sport.rules | 42 | 14 | 21 | 5 | 2 | 78 |
| tech.brands | 41 | 18 | 18 | 3 | 2 | 82 |
| tech.computing | 41 | 7 | 21 | 10 | 3 | 80 |
| tech.inventions | 63 | 0 | 24 | 31 | 8 | 81 |
