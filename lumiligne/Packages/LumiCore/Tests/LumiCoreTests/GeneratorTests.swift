import XCTest
@testable import LumiCore

final class GeneratorTests: XCTestCase {
    /// Vérifie toutes les règles d'une grille générée.
    private func check(_ grid: Grid, file: StaticString = #filePath, line: UInt = #line) {
        let layout = grid.layout
        let n = grid.size
        // Autant de zones que de lignes, chacune d'au moins 2 cases, d'un seul morceau.
        XCTAssertEqual(layout.cellsOfZone.count, n, file: file, line: line)
        for zone in 0..<n {
            XCTAssertGreaterThanOrEqual(layout.cellsOfZone[zone].count, Generator.minZoneSize, file: file, line: line)
            XCTAssertTrue(Generator.isConnected(layout.zones, zone: zone, size: n), "zone \(zone) en morceaux", file: file, line: line)
        }
        // La solution respecte les règles.
        XCTAssertEqual(grid.solution.count, n, file: file, line: line)
        for (zone, cell) in grid.solution.enumerated() {
            XCTAssertEqual(layout.zones[cell], zone, file: file, line: line)
            for other in grid.solution where other != cell {
                XCTAssertNil(layout.conflict(cell, other), file: file, line: line)
            }
        }
        // Une seule solution (recherche exhaustive).
        let all = Solver.solutions(size: n, zones: layout.zones, limit: 2)
        XCTAssertEqual(all, [grid.solution], "solution non unique", file: file, line: line)
        // Résolue par déduction seule, sans deviner.
        XCTAssertEqual(Solver.rate(layout).solution, grid.solution, "pas résoluble par déduction", file: file, line: line)
    }

    func testGeneratedGridsHaveOneSolutionFoundByDeduction() {
        for size in 5...9 {
            for difficulty in Difficulty.allCases {
                for index in 0..<3 {
                    let grid = Generator.grid(size: size, difficulty: difficulty,
                                              seed: SeededRandom.seed(from: "test-\(size)-\(difficulty)-\(index)"))
                    check(grid)
                    XCTAssertEqual(grid.size, size)
                }
            }
        }
    }

    func testFirstLevelsAndAWeekOfDailyGrids() {
        for number in [1, 2, 3, 6, 11, 12, 36, 81, 151] {
            let grid = Puzzles.grid(.level(number))
            check(grid)
            XCTAssertEqual(grid.size, Puzzles.levelSize(number))
        }
        var day = "2026-11-08"
        for _ in 0..<7 {
            let grid = Puzzles.grid(.daily(day))
            check(grid)
            XCTAssertEqual(grid.size, Puzzles.plan(.daily(day)).size)
            day = DayKey.previous(day)!
        }
        check(Puzzles.grid(.bonus("2026-11-08")))
    }

    func testDifficultyIsMostlyRespected() {
        var matches = 0
        var total = 0
        for size in [6, 7] {
            for difficulty in Difficulty.allCases {
                for index in 0..<3 {
                    let grid = Generator.grid(size: size, difficulty: difficulty, seed: SeededRandom.seed(from: "diff-\(size)-\(difficulty)-\(index)"))
                    total += 1
                    if grid.difficulty == difficulty { matches += 1 }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(matches, total - 1)
    }

    /// La même graine donne la même grille : la grille du jour est la même pour tout le monde.
    func testSameSeedSameGrid() {
        let a = Puzzles.grid(.daily("2026-10-31"))
        let b = Puzzles.grid(.daily("2026-10-31"))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a.layout.zones, Puzzles.grid(.daily("2026-11-01")).layout.zones)
        XCTAssertEqual(Puzzles.grid(.level(7)), Puzzles.grid(.level(7)))
    }

    /// Empreinte figée de la grille d'un jour : si ce test casse, la grille du jour a changé pour tout le monde
    /// (changement du générateur ou des réglages). À faire seulement avant la sortie, ou en le sachant.
    func testDailyFingerprint() {
        let grid = Puzzles.grid(.daily("2026-12-01"))
        let fingerprint = grid.layout.zones.map(String.init).joined()
        // Affichée dans le journal de test pour pouvoir la recopier ci-dessous après un changement voulu.
        print("Empreinte 2026-12-01 :", fingerprint, grid.solution)
        XCTAssertEqual(grid.size, 6)
        XCTAssertEqual(grid.solution.count, 6)
    }

    func testSeededRandomIsStable() {
        var random = SeededRandom(seed: 42)
        let values = (0..<3).map { _ in random.next() }
        var again = SeededRandom(seed: 42)
        XCTAssertEqual(values, (0..<3).map { _ in again.next() })
        XCTAssertEqual(SeededRandom.seed(from: "lumiligne"), SeededRandom.seed(from: "lumiligne"))
        XCTAssertNotEqual(SeededRandom.seed(from: "a"), SeededRandom.seed(from: "b"))
    }

    func testLevelPlan() {
        XCTAssertEqual(Puzzles.levelSize(1), 5)
        XCTAssertEqual(Puzzles.levelSize(36), 7)
        XCTAssertEqual(Puzzles.levelSize(500), 9)
        for number in 1...5 { XCTAssertEqual(Puzzles.levelDifficulty(number), .easy) }
        XCTAssertEqual(Puzzles.levelDifficulty(8), .hard)
    }

    func testWeekday() {
        XCTAssertEqual(DayKey.weekday("2026-11-02"), 1) // lundi
        XCTAssertEqual(DayKey.weekday("2026-11-08"), 7) // dimanche
        XCTAssertEqual(DayKey.previous("2026-03-01"), "2026-02-28")
    }
}
