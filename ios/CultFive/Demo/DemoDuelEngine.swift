#if DEBUG
import Foundation
import CultFiveCore

/// Duels de la démo : un adversaire simulé. Un défi reçu de Margaux (elle a déjà joué), un duel gagné contre Yanis_59 ;
/// quand tu défies un ami, il « joue » dès que tu as fini (score plausible, temps réaliste).
final class DemoDuelEngine: @unchecked Sendable {
    static let shared = DemoDuelEngine()

    private struct Player { var marks: [(correct: Bool, ms: Int)] = [] }
    private struct Match {
        let id: UUID
        let code: String
        var status: String
        let iAmChallenger: Bool
        let opponent: (id: UUID, handle: String)?
        let questions: [Question]
        var me = Player()
        var them = Player()
        var served: [Int: Date] = [:]
    }

    private let lock = NSLock()
    private var matches: [UUID: Match] = [:]
    private var order: [UUID] = []
    private var prepared = false

    func prepare(friends: [(UUID, String)], bank: [DemoPlayEngine.Entry]) {
        lock.lock(); defer { lock.unlock() }
        guard !prepared, !bank.isEmpty else { return }
        prepared = true
        let margaux = friends.first { $0.1 == "Margaux" } ?? friends.first ?? (UUID(), "Margaux")
        let yanis = friends.first { $0.1 == "Yanis_59" } ?? friends.last ?? (UUID(), "Yanis_59")
        var incoming = makeMatch(bank: bank, opponent: margaux, iAmChallenger: false, seed: 11)
        incoming.them.marks = [(true, 7200), (true, 9100), (false, 12400), (true, 6300), (true, 8800)]
        var won = makeMatch(bank: bank, opponent: yanis, iAmChallenger: true, seed: 23)
        won.me.marks = [(true, 6100), (true, 8200), (true, 7400), (false, 11900), (true, 5200)]
        won.them.marks = [(true, 9800), (false, 13100), (true, 8100), (false, 10500), (true, 9900)]
        won.status = "finished"
        for m in [won, incoming] { matches[m.id] = m; order.insert(m.id, at: 0) }
    }

    private func makeMatch(bank: [DemoPlayEngine.Entry], opponent: (UUID, String)?, iAmChallenger: Bool, seed: UInt64) -> Match {
        var rng = SeededRandom(seed: seed &+ UInt64(order.count))
        var picked: [Question] = []
        for domain in Array(Set(bank.map(\.question.domainId))).shuffled(using: &rng) where picked.count < 5 {
            if let q = bank.filter({ $0.question.domainId == domain && $0.question.type != .mapPick && (35...65).contains($0.difficulty) })
                .shuffled(using: &rng).first?.question { picked.append(q) }
        }
        let code = String((0..<6).map { _ in "ABCDEFGHJKMNPQRSTUVWXYZ23456789".randomElement(using: &rng)! })
        return Match(id: UUID(), code: code, status: opponent == nil ? "open" : "active", iAmChallenger: iAmChallenger,
                     opponent: opponent.map { (id: $0.0, handle: $0.1) }, questions: picked)
    }

    func create(opponent: (UUID, String)?, bank: [DemoPlayEngine.Entry]) -> [String: JSONValue] {
        lock.lock(); defer { lock.unlock() }
        let m = makeMatch(bank: bank, opponent: opponent, iAmChallenger: true, seed: UInt64(Date().timeIntervalSince1970))
        matches[m.id] = m
        order.insert(m.id, at: 0)
        return json(m, details: false)
    }

    func list() -> [JSONValue] {
        lock.lock(); defer { lock.unlock() }
        return order.compactMap { matches[$0] }.filter { $0.status != "declined" }.map { .object(json($0, details: false)) }
    }

    func result(_ id: UUID) -> [String: JSONValue]? {
        lock.lock(); defer { lock.unlock() }
        return matches[id].map { json($0, details: true) }
    }

    func decline(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        matches[id]?.status = "declined"
    }

