#if DEBUG
import Foundation
import CultFiveCore

/// Mode démo (builds Debug uniquement, exclu de Release) : l'app tourne sans serveur, sur des réponses RPC réelles
/// enregistrées depuis la base de test (scripts/gen-demo-fixtures.sh). Sert aux captures d'écran et aux essais sans compte.
/// Lancement : arguments `-demo -demoScreen <écran>` (voir `Demo.Screen`).
enum Demo {
    enum Screen: String {
        case onboarding, onboardingQuestion = "onboarding-question", home, question, reveal, result, share
        case play, domain, friends, league, profile
    }

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static var screen: Screen? {
        guard isActive else { return nil }
        return Screen(rawValue: UserDefaults.standard.string(forKey: "demoScreen") ?? "home") ?? .home
    }
}

struct DemoGameService: GameService {
    let screen: Demo.Screen

    private func fixture<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let url = Bundle.main.url(forResource: "\(name).demo", withExtension: "json") else {
            throw BackendError.decoding("fixture \(name) absente")
        }
        return try SupabaseAPI.decoder.decode(T.self, from: Data(contentsOf: url))
    }

    private func decode<T: Decodable>(_ json: JSONValue, as type: T.Type = T.self) throws -> T {
        try SupabaseAPI.decoder.decode(T.self, from: JSONEncoder().encode(json))
    }

    private var reviewItems: [ReviewItem] { (try? fixture("daily_review")) ?? [] }

    // MARK: Daily

    func dailyStatus() async throws -> DailyStatus {
        let status: DailyStatus = try fixture("daily_status")
        guard screen == .result || screen == .share else { return status }
        let result: DailyResult = try fixture("daily_result")
        return DailyStatus(date: status.date, state: .done, runId: result.runId, score: result.score,
                           answers: result.answers.map(\.isCorrect), streak: status.streak + 1,
                           streakFreezes: status.streakFreezes, secondsUntilNext: status.secondsUntilNext)
    }

    func dailyStart() async throws -> DailyStart {
        let start: DailyStart = try fixture("daily_start")
        guard screen == .result || screen == .share else { return start }
        return try decode(.object(["run_id": .string(start.runId.uuidString), "date": .string(start.date),
                                   "status": .string("finished"), "total": .number(5)]))
    }

    func dailyQuestion(run: UUID, position: Int) async throws -> DailyQuestionResponse {
        // Question de la veille (réponse connue) sans sa révélation, pour pouvoir simuler le verdict.
        let item = reviewItems[max(0, min(position - 1, reviewItems.count - 1))]
        var json = try decode(JSONValue.self, from: item.question)
        if case .object(var dict) = json {
            ["answer", "explanation", "takeaway", "source", "fact_as_of"].forEach { dict[$0] = nil }
            dict["position"] = .number(Double(position))
            json = .object(dict)
        }
        return try decode(json)
    }

    func dailyAnswer(run: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) async throws -> DailyVerdict {
        let item = reviewItems[max(0, min(position - 1, reviewItems.count - 1))]
        let correct = AnswerEvaluator.isCorrect(given, for: item.question) ?? false
        let reveal = try XCTUnwrapDemo(item.question.reveal)
        var dict: [String: JSONValue] = [
            "position": .number(Double(position)), "is_correct": .bool(correct), "duplicate": .bool(false),
            "counted_ms": .number(Double(clientMs ?? 6000)), "finished": .bool(position >= 5),
            "explanation": .string(reveal.explanation), "answer": try decode(JSONValue.self, from: reveal.answer),
        ]
        if let takeaway = reveal.takeaway { dict["takeaway"] = .string(takeaway) }
        return try decode(.object(dict))
    }

    func dailyResult(date: String?) async throws -> DailyResult { try fixture("daily_result") }
    func dailyReview(date: String?) async throws -> [ReviewItem] { reviewItems }
    func dailyHistory(days: Int) async throws -> [DailyHistoryEntry] { try fixture("history") }

    // MARK: Jouer

    func onboardingPack() async throws -> PlayPack {
        let pack: PlayPack = try fixture("play_pack")
        return try decode(.object(["session_id": .string(pack.sessionId.uuidString),
                                   "questions": try decode(JSONValue.self, from: Array(pack.questions.prefix(3)))]))
    }

    func playPack(mode: PlayMode, domain: String?, subdomain: String?, count: Int) async throws -> PlayPack {
        try fixture("play_pack")
    }

    func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult {
        try decode(.object(["recorded": .number(Double(attempts.count)), "correct": .number(0), "xp": .number(40),
                            "seeds": .number(2), "corrected": .array([]), "results": .array([]),
                            "achievements": .array([]), "balance": .number(546)]))
    }

    func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent { throw BackendError.offline }

    // MARK: Profil

    func profile() async throws -> Profile { try fixture("profile") }
    func handleAvailable(_ handle: String) async throws -> HandleAvailability {
        try decode(.object(["available": .bool(true)]))
    }
    func setHandle(_ handle: String) async throws -> Profile { try profile() }
    func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile { try profile() }
    func completeOnboarding(level: String, interests: [String]) async throws -> Profile { try profile() }
    func setTimezone(_ identifier: String) async throws {}
    func registerDevice(hash: String) async throws {}
    func skills() async throws -> [SkillSummary] { try fixture("skills") }
    func domainStats(_ domain: String) async throws -> DomainStats { try fixture("domain_stats") }
    func errors() async throws -> ErrorsOverview { try fixture("errors") }
    func achievements() async throws -> [AchievementRef] { try fixture("achievements") }
    func deleteAccount() async throws {}

    // MARK: Social

    func friends() async throws -> FriendsOverview { try fixture("friends") }
    func searchHandles(_ query: String) async throws -> [HandleSearchResult] { [] }
    func requestFriend(handle: String) async throws -> FriendRequestResult { try decode(.object(["status": .string("pending")])) }
    func respondFriend(friendship: UUID, accept: Bool) async throws {}
    func removeFriend(_ user: UUID) async throws {}
    func blockUser(_ user: UUID) async throws {}
    func claimReferral(code: String, deviceHash: String) async throws -> ReferralClaimResult {
        try decode(.object(["status": .string("rejected")]))
    }
    func referralOverview() async throws -> ReferralOverview { try fixture("referral") }
    func leagues() async throws -> [LeagueSummary] { try fixture("leagues") }
    func createLeague(name: String, period: LeaguePeriod) async throws -> LeagueStandings { try fixture("league") }
    func joinLeague(code: String) async throws -> LeagueStandings { try fixture("league") }
    func leaveLeague(_ id: UUID) async throws {}
    func leagueStandings(_ id: UUID, offset: Int) async throws -> LeagueStandings { try fixture("league") }

    // MARK: Référentiel

    func domains() async throws -> [DomainInfo] { try fixture("domains") }
    func subdomains() async throws -> [SubdomainInfo] { try fixture("subdomains") }
}

private extension DemoGameService {
    func decode<T: Decodable, U: Encodable>(_ type: T.Type, from value: U) throws -> T {
        try SupabaseAPI.decoder.decode(T.self, from: JSONEncoder().encode(value))
    }

    func XCTUnwrapDemo<T>(_ value: T?) throws -> T {
        guard let value else { throw BackendError.decoding("donnée de démo manquante") }
        return value
    }
}
#endif
