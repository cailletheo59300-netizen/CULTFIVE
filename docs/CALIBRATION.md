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
| arts.architecture | 61 | 13 | 25 | 20 | 3 | 72 |
| arts.literature | 230 | 3 | 84 | 90 | 53 | 78 |
| arts.mythology | 66 | 15 | 37 | 12 | 2 | 78 |
| arts.painting | 62 | 3 | 22 | 23 | 14 | 75 |
| calc.conversions | 74 | 17 | 36 | 20 | 1 | 80 |
| calc.fractions | 73 | 5 | 45 | 22 | 1 | 70 |
| calc.mental | 97 | 6 | 63 | 26 | 2 | 72 |
| calc.number_logic | 79 | 4 | 13 | 54 | 8 | 85 |
| calc.percent | 79 | 1 | 47 | 23 | 8 | 72 |
| cinema.actors | 141 | 1 | 32 | 107 | 1 | 78 |
| cinema.animation | 63 | 29 | 25 | 7 | 2 | 80 |
| cinema.directors | 57 | 6 | 24 | 25 | 2 | 80 |
| cinema.films | 57 | 1 | 19 | 35 | 2 | 85 |
| french.expressions | 70 | 38 | 23 | 8 | 1 | 78 |
| french.grammar | 71 | 17 | 31 | 19 | 4 | 80 |
| french.spelling | 71 | 14 | 25 | 27 | 5 | 80 |
| french.synonyms | 75 | 18 | 33 | 20 | 4 | 78 |
| french.vocabulary | 80 | 10 | 41 | 25 | 4 | 75 |
| geography.capitals | 285 | 87 | 184 | 11 | 3 | 80 |
| geography.countries | 745 | 89 | 510 | 141 | 5 | 78 |
| geography.flags | 193 | 12 | 141 | 34 | 6 | 82 |
| geography.monuments | 185 | 5 | 86 | 68 | 26 | 70 |
| geography.relief | 150 | 13 | 114 | 20 | 3 | 85 |
| history.antiquity | 75 | 15 | 32 | 27 | 1 | 72 |
| history.contemporary | 278 | 22 | 167 | 85 | 4 | 80 |
| history.middle_ages | 101 | 7 | 51 | 40 | 3 | 75 |
| history.modern | 132 | 11 | 81 | 34 | 6 | 75 |
| logic.puzzles | 61 | 7 | 22 | 23 | 9 | 85 |
| logic.reasoning | 64 | 19 | 23 | 17 | 5 | 80 |
| logic.sequences | 63 | 16 | 25 | 21 | 1 | 85 |
| music.classical | 66 | 13 | 37 | 15 | 1 | 75 |
| music.instruments | 64 | 3 | 22 | 32 | 7 | 81 |
| music.popular | 132 | 1 | 24 | 80 | 27 | 83 |
| nature.animals | 74 | 37 | 28 | 9 | 0 | 68 |
| nature.earth | 66 | 13 | 37 | 15 | 1 | 72 |
| nature.marine | 64 | 18 | 32 | 12 | 2 | 78 |
| nature.plants | 66 | 19 | 28 | 18 | 1 | 72 |
| science.biology | 67 | 20 | 29 | 14 | 4 | 75 |
| science.chemistry | 80 | 17 | 51 | 10 | 2 | 75 |
| science.human_body | 67 | 17 | 37 | 13 | 0 | 68 |
| science.physics | 65 | 19 | 34 | 11 | 1 | 72 |
| science.space | 73 | 16 | 32 | 23 | 2 | 75 |
| sport.champions | 59 | 15 | 31 | 11 | 2 | 78 |
| sport.football | 67 | 16 | 18 | 32 | 1 | 72 |
| sport.olympics | 52 | 2 | 11 | 38 | 1 | 78 |
| sport.rules | 66 | 27 | 29 | 8 | 2 | 78 |
| tech.brands | 60 | 27 | 27 | 4 | 2 | 82 |
| tech.computing | 60 | 18 | 26 | 13 | 3 | 80 |
| tech.inventions | 63 | 0 | 24 | 31 | 8 | 81 |
