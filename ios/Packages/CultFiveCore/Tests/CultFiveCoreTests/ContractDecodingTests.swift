import XCTest
@testable import CultFiveCore

/// Tests de contrat : les fixtures sont de vraies réponses RPC générées par scripts/gen-fixtures.sh.
/// Si le serveur change de forme, ces tests cassent avant l'app.
final class ContractDecodingTests: XCTestCase {
    private func fixture<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try SupabaseAPI.decoder.decode(T.self, from: Data(contentsOf: url))
    }

    func testDaily() throws {
        let status: DailyStatus = try fixture("daily_status")
        XCTAssertEqual(status.state, .available)
        let start: DailyStart = try fixture("daily_start")
        XCTAssertEqual(start.nextPosition, 1)

        let response: DailyQuestionResponse = try fixture("daily_question")
        let question = try XCTUnwrap(response.question)
        XCTAssertFalse(response.expired)
        XCTAssertNil(question.reveal, "pas de réponse avant validation")
        XCTAssertEqual(question.position, 1)

        let verdict: DailyVerdict = try fixture("daily_verdict")
        XCTAssertEqual(verdict.isCorrect, true)
        XCTAssertNotNil(verdict.reveal)

        let result: DailyResult = try fixture("daily_result")
        XCTAssertEqual(result.answers.count, 5)
        XCTAssertEqual(result.percentile?.source, .estimate)
        XCTAssertFalse(result.achievements.isEmpty)

        let review: [ReviewItem] = try fixture("daily_review")
        XCTAssertEqual(review.count, 5)
        XCTAssertTrue(review.allSatisfy { $0.question.reveal != nil })
        XCTAssertTrue(review.contains { $0.given != nil })

        let history: [DailyHistoryEntry] = try fixture("history")
        XCTAssertEqual(history.first?.score, result.score)
    }

    func testPlay() throws {
        let pack: PlayPack = try fixture("play_pack")
        XCTAssertEqual(pack.questions.count, 6)
        for question in pack.questions {
            let reveal = try XCTUnwrap(question.reveal)
            XCTAssertNotNil(question.conceptId)
            XCTAssertNotNil(question.difficulty)
            XCTAssertTrue((0 ... 1).contains(try XCTUnwrap(question.expected)))
            // L'évaluateur local doit accepter la bonne réponse telle que le serveur l'exprime.
            let given: GivenAnswer
            switch question.type {
            case .mcq, .mapPick: given = .option(try XCTUnwrap(reveal.answer.optionId))
            case .trueFalse: given = .bool(try XCTUnwrap(reveal.answer.value?.boolValue))
            case .numeric: given = .number(Decimal(try XCTUnwrap(reveal.answer.value?.doubleValue)))
            case .ordering: given = .order(try XCTUnwrap(reveal.answer.order))
            case .pairs: given = .pairs(try XCTUnwrap(reveal.answer.pairs))
            }
            XCTAssertEqual(AnswerEvaluator.isCorrect(given, for: question), true, question.prompt)
        }
        let submit: PlaySubmitResult = try fixture("play_submit")
        XCTAssertEqual(submit.recorded, 6)
        XCTAssertEqual(submit.correct, 6)
        XCTAssertGreaterThan(try XCTUnwrap(submit.points), 6 * 50)
        let ratings = try XCTUnwrap(submit.ratings)
        XCTAssertFalse(ratings.isEmpty)
        XCTAssertTrue(ratings.allSatisfy { $0.delta > 0 && !$0.placed })
        XCTAssertTrue(submit.results.allSatisfy { ($0.points ?? 0) > 0 })
    }

    func testQuestsAndRecap() throws {
        let quests: QuestsOverview = try fixture("quests")
        XCTAssertEqual(quests.day.quests.count, 3)
        XCTAssertEqual(quests.week.quests.count, 3)
        XCTAssertEqual(quests.day.quests.first?.label, "Fais le 5 du jour")
        XCTAssertGreaterThan(quests.day.endsAt, quests.day.endsAt.addingTimeInterval(-86_400), "date ISO 8601 décodée")
        XCTAssertTrue(quests.day.quests.allSatisfy { $0.progress <= $0.target })
        let weeks: [WeekRecap] = try fixture("weekly_recap")
        XCTAssertFalse(weeks.isEmpty)
        XCTAssertGreaterThan(weeks[0].answers, 0)
        XCTAssertNotNil(weeks[0].rate)
        let history: [DailyHistoryEntry] = try fixture("history")
        let finished = try XCTUnwrap(history.first { $0.status != "in_progress" })
        XCTAssertEqual(finished.rate, (finished.score ?? 0) * 20)
        XCTAssertNotNil(finished.percentile)
    }

    func testProfileAndStats() throws {
        let profile: Profile = try fixture("profile")
        XCTAssertEqual(profile.handle, "alice_fx")
        XCTAssertGreaterThan(profile.xpTotal, 0)
        let skills: [SkillSummary] = try fixture("skills")
        XCTAssertEqual(skills.count, 12)
        let stats: DomainStats = try fixture("domain_stats")
        XCTAssertEqual(stats.domainId, "geography")
        XCTAssertFalse(stats.subdomains.isEmpty)
        XCTAssertNotNil(stats.cote)
        XCTAssertNotNil(stats.placement)
        XCTAssertTrue(skills.allSatisfy { $0.cote != nil && $0.placed != nil })
        XCTAssertTrue(stats.subdomains.allSatisfy { $0.cote != nil })
        let errors: ErrorsOverview = try fixture("errors")
        XCTAssertGreaterThanOrEqual(errors.active.count, 1)
        let achievements: [AchievementRef] = try fixture("achievements")
        XCTAssertTrue(achievements.contains { $0.unlockedAt != nil }, "dates ISO 8601 décodées")
        let domains: [DomainInfo] = try fixture("domains")
        XCTAssertEqual(domains.count, 12)
    }

    func testSocial() throws {
        let friends: FriendsOverview = try fixture("friends")
        XCTAssertEqual(friends.friends.first?.handle, "bruno_fx")
        let league: LeagueStandings = try fixture("league")
        XCTAssertEqual(league.name, "Les Curieux")
        XCTAssertEqual(league.standings.first?.isMe, true)
        let leagues: [LeagueSummary] = try fixture("leagues")
        XCTAssertEqual(leagues.first?.members, 1)
    }
}
