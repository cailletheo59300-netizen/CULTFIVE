import Foundation

/// Cote CULT : lecture du niveau de connaissance μ (0–100) sur une échelle façon échecs.
/// cote = 1000 + 17,37 × (μ − 50) : 400 points d'écart = 10 contre 1 de chances de réussite. 1000 = niveau médian.
/// Tant que le domaine a moins de 50 réponses classées (≈ 5 parties), le joueur est en placement : la cote reste cachée.
public struct CoteCULT: Hashable, Sendable {
    public static let placementAnswers = 50
    public static let placementGames = 5

    public let cote: Int
    public let answered: Int
    public let placed: Bool

    public init(cote: Int, answered: Int, placed: Bool? = nil) {
        self.cote = cote
        self.answered = answered
        self.placed = placed ?? (answered >= CoteCULT.placementAnswers)
    }

    public static func cote(level mu: Double) -> Int {
        Int((1000 + 17.37 * (mu - 50)).rounded())
    }

    /// Parties de placement jouées (0–5), à raison de 10 réponses par partie.
    public var placementGames: Int { min(CoteCULT.placementGames, answered / 10) }
    public var rank: Rank { Rank(cote: cote) }

    /// Cote globale : moyenne des domaines pondérée par le nombre de réponses. Placée dès 50 réponses classées au total.
    public static func global(_ skills: [SkillSummary]) -> CoteCULT? {
        let played = skills.filter { $0.answered > 0 }
        let total = played.reduce(0) { $0 + $1.answered }
        guard total > 0 else { return nil }
        let weighted = played.reduce(0.0) { $0 + Double($1.rating.cote) * Double($1.answered) } / Double(total)
        return CoteCULT(cote: Int(weighted.rounded()), answered: total)
    }

    /// « 1 342 » (espace fine insécable des milliers, à la française).
    public var formatted: String { CoteCULT.format(cote) }

    public static func format(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// « +18 », « −7 », « = ».
    public static func formatDelta(_ delta: Int) -> String {
        delta > 0 ? "+\(delta)" : delta < 0 ? "−\(-delta)" : "="
    }

    public enum Rank: Int, CaseIterable, Sendable, Comparable {
        case curious, amateur, enlightened, scholar, expert, encyclopedia

        public init(cote: Int) {
            self = Rank.allCases.last { cote >= $0.floor } ?? .curious
        }

        /// Cote minimale du rang.
        public var floor: Int {
            switch self {
            case .curious: return Int.min
            case .amateur: return 900
            case .enlightened: return 1050
            case .scholar: return 1200
            case .expert: return 1350
            case .encyclopedia: return 1500
            }
        }

        public var name: String {
            switch self {
            case .curious: return "Curieux"
            case .amateur: return "Amateur"
            case .enlightened: return "Éclairé"
            case .scholar: return "Érudit"
            case .expert: return "Expert"
            case .encyclopedia: return "Encyclopédie"
            }
        }

        public var next: Rank? { Rank(rawValue: rawValue + 1) }

        public static func < (a: Rank, b: Rank) -> Bool { a.rawValue < b.rawValue }
    }

    /// Progression vers le rang suivant (0–1) et points restants.
    public var toNextRank: (progress: Double, missing: Int)? {
        guard let next = rank.next else { return nil }
        let start = rank == .curious ? next.floor - 150 : rank.floor
        let progress = Double(cote - start) / Double(next.floor - start)
        return (min(max(progress, 0), 1), next.floor - cote)
    }
}

/// Difficulté ressentie d'une question pour ce joueur, d'après ses chances de réussite estimées.
public enum RelativeDifficulty: Int, Sendable, CaseIterable {
    case easy, medium, hard, veryHard

    public init(expected p: Double) {
        switch p {
        case 0.70...: self = .easy
        case 0.50..<0.70: self = .medium
        case 0.35..<0.50: self = .hard
        default: self = .veryHard
        }
    }

    public var label: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        case .veryHard: return "Très difficile"
        }
    }
}

/// Points d'une réponse (même règle que le serveur) : 50 + 100 × (1 − chances) + bonus de vitesse (≤ 30 sous 15 s).
public enum GamePoints {
    public static func points(correct: Bool, expected: Double?, responseMs: Int) -> Int {
        guard correct else { return 0 }
        let p = min(max(expected ?? 0.5, 0), 1)
        let speed = responseMs < 800 ? 0 : max(0, Int((30 * Double(15000 - responseMs) / 15000).rounded()))
        return 50 + Int((100 * (1 - p)).rounded()) + speed
    }
}

/// Ordre adaptatif dans une partie : après 3 bonnes réponses d'affilée, la question restante la plus dure ;
/// après 2 erreurs d'affilée, la plus accessible ; sinon l'ordre du serveur (déjà varié).
public enum AdaptiveOrder {
    public static func nextIndex(remaining: [Question], correctStreak: Int, wrongStreak: Int) -> Int {
        guard remaining.count > 1 else { return 0 }
        let chances = remaining.map { $0.expected ?? 0.6 }
        if correctStreak >= 3, let i = chances.indices.min(by: { chances[$0] < chances[$1] }) { return i }
        if wrongStreak >= 2, let i = chances.indices.max(by: { chances[$0] < chances[$1] }) { return i }
        return 0
    }
}
