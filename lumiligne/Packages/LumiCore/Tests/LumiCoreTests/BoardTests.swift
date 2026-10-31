import XCTest
@testable import LumiCore

final class BoardTests: XCTestCase {
    /// Grille 5 × 5 fixe pour les tests de règles :
    /// 0 0 1 1 1
    /// 0 0 1 2 2
    /// 3 3 3 2 2
    /// 3 4 4 4 2
    /// 3 4 4 4 4
    private let zones = [0, 0, 1, 1, 1,
                         0, 0, 1, 2, 2,
                         3, 3, 3, 2, 2,
                         3, 4, 4, 4, 2,
                         3, 4, 4, 4, 4]

    func testRules() {
        let layout = Layout(size: 5, zones: zones)
        XCTAssertEqual(layout.conflict(0, 1), .sameZone)
        XCTAssertEqual(layout.conflict(6, 12), .touching)       // zones 0 et 3, en diagonale
        XCTAssertEqual(layout.conflict(0, 7), .notAligned)      // zones 0 et 1, ni même ligne ni même colonne
        XCTAssertNil(layout.conflict(0, 3))                     // zones 0 et 1, même ligne, ne se touchent pas
        XCTAssertNil(layout.conflict(0, 9))                     // zones 0 et 2 : pas besoin d'être alignées
        XCTAssertTrue(layout.blocked[0].contains(1))
        XCTAssertTrue(layout.blocked[0].contains(7))
        XCTAssertFalse(layout.blocked[0].contains(3))
        XCTAssertEqual(layout.labelCell(of: 2), 8)
    }

    private func sampleGrid() -> Grid {
        Generator.grid(size: 6, difficulty: .medium, seed: 1234)
    }

    func testTapCyclesAndUndo() {
        var board = Board(grid: sampleGrid())
        XCTAssertEqual(board.tap(0), .cross)
        XCTAssertEqual(board.tap(0), .gem)
        XCTAssertEqual(board.tap(0), .empty)
        board.undo()
        XCTAssertEqual(board.marks[0], .gem)
        board.clear()
        XCTAssertTrue(board.marks.allSatisfy { $0 == .empty })
        board.undo()
        XCTAssertEqual(board.marks[0], .gem)
    }

    func testStrokeOnlyCrossesEmptyCellsInOneUndo() {
        var board = Board(grid: sampleGrid())
        board.set(1, .gem)
        board.beginStroke()
        XCTAssertTrue(board.strokeCross(0))
        XCTAssertFalse(board.strokeCross(1))
        XCTAssertTrue(board.strokeCross(2))
        board.undo()
        XCTAssertEqual(board.marks[0], .empty)
        XCTAssertEqual(board.marks[1], .gem)
        XCTAssertEqual(board.marks[2], .empty)
    }

    func testSolutionSolvesAndLightsTheBeam() {
        let grid = sampleGrid()
        var board = Board(grid: grid)
        for cell in grid.solution.dropLast() { board.set(cell, .gem) }
        XCTAssertFalse(board.isSolved)
        XCTAssertTrue(board.conflicts.allSatisfy { !$0 })
        XCTAssertEqual(board.links.filter { $0 }.count, grid.size - 2)
        board.set(grid.solution.last!, .gem)
        XCTAssertTrue(board.isSolved)
        XCTAssertTrue(board.links.allSatisfy { $0 })
        XCTAssertTrue(board.resolvedZones.allSatisfy { $0 })
        XCTAssertNil(board.hint(autoCrosses: true))
    }

    func testConflictsAreShown() {
        let grid = sampleGrid()
        var board = Board(grid: grid)
        let a = grid.solution[0]
        // Une deuxième gemme dans la même zone.
        let b = grid.layout.cellsOfZone[0].first { $0 != a }!
        board.set(a, .gem)
        board.set(b, .gem)
        XCTAssertTrue(board.conflicts[a])
        XCTAssertTrue(board.conflicts[b])
        XCTAssertEqual(board.conflict(at: a)?.conflict, .sameZone)
        let hint = board.hint(autoCrosses: true)!
        XCTAssertTrue(hint.isFree)
        XCTAssertFalse(board.isSolved)
    }

    func testAutoCrosses() {
        let grid = sampleGrid()
        var board = Board(grid: grid)
        let gem = grid.solution[0]
        board.set(gem, .gem)
        let auto = board.autoCrosses
        for cell in grid.layout.blocked[gem] { XCTAssertTrue(auto[cell]) }
        XCTAssertFalse(auto[gem])
    }

    /// En suivant seulement les indices, on finit toujours la grille.
    func testHintsAloneSolveTheGrid() {
        for seed: UInt64 in [1, 2, 3, 4] {
            for autoCrosses in [true, false] {
                let grid = Generator.grid(size: 7, difficulty: .hard, seed: seed)
                var board = Board(grid: grid)
                var steps = 0
                while let hint = board.hint(autoCrosses: autoCrosses), steps < 500 {
                    XCTAssertFalse(hint.message.isEmpty)
                    board.apply(hint)
                    steps += 1
                }
                XCTAssertTrue(board.isSolved, "graine \(seed)")
            }
        }
    }

    /// Les indices corrigent les erreurs : mauvaise gemme, croix en trop.
    func testHintsFixMistakes() {
        let grid = sampleGrid()
        var board = Board(grid: grid)
        let wrong = grid.layout.cellsOfZone[2].first { $0 != grid.solution[2] }!
        board.set(wrong, .gem)
        board.set(grid.solution[3], .cross)
        var hint = board.hint(autoCrosses: true)!
        XCTAssertEqual(hint.kind, .wrongGem(zone: 2))
        board.apply(hint)
        XCTAssertEqual(board.marks[wrong], .empty)
        hint = board.hint(autoCrosses: true)!
        XCTAssertEqual(hint.kind, .wrongCross(zone: 3))
        board.apply(hint)
        XCTAssertEqual(board.marks[grid.solution[3]], .empty)
    }

    func testSavedMarksAreRestored() {
        let grid = sampleGrid()
        var board = Board(grid: grid)
        board.set(3, .cross)
        board.set(grid.solution[1], .gem)
        let restored = Board(grid: grid, marks: board.marks)
        XCTAssertEqual(restored.marks, board.marks)
        XCTAssertEqual(Board(grid: grid, marks: [.gem]).marks.count, grid.layout.cellCount)
    }
}
