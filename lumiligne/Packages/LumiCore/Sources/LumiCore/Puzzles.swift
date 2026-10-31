import Foundation

/// Jours de la grille du jour. Un jour va de minuit à minuit en heure universelle (UTC), soit 1 h ou 2 h du matin en
/// France : tout le monde a la même grille en même temps, comme le classement quotidien de Game Center (00:00 UTC).
public enum DayKey {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// « 2026-10-31 ».
    public static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func today(_ now: Date = Date()) -> String { key(for: now) }

    /// Le jour d'avant (« 2026-10-30 » pour « 2026-10-31 »).
    public static func previous(_ day: String) -> String? {
        guard let date = date(of: day), let before = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return key(for: before)
    }

    public static func date(of day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Jour de la semaine : 1 = lundi … 7 = dimanche.
    public static func weekday(_ day: String) -> Int {
        guard let date = date(of: day) else { return 1 }
        let sundayFirst = calendar.component(.weekday, from: date) // 1 = dimanche
        return sundayFirst == 1 ? 7 : sundayFirst - 1
    }

    /// Temps restant avant la prochaine grille du jour.
    public static func secondsUntilNextDay(_ now: Date = Date()) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return max(0, next.timeIntervalSince(now))
    }
}

/// Les trois sortes de grilles.
public enum PuzzleKind: Equatable, Hashable, Sendable {
    /// Niveau numéroté (1, 2, 3…), à faire dans l'ordre.
    case level(Int)
    /// Grille du jour, la même pour tout le monde.
    case daily(String)
    /// Grille bonus du jour, débloquée avec une pub une fois la grille du jour finie.
    case bonus(String)

    /// Clé de sauvegarde (grille commencée).
    public var key: String {
        switch self {
        case .level(let number): "level-\(number)"
        case .daily(let day): "daily-\(day)"
        case .bonus(let day): "bonus-\(day)"
        }
    }

    public var title: String {
        switch self {
        case .level(let number): "Niveau \(number)"
        case .daily: "Grille du jour"
        case .bonus: "Grille bonus"
        }
    }
}

/// Taille, difficulté et graine de chaque grille. Changer une valeur ici change les grilles des joueurs :
/// à faire avant la sortie (voir docs/REGLES.md).
public enum Puzzles {
    public struct Plan: Equatable, Sendable {
        public let size: Int
        public let difficulty: Difficulty
        public let seed: UInt64
    }

    public static func plan(_ kind: PuzzleKind) -> Plan {
        switch kind {
        case .level(let number):
            return Plan(size: levelSize(number), difficulty: levelDifficulty(number),
                        seed: SeededRandom.seed(from: "lumiligne-level-\(number)"))
        case .daily(let day):
            // Du lundi au dimanche : la grille grandit un peu au fil de la semaine.
            let week: [(Int, Difficulty)] = [(6, .medium), (6, .hard), (7, .medium), (7, .hard), (7, .hard), (8, .medium), (8, .hard)]
            let (size, difficulty) = week[DayKey.weekday(day) - 1]
            return Plan(size: size, difficulty: difficulty, seed: SeededRandom.seed(from: "lumiligne-daily-\(day)"))
        case .bonus(let day):
            return Plan(size: 8, difficulty: .hard, seed: SeededRandom.seed(from: "lumiligne-bonus-\(day)"))
        }
    }

    public static func grid(_ kind: PuzzleKind) -> Grid {
        let plan = plan(kind)
        return Generator.grid(size: plan.size, difficulty: plan.difficulty, seed: plan.seed)
    }

    /// Taille des niveaux : 5 × 5 pour apprendre, puis la grille grandit jusqu'à 9 × 9.
    public static func levelSize(_ number: Int) -> Int {
        switch number {
        case ...10: 5
        case ...35: 6
        case ...80: 7
        case ...150: 8
        default: 9
        }
    }

    /// Difficulté des niveaux : les 5 premiers faciles, puis un cycle facile, moyen, moyen, difficile.
    public static func levelDifficulty(_ number: Int) -> Difficulty {
        if number <= 5 { return .easy }
        switch number % 4 {
        case 0: return .hard
        case 1: return .easy
        default: return .medium
        }
    }
}