    func question(_ id: UUID, position: Int) -> Question? {
        lock.lock(); defer { lock.unlock() }
        guard var m = matches[id], m.me.marks.count + 1 == position, m.questions.indices.contains(position - 1) else { return nil }
        m.served[position] = m.served[position] ?? Date()
        matches[id] = m
        return m.questions[position - 1]
    }

    func answer(_ id: UUID, position: Int, given: GivenAnswer?, clientMs: Int?) -> [String: JSONValue]? {
        lock.lock(); defer { lock.unlock() }
        guard var m = matches[id], m.questions.indices.contains(position - 1), let reveal = m.questions[position - 1].reveal else { return nil }
        let q = m.questions[position - 1]
        let correct = given.flatMap { AnswerEvaluator.isCorrect($0, for: q) } ?? false
        let served = m.served[position] ?? Date()
        let ms = min(max(clientMs ?? Int(Date().timeIntervalSince(served) * 1000), 300), 120_000)
        if m.me.marks.count < position { m.me.marks.append((correct, ms)) }
        if m.me.marks.count == 5, let _ = m.opponent {
            // L'adversaire simulé joue à son tour (s'il ne l'a pas déjà fait), puis le duel se clôt.
            if m.them.marks.isEmpty {
                let target = max(1, min(5, m.me.marks.filter { $0.correct }.count + [-1, 0, 0, 1].randomElement()!))
                let rights = Set((0..<5).shuffled().prefix(target))
                m.them.marks = (0..<5).map { (rights.contains($0), Int.random(in: 5_000...14_000)) }
            }
            m.status = "finished"
        }
        matches[m.id] = m
        var out: [String: JSONValue] = ["position": .number(Double(position)), "is_correct": .bool(correct), "duplicate": .bool(false),
                                        "counted_ms": .number(Double(ms)), "finished": .bool(position == 5),
                                        "explanation": .string(reveal.explanation)]
        if let data = try? JSONEncoder().encode(reveal.answer), let answer = try? JSONDecoder().decode(JSONValue.self, from: data) {
            out["answer"] = answer
        }
        if let takeaway = reveal.takeaway { out["takeaway"] = .string(takeaway) }
        return out
    }

    private func json(_ m: Match, details: Bool) -> [String: JSONValue] {
        let myScore = m.me.marks.filter { $0.correct }.count, myMs = m.me.marks.reduce(0) { $0 + $1.ms }
        let theirScore = m.them.marks.filter { $0.correct }.count, theirMs = m.them.marks.reduce(0) { $0 + $1.ms }
        let reveal = m.me.marks.count == 5 || m.status == "finished"
        var winner: JSONValue = .null
        if m.status == "finished" {
            winner = .string(myScore != theirScore ? (myScore > theirScore ? "me" : "opponent") : (myMs <= theirMs ? "me" : "opponent"))
        }
        let marks: ([(correct: Bool, ms: Int)]) -> JSONValue = { list in
            .array(list.enumerated().map { item -> JSONValue in
                .object(["position": .number(Double(item.offset + 1)), "is_correct": .bool(item.element.correct),
                         "counted_ms": .number(Double(item.element.ms))])
            })
        }
        var out: [String: JSONValue] = [
            "id": .string(m.id.uuidString), "code": .string(m.code), "status": .string(m.status),
            "expires_at": .string(ISO8601DateFormatter().string(from: Date().addingTimeInterval(36 * 3600))),
            "i_am_challenger": .bool(m.iAmChallenger),
            "opponent": m.opponent.map { o -> JSONValue in .object(["id": .string(o.id.uuidString), "handle": .string(o.handle),
                                                        "answered": .number(Double(m.them.marks.count)),
                                                        "score": reveal ? .number(Double(theirScore)) : .null,
                                                        "total_ms": reveal ? .number(Double(theirMs)) : .null]) } ?? .null,
            "me": .object(["answered": .number(Double(m.me.marks.count)), "score": .number(Double(myScore)), "total_ms": .number(Double(myMs))]),
            "my_turn": .bool((m.status == "open" || m.status == "active") && m.me.marks.count < 5),
            "winner": winner,
        ]
        if details {
            out["my_answers"] = marks(m.me.marks)
            out["their_answers"] = reveal ? marks(m.them.marks) : .null
        }
        return out
    }
}
#endif
