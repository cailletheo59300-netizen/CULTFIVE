import XCTest
import CultFiveCore
@testable import CultFive

@MainActor
final class AppLogicTests: XCTestCase {
    private func makeModel() -> AppModel {
        AppModel(service: UnavailableService(), api: nil, queue: OfflineAttemptQueue(fileURL: nil))
    }

    func testInviteLinks() {
        let model = makeModel()
        model.handle(url: URL(string: "cultfive://l/ABC123")!)
        XCTAssertEqual(model.pendingLeagueCode, "ABC123")
        XCTAssertEqual(model.tab, .friends)

        model.handle(url: URL(string: "https://cultfive.app/i/xy7k2pq")!)
        XCTAssertEqual(model.pendingInvite, "XY7K2PQ")
        UserDefaults.standard.removeObject(forKey: "pendingInvite")
    }

    func testBrandIsCentralised() {
        XCTAssertEqual(Brand.name, "CULT FIVE")
        XCTAssertEqual(Brand.inviteURL(code: "ABC").absoluteString, "https://cultfive.app/i/ABC")
        XCTAssertEqual(Brand.currency(1), "1 graine")
        XCTAssertEqual(Brand.currency(12), "12 graines")
    }

    func testCorrectAnswerText() {
        let question = Question(id: UUID(), type: .numeric, domainId: "calc", subdomainId: "calc.conversions",
                                prompt: "Combien ?", payload: QuestionPayload(unit: "km"))
        XCTAssertEqual(AnswerText.correct(for: question, answer: CorrectAnswer(value: .number(42.195))), "42,195 km")
        let mcq = Question(id: UUID(), type: .mcq, domainId: "geography", subdomainId: "geography.capitals", prompt: "Capitale ?",
                           payload: QuestionPayload(options: [Choice(id: "a", text: "Canberra"), Choice(id: "b", text: "Sydney")]))
        XCTAssertEqual(AnswerText.correct(for: mcq, answer: CorrectAnswer(optionId: "a")), "Canberra")
    }

    func testResultCopyCoversAllScores() {
        for score in 0...5 {
            XCTAssertFalse(ResultCopy.headline(score: score, status: "finished").isEmpty)
        }
        XCTAssertTrue(ResultCopy.headline(score: 2, status: "expired").contains("Temps écoulé"))
    }

    func testDateText() {
        XCTAssertTrue(DateText.long("2026-09-26").contains("26 septembre"))
    }
}
