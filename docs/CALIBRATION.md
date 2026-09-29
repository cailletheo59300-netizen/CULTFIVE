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
| arts.architecture | 65 | 13 | 25 | 20 | 7 | 82 |
| arts.literature | 230 | 3 | 84 | 90 | 53 | 78 |
| arts.mythology | 71 | 15 | 37 | 12 | 7 | 78 |
| arts.painting | 62 | 3 | 22 | 23 | 14 | 75 |
| calc.conversions | 74 | 17 | 36 | 20 | 1 | 80 |
| calc.fractions | 73 | 5 | 45 | 22 | 1 | 70 |
| calc.mental | 97 | 6 | 63 | 26 | 2 | 72 |
| calc.number_logic | 79 | 4 | 13 | 54 | 8 | 85 |
| calc.percent | 79 | 1 | 47 | 23 | 8 | 72 |
| cinema.actors | 141 | 1 | 32 | 107 | 1 | 78 |
| cinema.animation | 65 | 29 | 25 | 7 | 4 | 82 |
| cinema.directors | 60 | 6 | 24 | 25 | 5 | 80 |
| cinema.films | 58 | 1 | 19 | 35 | 3 | 85 |
| french.expressions | 80 | 38 | 23 | 8 | 11 | 82 |
| french.grammar | 77 | 17 | 31 | 19 | 10 | 82 |
| french.spelling | 79 | 14 | 25 | 27 | 13 | 80 |
| french.synonyms | 83 | 18 | 33 | 20 | 12 | 82 |
| french.vocabulary | 88 | 10 | 41 | 25 | 12 | 85 |
| geography.capitals | 285 | 87 | 184 | 11 | 3 | 80 |
| geography.countries | 746 | 89 | 510 | 141 | 6 | 78 |
| geography.flags | 193 | 12 | 141 | 34 | 6 | 82 |
| geography.monuments | 185 | 5 | 86 | 68 | 26 | 70 |
| geography.relief | 151 | 13 | 114 | 20 | 4 | 85 |
| history.antiquity | 82 | 15 | 32 | 27 | 8 | 78 |
| history.contemporary | 284 | 22 | 167 | 85 | 10 | 80 |
| history.middle_ages | 107 | 7 | 51 | 40 | 9 | 80 |
| history.modern | 134 | 11 | 81 | 34 | 8 | 85 |
| logic.puzzles | 61 | 7 | 22 | 23 | 9 | 85 |
| logic.reasoning | 64 | 19 | 23 | 17 | 5 | 80 |
| logic.sequences | 66 | 16 | 25 | 21 | 4 | 85 |
| music.classical | 71 | 13 | 37 | 15 | 6 | 80 |
| music.instruments | 64 | 3 | 22 | 32 | 7 | 81 |
| music.popular | 132 | 1 | 24 | 80 | 27 | 83 |
| nature.animals | 80 | 37 | 28 | 10 | 5 | 80 |
| nature.earth | 72 | 13 | 37 | 15 | 7 | 82 |
| nature.marine | 68 | 18 | 32 | 12 | 6 | 80 |
| nature.plants | 70 | 19 | 28 | 18 | 5 | 82 |
| science.biology | 71 | 20 | 29 | 14 | 8 | 80 |
| science.chemistry | 81 | 17 | 51 | 10 | 3 | 75 |
| science.human_body | 74 | 17 | 37 | 13 | 7 | 80 |
| science.physics | 69 | 19 | 34 | 11 | 5 | 80 |
| science.space | 77 | 16 | 32 | 23 | 6 | 82 |
| sport.champions | 61 | 15 | 31 | 11 | 4 | 78 |
| sport.football | 69 | 16 | 18 | 32 | 3 | 75 |
| sport.olympics | 54 | 2 | 11 | 38 | 3 | 78 |
| sport.rules | 70 | 27 | 29 | 8 | 6 | 82 |
| tech.brands | 64 | 27 | 27 | 4 | 6 | 82 |
| tech.computing | 64 | 18 | 26 | 13 | 7 | 80 |
| tech.inventions | 63 | 0 | 24 | 31 | 8 | 81 |
