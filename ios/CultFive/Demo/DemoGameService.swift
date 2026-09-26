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

    /// Moteur de jeu prêt (banque chargée, niveaux et erreurs d'exemple).
    private func engine() throws -> DemoPlayEngine {
        let engine = DemoPlayEngine.shared
        let skills: [SkillSummary] = (try? fixture("skills")) ?? []
        let profile: Profile? = try? fixture("profile")
        engine.prepare(skills: skills, activeErrors: profile?.activeErrors ?? 0) {
            (try? fixture("play_bank", as: [DemoPlayEngine.Entry].self)) ?? []
        }
        return engine
    }

    func playPack(mode: PlayMode, domain: String?, subdomains: [String], count: Int, ranked: Bool,
                  level: PlayLevel) async throws -> PlayPack {
        try engine().pack(mode: mode, domain: domain, subdomains: subdomains, count: count, ranked: ranked, level: level)
    }

    func playSubmit(session: UUID, attempts: [PlayAttempt]) async throws -> PlaySubmitResult {
        let engine = try engine()
        var result = engine.submit(session: session, attempts: attempts)
        let profile = try await self.profile()
        result["balance"] = .number(Double(profile.seeds))
        return try decode(.object(result))
    }

    func spendHelp(session: UUID, question: UUID, kind: HelpKind) async throws -> HelpContent {
        let engine = try engine()
        guard let entry = engine.entry(question) else { throw BackendError.decoding("question inconnue") }
        var content: [String: JSONValue] = [:]
        switch kind {
        case .fiftyFifty:
            let wrong = (entry.question.payload.options ?? []).map(\.id).filter { $0 != entry.question.reveal?.answer.optionId }
            content["remove"] = .array(wrong.shuffled().prefix(max(wrong.count - 1, 0)).map(JSONValue.string))
        case .hint:
            guard let hint = entry.hint else { throw BackendError.decoding("pas d'indice") }
            content["hint"] = .string(hint)
        case .context:
            guard let context = entry.context else { throw BackendError.decoding("pas de contexte") }
            content["context"] = .string(context)
        }
        engine.spendSeeds(kind.cost)
        content["balance"] = .number(Double(try await profile().seeds))
        return try decode(.object(content))
    }

    // MARK: Profil

    /// Profil d'exemple, avec les graines et les erreurs de la séance de démo.
    func profile() async throws -> Profile {
        let engine = try engine()
        var json: JSONValue = try fixture("profile")
        if case .object(var dict) = json {
            dict["active_errors"] = .number(Double(engine.activeErrors))
            dict["seeds"] = .number(Double((dict["seeds"]?.doubleValue ?? 0) + Double(engine.seeds)))
            json = .object(dict)
        }
        return try decode(json)
    }
    func handleAvailable(_ handle: String) async throws -> HandleAvailability {
        try decode(.object(["available": .bool(true)]))
    }
    func setHandle(_ handle: String) async throws -> Profile { try await profile() }
    func updateProfile(_ fields: [String: JSONValue]) async throws -> Profile { try await profile() }
    func completeOnboarding(level: String, interests: [String]) async throws -> Profile { try await profile() }
    func setTimezone(_ identifier: String) async throws {}
    func registerDevice(hash: String) async throws {}
    func skills() async throws -> [SkillSummary] {
        let engine = try engine()
        let skills: [SkillSummary] = try fixture("skills")
        return skills.map { s in
            guard let level = engine.level(s.domainId) else { return s }
            return (try? decode(JSONValue.object(["domain_id": .string(s.domainId), "name": .string(s.name),
                                                   "level": .number(level.rounded()), "reliability": .number(s.reliability),
                                                   "answered": .number(Double(s.answered)), "correct": .number(Double(s.correct))]))) ?? s
        }
    }

    /// Statistiques d'exemple ramenées au domaine demandé (niveau, thèmes, courbe).
    func domainStats(_ domain: String) async throws -> DomainStats {
        let engine = try engine()
        var json: JSONValue = try fixture("domain_stats")
        guard case .object(var dict) = json else { return try decode(json) }
        let skill = try await skills().first { $0.domainId == domain }
        let level = Double(skill?.level ?? 50)
        let shift = level - (dict["level"]?.doubleValue ?? level)
        dict["domain_id"] = .string(domain)
        dict["level"] = .number(level)
        dict["answered"] = .number(Double(skill?.answered ?? 0))
        dict["correct"] = .number(Double(skill?.correct ?? 0))
        if case .array(let points)? = dict["history"] {
            dict["history"] = .array(points.map { p -> JSONValue in
                guard case .object(var point) = p else { return p }
                point["level"] = .number((((point["level"]?.doubleValue ?? level) + shift) * 10).rounded() / 10)
                return .object(point)
            })
        }
        let subs: [SubdomainInfo] = try fixture("subdomains")
        dict["subdomains"] = .array(subs.filter { $0.domainId == domain }.enumerated().map { (i, sub) -> JSONValue in
            .object(["id": .string(sub.id), "name": .string(sub.name), "level": .number(level + Double(i % 3 * 4 - 4)),
                     "reliability": .number(0.5), "answered": .number(Double(skill?.answered ?? 0) / 3), "correct": .number(0),
                     "available": .number(Double(engine.available(subdomain: sub.id)))])
        })
        dict["recent_errors"] = .array([])
        json = .object(dict)
        return try decode(json)
    }
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
