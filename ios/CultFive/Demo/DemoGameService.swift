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

    /// Actif avec l'argument `-demo`, ou automatiquement quand aucun serveur n'est configuré
    /// (build de démonstration : simulateur, Appetize.io).
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-demo") || AppConfig.backend == nil }

    static var screen: Screen? {
        guard isActive else { return nil }
        return Screen(rawValue: UserDefaults.standard.string(forKey: "demoScreen") ?? "home") ?? .home
    }
}

/// Réponses du 5 du jour données pendant la démo : le résultat reflète ce que le joueur a vraiment répondu.
final class DemoDailyRecorder: @unchecked Sendable {
    static let shared = DemoDailyRecorder()
    private let lock = NSLock()
    private var answers: [Int: (correct: Bool, ms: Int)] = [:]

    func record(position: Int, correct: Bool, ms: Int) {
        lock.lock(); defer { lock.unlock() }
        if answers[position] == nil { answers[position] = (correct, ms) }
    }

    /// Les 5 réponses, dans l'ordre, une fois la série complète.
    var completed: [(correct: Bool, ms: Int)]? {
        lock.lock(); defer { lock.unlock() }
        let list = (1...5).compactMap { answers[$0] }
        return list.count == 5 ? list : nil
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

    private var playedDaily: Bool { DemoDailyRecorder.shared.completed != nil }

    func dailyStatus() async throws -> DailyStatus {
        let status: DailyStatus = try fixture("daily_status")
        guard screen == .result || screen == .share || playedDaily else { return status }
        let result = try await dailyResult(date: nil)
        return DailyStatus(date: status.date, state: .done, runId: result.runId, score: result.score,
                           answers: result.answers.map(\.isCorrect), streak: status.streak + 1,
                           streakFreezes: status.streakFreezes, secondsUntilNext: status.secondsUntilNext)
    }

    func dailyStart() async throws -> DailyStart {
        let start: DailyStart = try fixture("daily_start")
        guard screen == .result || screen == .share || playedDaily else { return start }
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
        let ms = min(max(clientMs ?? 6000, 300), 120_000)
        DemoDailyRecorder.shared.record(position: position, correct: correct, ms: ms)
        let reveal = try XCTUnwrapDemo(item.question.reveal)
        var dict: [String: JSONValue] = [
            "position": .number(Double(position)), "is_correct": .bool(correct), "duplicate": .bool(false),
            "counted_ms": .number(Double(ms)), "finished": .bool(position >= 5),
            "explanation": .string(reveal.explanation), "answer": try decode(JSONValue.self, from: reveal.answer),
        ]
        if let takeaway = reveal.takeaway { dict["takeaway"] = .string(takeaway) }
        return try decode(.object(dict))
    }

    /// Résultat enregistré (percentile, série, graines d'exemple), recalculé sur les réponses réellement données.
    func dailyResult(date: String?) async throws -> DailyResult {
        guard let played = DemoDailyRecorder.shared.completed else { return try fixture("daily_result") }
        var json: JSONValue = try fixture("daily_result")
        let status: DailyStatus = try fixture("daily_status")
        guard case .object(var dict) = json, case .array(let answers)? = dict["answers"] else { return try decode(json) }
        dict["answers"] = .array(answers.enumerated().map { (index, answer) -> JSONValue in
            guard case .object(var a) = answer, index < played.count else { return answer }
            let before = a["domain_before"]?.doubleValue ?? 50
            a["is_correct"] = .bool(played[index].correct)
            a["counted_ms"] = .number(Double(played[index].ms))
            a["domain_after"] = .number(((before + (played[index].correct ? 0.4 : -0.9)) * 10).rounded() / 10)
            return .object(a)
        })
        let score = played.filter(\.correct).count
        dict["score"] = .number(Double(score))
        dict["total_ms"] = .number(Double(played.reduce(0) { $0 + $1.ms }))
        dict["date"] = .string(status.date)
        dict["xp"] = .number(Double(20 + 10 * score))
        json = .object(dict)
        return try decode(json)
    }
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
    func setHandle(_ handle: String) async throws -> Profile { try await profile() }
    func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile { try await profile() }
    func completeOnboarding(level: String, interests: [String]) async throws -> Profile { try await profile() }
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
