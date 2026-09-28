#if DEBUG
import Foundation
import CultFiveCore

/// Moteur de jeu de la démo : imite le serveur sur une vraie banque (Fixtures/play_bank, ~30 questions par domaine,
/// régénérée par scripts/gen-demo-bank.sh). Domaine et thèmes respectés, aucune question revue pendant la séance,
/// difficulté selon le niveau ou le choix, erreurs suivies, niveau qui bouge en partie classée seulement.
final class DemoPlayEngine: @unchecked Sendable {
    static let shared = DemoPlayEngine()

    struct Entry: Decodable {
        let question: Question
        let difficulty: Double
        let family: String?
        let hint: String?
        let context: String?

        enum CodingKeys: String, CodingKey { case difficulty, family, hint, context = "context_note" }

        init(from decoder: Decoder) throws {
            question = try Question(from: decoder)
            let c = try decoder.container(keyedBy: CodingKeys.self)
            difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty) ?? 50
            family = try c.decodeIfPresent(String.self, forKey: .family)
            hint = try c.decodeIfPresent(String.self, forKey: .hint)
            context = try c.decodeIfPresent(String.self, forKey: .context)
        }
    }

    private let lock = NSLock()
    private(set) var bank: [Entry] = []
    private var seen: Set<UUID> = []
    private var errors: [UUID] = []
    private var levels: [String: Double] = [:]
    /// Réponses classées par domaine (placement : cote dévoilée à 50).
    private var answered: [String: Int] = [:]
    private var sessions: [UUID: (ids: [UUID], ranked: Bool)] = [:]
    private var submitted: Set<UUID> = []
    private var seedsDelta = 0
    // Activité de la séance, pour les objectifs de la démo.
    private(set) var rankedGames = 0
    private(set) var answered = 0
    private(set) var correctByDomain: [String: Int] = [:]
    private(set) var correctedCount = 0
    private(set) var domainsPlayed: Set<String> = []
    private var claimed: Set<String> = []
    private var prepared = false

    /// Charge la banque et l'état initial (niveaux du profil d'exemple, erreurs « à revoir » du profil).
    func prepare(skills: [SkillSummary], activeErrors: Int, load: () -> [Entry]) {
        lock.lock(); defer { lock.unlock() }
        guard !prepared else { return }
        prepared = true
        bank = load()
        for skill in skills {
            levels[skill.domainId] = Double(skill.level)
            answered[skill.domainId] = skill.answered
        }
        var rng = SeededRandom(seed: 7)
        errors = Array(bank.map(\.question.id).shuffled(using: &rng).prefix(activeErrors))
    }

    var activeErrors: Int { lock.lock(); defer { lock.unlock() }; return errors.count }
    var seeds: Int { lock.lock(); defer { lock.unlock() }; return seedsDelta }
    func level(_ domain: String) -> Double? { lock.lock(); defer { lock.unlock() }; return levels[domain] }
    func answeredCount(_ domain: String) -> Int? { lock.lock(); defer { lock.unlock() }; return answered[domain] }

    /// Champs de cote, comme public._rating_json.
    static func ratingFields(level: Double, answered: Int, threshold: Int = CoteCULT.placementAnswers) -> [String: JSONValue] {
        ["cote": .number(Double(CoteCULT.cote(level: level))), "answered": .number(Double(answered)),
         "placement": .number(Double(min(5, answered * 5 / threshold))), "placed": .bool(answered >= threshold)]
    }
    func available(subdomain: String) -> Int { bank.filter { $0.question.subdomainId == subdomain }.count }
    func entry(_ id: UUID) -> Entry? { bank.first { $0.question.id == id } }

    // MARK: Pack

    func pack(mode: PlayMode, domain: String?, subdomains: [String], count: Int, ranked: Bool, level: PlayLevel) -> PlayPack {
        lock.lock(); defer { lock.unlock() }
        var picked: [Entry] = []
        if mode == .errors {
            picked = errors.compactMap { id in bank.first { $0.question.id == id } }.prefix(count).map { $0 }
        } else if let domain {
            picked = pick(from: bank.filter { $0.question.domainId == domain && (subdomains.isEmpty || subdomains.contains($0.question.subdomainId)) },
                          count: count, band: band(mode: mode, domain: domain, ranked: ranked, level: level))
        } else {
            // Parties multi-domaines : un domaine différent à chaque question, tant que possible.
            let domains = Array(Set(bank.map(\.question.domainId))).shuffled()
            for i in 0 ..< (domains.isEmpty ? 0 : count) {
                let d = domains[i % domains.count]
                let pool = bank.filter { $0.question.domainId == d && !picked.map(\.question.id).contains($0.question.id) }
                picked += pick(from: pool, count: 1, band: band(mode: mode, domain: d, ranked: true, level: .adaptive))
            }
        }
        let ids = picked.map(\.question.id)
        seen.formUnion(ids)
        let session = UUID()
        sessions[session] = (ids, mode == .errors ? true : ranked)
        // Comme le serveur : difficulté et chances de réussite estimées de chaque question.
        let questions = picked.map { entry -> Question in
            var q = entry.question
            let mu = levels[q.domainId] ?? 50
            q.difficulty = entry.difficulty
            q.expected = (DemoPlayEngine.chance(mu: mu, entry: entry) * 100).rounded() / 100
            return q
        }
        return PlayPack(sessionId: session, mode: mode.rawValue, questions: questions,
                        ranked: mode == .errors ? true : ranked, level: ranked ? "adaptive" : level.rawValue)
    }

    private func band(mode: PlayMode, domain: String, ranked: Bool, level: PlayLevel) -> ClosedRange<Double> {
        if !ranked {
            switch level {
            case .beginner: return 0 ... 40
            case .intermediate: return 35 ... 65
            case .expert: return 60 ... 100
            case .adaptive: break
            }
        }
        // Fenêtre de cote autour du joueur, comme le serveur (0015) : classé de −250 à +25 points de cote
        // (≈ 65 % de réussite), défi de −150 à +250. 1 point de niveau = 17,37 points de cote.
        let mu = levels[domain] ?? 50
        let window: (Double, Double) = mode == .challenge ? (-150, 250) : (-250, 25)
        return (mu + window.0 / 17.37) ... (mu + window.1 / 17.37)
    }

    /// Chances de réussite hasard compris (comme public._expect_q) : QCM 1/n, Vrai/Faux 1/2.
    static func chance(mu: Double, entry: Entry) -> Double {
        let q = entry.question
        let guess: Double
        switch q.type {
        case .mcq, .mapPick: guess = 1 / Double(max(q.payload.options?.count ?? 4, 2))
        case .trueFalse: guess = 0.5
        default: guess = 0
        }
        return guess + (1 - guess) / (1 + exp(-(mu - entry.difficulty) / 10))
    }

    /// Jamais une question déjà vue ; une seule par famille tant que possible ; la difficulté visée d'abord, puis élargie.
    private func pick(from pool: [Entry], count: Int, band: ClosedRange<Double>) -> [Entry] {
        var fresh = pool.filter { !seen.contains($0.question.id) }
        if fresh.isEmpty {
            // Tout a été vu dans ce périmètre : on recommence un cycle plutôt que de laisser le joueur sans partie.
            pool.forEach { seen.remove($0.question.id) }
            fresh = pool
        }
        fresh.shuffle()
        // Thèmes équilibrés : on alterne les thèmes (1er de chaque thème, puis 2e…), comme le serveur.
        var rank: [String: Int] = [:]
        fresh = fresh.map { e -> (Entry, Int) in
            let r = rank[e.question.subdomainId, default: 0]
            rank[e.question.subdomainId] = r + 1
            return (e, r)
        }.sorted { $0.1 < $1.1 }.map(\.0)
        var result: [Entry] = []
        var families: [String: Int] = [:]
        for (widen, perFamily) in [(0.0, 1), (10, 1), (20, 2), (100, 99)] {
            for entry in fresh where result.count < count && !result.contains(where: { $0.question.id == entry.question.id }) {
                guard entry.difficulty >= band.lowerBound - widen, entry.difficulty <= band.upperBound + widen else { continue }
                if let family = entry.family, families[family, default: 0] >= perFamily { continue }
                result.append(entry)
                if let family = entry.family { families[family, default: 0] += 1 }
            }
        }
        return result
    }

    // MARK: Soumission

    func submit(session: UUID, attempts: [PlayAttempt]) -> [String: JSONValue] {
        lock.lock(); defer { lock.unlock() }
        let ranked = sessions[session]?.ranked ?? true
        var correct = 0
        var corrected: [JSONValue] = []
        var results: [JSONValue] = []
        var points = 0
        var moves: [(domain: String, before: Double)] = []
        for attempt in attempts where !submitted.contains(attempt.clientAttemptId) {
            submitted.insert(attempt.clientAttemptId)
            guard let entry = bank.first(where: { $0.question.id == attempt.questionId }) else { continue }
            let ok = attempt.given.flatMap { AnswerEvaluator.isCorrect($0, for: entry.question) } ?? false
            var transition: JSONValue = .null
            if ok {
                correct += 1
                if let i = errors.firstIndex(of: entry.question.id) {
                    errors.remove(at: i)
                    transition = .string("corrected")
                    corrected.append(.string(entry.question.id.uuidString))
                }
            } else if !errors.contains(entry.question.id) {
                errors.append(entry.question.id)
                transition = .string("new_error")
            } else {
                transition = .string("still_wrong")
            }
            let domain = entry.question.domainId
            answered += 1
            domainsPlayed.insert(domain)
            if ok { correctByDomain[domain, default: 0] += 1 }
            if case .string("corrected") = transition { correctedCount += 1 }
            let before = levels[domain] ?? 50
            var after = before
            let expected = DemoPlayEngine.chance(mu: before, entry: entry)
            if ranked {
                // Bayésien simplifié : on bouge plus sur une surprise (bonne réponse difficile, erreur facile).
                // Placement (< 50 réponses) : pas doublé.
                let step: Double = (answered[domain] ?? 0) < CoteCULT.placementAnswers ? 8 : 4
                after = min(100, max(0, before + step * ((ok ? 1 : 0) - expected)))
                levels[domain] = after
                answered[domain, default: 0] += 1
                if !moves.contains(where: { $0.domain == domain }) { moves.append((domain, before)) }
            }
            let gained = GamePoints.points(correct: ok, expected: expected, responseMs: attempt.responseMs)
            points += gained
            results.append(.object([
                "question_id": .string(entry.question.id.uuidString), "is_correct": .bool(ok), "error_transition": transition,
                "domain_before": .number((before * 10).rounded() / 10), "domain_after": .number((after * 10).rounded() / 10),
                "points": .number(Double(gained)),
            ]))
        }
        if ranked && attempts.count >= 8 { rankedGames += 1 }
        let xp = correct * (ranked ? 5 : 3) + (attempts.count >= 5 ? (ranked ? 10 : 5) : 0)
        let seeds = ranked ? 2 * (correct / 5) : 0
        seedsDelta += seeds
        return ["recorded": .number(Double(results.count)), "correct": .number(Double(correct)), "xp": .number(Double(xp)),
                "seeds": .number(Double(seeds)), "corrected": .array(corrected), "results": .array(results),
                "achievements": .array([]), "ranked": .bool(ranked), "points": .number(Double(points)),
                "ratings": .array(moves.map { move -> JSONValue in
                    var fields = DemoPlayEngine.ratingFields(level: levels[move.domain] ?? 50, answered: answered[move.domain] ?? 0)
                    fields["cote"] = nil
                    fields["domain_id"] = .string(move.domain)
                    fields["cote_before"] = .number(Double(CoteCULT.cote(level: move.before)))
                    fields["cote_after"] = .number(Double(CoteCULT.cote(level: levels[move.domain] ?? 50)))
                    return .object(fields)
                })]
    }

    /// Récompense d'objectif, versée une seule fois par clé.
    func claim(_ key: String, seeds: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !claimed.contains(key) else { return false }
        claimed.insert(key)
        seedsDelta += seeds
        return true
    }
    func isClaimed(_ key: String) -> Bool { lock.lock(); defer { lock.unlock() }; return claimed.contains(key) }

    func spendSeeds(_ amount: Int) {
        lock.lock(); defer { lock.unlock() }
        seedsDelta -= amount
    }
}

/// Générateur déterministe (les mêmes erreurs d'exemple à chaque lancement).
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
