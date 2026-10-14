import XCTest
@testable import CultFiveCore

final class RatingTests: XCTestCase {
    func testScale() {
        XCTAssertEqual(CoteCULT.cote(level: 50), 1000)
        XCTAssertEqual(CoteCULT.cote(level: 73.03), 1400)
        XCTAssertEqual(CoteCULT.cote(level: 26.97), 600)
    }

    func testRanks() {
        XCTAssertEqual(CoteCULT.Rank(cote: 500), .curious)
        XCTAssertEqual(CoteCULT.Rank(cote: 600), .amateur)
        XCTAssertEqual(CoteCULT.Rank(cote: 749), .amateur)
        XCTAssertEqual(CoteCULT.Rank(cote: 750), .enlightened)
        XCTAssertEqual(CoteCULT.Rank(cote: 1000), .scholar)
        XCTAssertEqual(CoteCULT.Rank(cote: 1199), .expert)
        XCTAssertEqual(CoteCULT.Rank(cote: 1500), .encyclopedia)
        XCTAssertEqual(CoteCULT.Rank.expert.next, .encyclopedia)
        XCTAssertNil(CoteCULT.Rank.encyclopedia.next)
        let next = try? XCTUnwrap(CoteCULT(cote: 975, answered: 80).toNextRank)
        XCTAssertEqual(next?.missing, 75)
        // Elo affiché : 500 au départ, le vrai niveau à la fin du placement.
        XCTAssertEqual(CoteCULT.shown(level: 50, answered: 0), 500)
        XCTAssertEqual(CoteCULT.shown(level: 50, answered: 10), 750)
        XCTAssertEqual(CoteCULT.shown(level: 50, answered: 80), 1000)
        XCTAssertEqual(next?.progress ?? 0, 0.5, accuracy: 0.001)
    }

    func testPlacement() {
        XCTAssertFalse(CoteCULT(cote: 1100, answered: 19).placed)
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 13).placementGames, 1)
        XCTAssertTrue(CoteCULT(cote: 1100, answered: 20).placed)
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 400).placementGames, 2)
        // Avancement réel : réponses classées sur 20.
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 7).placementDone, 7)
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 7).placementLeft, 13)
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 7).provisionalLabel, "placement 7/20")
        XCTAssertEqual(CoteCULT(cote: 1100, answered: 400).placementLeft, 0)
        XCTAssertTrue(CoteCULT(cote: 1100, answered: 3, placed: true).placed, "le serveur fait foi")
    }

    func testGlobalIsWeighted() {
        let skills = [
            SkillSummary(domainId: "history", name: "Histoire", level: 60, reliability: 0.8, answered: 300, correct: 200, cote: 1200),
            SkillSummary(domainId: "sport", name: "Sport", level: 40, reliability: 0.5, answered: 100, correct: 40, cote: 800),
            SkillSummary(domainId: "music", name: "Musique", level: 50, reliability: 0, answered: 0, correct: 0, cote: 1000),
        ]
        let global = try? XCTUnwrap(CoteCULT.global(skills))
        XCTAssertEqual(global?.cote, 1100)
        XCTAssertEqual(global?.answered, 400)
        XCTAssertNil(CoteCULT.global([skills[2]]))
    }

    func testFormatting() {
        XCTAssertEqual(CoteCULT.formatDelta(18), "+18")
        XCTAssertEqual(CoteCULT.formatDelta(-7), "−7")
        XCTAssertEqual(CoteCULT.formatDelta(0), "=")
        XCTAssertEqual(CoteCULT.format(1342).filter(\.isNumber), "1342")
    }

    func testRelativeDifficulty() {
        XCTAssertEqual(RelativeDifficulty(expected: 0.8), .easy)
        XCTAssertEqual(RelativeDifficulty(expected: 0.55), .medium)
        XCTAssertEqual(RelativeDifficulty(expected: 0.4), .hard)
        XCTAssertEqual(RelativeDifficulty(expected: 0.2), .veryHard)
    }

    func testPointsMatchServer() {
        // Mêmes valeurs que public._attempt_points (supabase/tests/70_rating.sql).
        XCTAssertEqual(GamePoints.points(correct: true, expected: 0.5, responseMs: 500), 100)
        XCTAssertGreaterThan(GamePoints.points(correct: true, expected: 0.5, responseMs: 800), 100)
        XCTAssertEqual(GamePoints.points(correct: false, expected: 0.1, responseMs: 2000), 0)
        XCTAssertEqual(GamePoints.points(correct: true, expected: 0.3, responseMs: 20000), 120)
    }

    func testAdaptiveOrder() {
        func q(_ p: Double) -> Question {
            Question(id: UUID(), type: .mcq, domainId: "history", subdomainId: "history.modern", prompt: "?",
                     payload: QuestionPayload(), expected: p)
        }
        let remaining = [q(0.6), q(0.3), q(0.85)]
        XCTAssertEqual(AdaptiveOrder.nextIndex(remaining: remaining, correctStreak: 0, wrongStreak: 0), 0)
        XCTAssertEqual(AdaptiveOrder.nextIndex(remaining: remaining, correctStreak: 3, wrongStreak: 0), 1)
        XCTAssertEqual(AdaptiveOrder.nextIndex(remaining: remaining, correctStreak: 0, wrongStreak: 2), 2)
    }
}
