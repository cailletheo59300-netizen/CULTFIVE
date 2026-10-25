import Foundation

// Arène (serveur 0088, D-111) : duels classés en file commune, points de la semaine, classements et récompenses.

/// Un duel classé vu par le joueur.
public struct ArenaDuel: Codable, Hashable, Identifiable, Sendable {
    public struct Opponent: Codable, Hashable, Sendable {
        public let id: UUID
        public let handle: String
        /// Points de l'adversaire cette semaine.
        public let weekPoints: Int
        /// Champion de la semaine passée (couronne).
        public let champion: Bool
        public let answered: Int
        /// Révélé une fois sa propre partie finie.
        public let score: Int?
        public let totalMs: Int?

        enum CodingKeys: String, CodingKey {
            case id, handle, champion, answered, score
            case weekPoints = "week_points"
            case totalMs = "total_ms"
        }

        public init(id: UUID, handle: String, weekPoints: Int = 0, champion: Bool = false, answered: Int = 0,
                    score: Int? = nil, totalMs: Int? = nil) {
            self.id = id
            self.handle = handle
            self.weekPoints = weekPoints
            self.champion = champion
            self.answered = answered
            self.score = score
            self.totalMs = totalMs
        }
    }

    public struct Side: Codable, Hashable, Sendable {
        public let answered: Int
        public let score: Int
        public let totalMs: Int

        enum CodingKeys: String, CodingKey {
            case answered, score
            case totalMs = "total_ms"
        }

        public init(answered: Int = 0, score: Int = 0, totalMs: Int = 0) {
            self.answered = answered
            self.score = score
            self.totalMs = totalMs
        }
    }

    /// Ce que le duel a rapporté au joueur, une fois réglé.
    public struct Outcome: Codable, Hashable, Sendable {
        /// win · draw · loss
        public let outcome: String
        public let points: Int
        /// Victoires d'affilée après ce duel.
        public let streak: Int
        /// daily_chest · streak_chest · arena_chest
        public let bonus: [String]

        public init(outcome: String, points: Int, streak: Int = 0, bonus: [String] = []) {
            self.outcome = outcome
            self.points = points
            self.streak = streak
            self.bonus = bonus
        }
    }

    public let id: UUID
    /// open (personne ne l'a encore pris) · active · finished · expired
    public let status: String
    public let createdAt: Date?
    public let finishedAt: Date?
    public let total: Int
    public let seconds: Int
    public let opponent: Opponent?
    public let me: Side
    public let myTurn: Bool
    /// me · opponent · draw (duel terminé)
    public let winner: String?
    public let result: Outcome?

    enum CodingKeys: String, CodingKey {
        case id, status, total, seconds, opponent, me, winner, result
        case createdAt = "created_at"
        case finishedAt = "finished_at"
        case myTurn = "my_turn"
    }

    public init(id: UUID = UUID(), status: String = "open", createdAt: Date? = nil, finishedAt: Date? = nil, total: Int = 7,
                seconds: Int = 25, opponent: Opponent? = nil, me: Side = Side(), myTurn: Bool = true, winner: String? = nil,
                result: Outcome? = nil) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.finishedAt = finishedAt
        self.total = total
        self.seconds = seconds
        self.opponent = opponent
        self.me = me
        self.myTurn = myTurn
        self.winner = winner
        self.result = result
    }

    public var isFinished: Bool { status == "finished" }
    /// Joué en entier, en attente d'un adversaire dans la file.
    public var isWaiting: Bool { !myTurn && !isFinished && opponent == nil }
}

/// Réponse de « Trouver un adversaire ».
public struct ArenaMatch: Codable, Hashable, Sendable {
    public let duel: ArenaDuel
    /// Vrai : on affronte un joueur qui a déjà joué ; faux : on ouvre un duel à l'Arène.
    public let matched: Bool
    /// Duel commencé et repris.
    public let resumed: Bool

    public init(duel: ArenaDuel, matched: Bool, resumed: Bool = false) {
        self.duel = duel
        self.matched = matched
        self.resumed = resumed
    }
}

/// Une question de duel classé, avec le temps de l'adversaire s'il y a déjà répondu (jamais sa réponse).
public struct ArenaQuestionResponse: Decodable, Sendable {
    public let question: Question?
    public let expired: Bool
    public let seconds: Int
    public let themMs: Int?

    public init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)
        if json["expired"]?.boolValue == true {
            question = nil
            expired = true
            seconds = 25
            themMs = nil
        } else {
            question = try Question(from: decoder)
            expired = false
            seconds = json["seconds"]?.doubleValue.map { Int($0) } ?? 25
            themMs = json["them_ms"]?.doubleValue.map { Int($0) }
        }
    }

    public init(question: Question?, seconds: Int = 25, themMs: Int? = nil) {
        self.question = question
        self.expired = question == nil
        self.seconds = seconds
        self.themMs = themMs
    }
}

/// Correction d'une réponse, et ce qu'a fait l'adversaire sur la même question.
public struct ArenaVerdict: Codable, Hashable, Sendable {
    public struct Them: Codable, Hashable, Sendable {
        public let isCorrect: Bool?
        public let countedMs: Int?

        enum CodingKeys: String, CodingKey {
            case isCorrect = "is_correct"
            case countedMs = "counted_ms"
        }

        public init(isCorrect: Bool?, countedMs: Int?) {
            self.isCorrect = isCorrect
            self.countedMs = countedMs
        }
    }

    public let position: Int
    public let isCorrect: Bool?
    public let countedMs: Int?
    public let late: Bool?
    public let finished: Bool?
    public let myScore: Int?
    public let them: Them?
    public let themScore: Int?
    public let errorTransition: String?
    public let answer: CorrectAnswer?
    public let explanation: String?
    public let takeaway: String?
    public let source: String?

    enum CodingKeys: String, CodingKey {
        case position, late, finished, them, answer, explanation, takeaway, source
        case isCorrect = "is_correct"
        case countedMs = "counted_ms"
        case myScore = "my_score"
        case themScore = "them_score"
        case errorTransition = "error_transition"
    }

    public var reveal: Reveal? {
        guard let answer, let explanation else { return nil }
        return Reveal(answer: answer, explanation: explanation, takeaway: takeaway, source: source)
    }
}

/// Bilan d'un duel classé.
public struct ArenaDuelResult: Decodable, Hashable, Sendable {
    public struct Week: Codable, Hashable, Sendable {
        public let points: Int
        public let rank: Int
        public let duels: Int
        public let eligible: Bool

        public init(points: Int, rank: Int, duels: Int, eligible: Bool) {
            self.points = points
            self.rank = rank
            self.duels = duels
            self.eligible = eligible
        }
    }

    public let duel: ArenaDuel
    public let myAnswers: [Duel.Mark]
    public let theirAnswers: [Duel.Mark]?
    public let week: Week?
    public let chestProgress: Int
    public let chestEvery: Int

    enum CodingKeys: String, CodingKey {
        case week
        case myAnswers = "my_answers"
        case theirAnswers = "their_answers"
        case chestProgress = "chest_progress"
        case chestEvery = "chest_every"
    }

    public init(from decoder: Decoder) throws {
        duel = try ArenaDuel(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myAnswers = try c.decodeIfPresent([Duel.Mark].self, forKey: .myAnswers) ?? []
        theirAnswers = try c.decodeIfPresent([Duel.Mark].self, forKey: .theirAnswers)
        week = try c.decodeIfPresent(Week.self, forKey: .week)
        chestProgress = try c.decodeIfPresent(Int.self, forKey: .chestProgress) ?? 0
        chestEvery = try c.decodeIfPresent(Int.self, forKey: .chestEvery) ?? 10
    }

    public init(duel: ArenaDuel, myAnswers: [Duel.Mark] = [], theirAnswers: [Duel.Mark]? = nil, week: Week? = nil,
                chestProgress: Int = 0, chestEvery: Int = 10) {
        self.duel = duel
        self.myAnswers = myAnswers
        self.theirAnswers = theirAnswers
        self.week = week
        self.chestProgress = chestProgress
        self.chestEvery = chestEvery
    }
}

/// Une ligne de classement.
public struct ArenaRow: Codable, Hashable, Identifiable, Sendable {
    public let rank: Int
    public let id: UUID
    public let handle: String
    public let points: Int
    public let wins: Int
    public let duels: Int
    /// 5 duels au moins dans la semaine : classé pour les récompenses.
    public let eligible: Bool
    public let me: Bool
    public let champion: Bool

    public init(rank: Int, id: UUID = UUID(), handle: String, points: Int, wins: Int = 0, duels: Int = 0, eligible: Bool = true,
                me: Bool = false, champion: Bool = false) {
        self.rank = rank
        self.id = id
        self.handle = handle
        self.points = points
        self.wins = wins
        self.duels = duels
        self.eligible = eligible
        self.me = me
        self.champion = champion
    }
}

/// Récompense d'une place (ou d'une tranche de places) en fin de semaine.
public struct ArenaPrize: Codable, Hashable, Sendable {
    /// Tranche de places (`to` absent : « et au-delà »). Absente pour une récompense reçue.
    public let from: Int?
    public let to: Int?
    public let gold: Int?
    public let silver: Int?
    public let wood: Int?
    /// legend · epic : carte garantie de cette rareté.
    public let card: String?
    public let seeds: Int?
    public let packs: Int?
    public let trophy: String?
    public let cosmetic: String?
    public let crown: Bool?
    /// Carte reçue (récompense versée).
    public let cardPull: AlbumPull?

    enum CodingKeys: String, CodingKey {
        case from, to, gold, silver, wood, card, seeds, packs, trophy, cosmetic, crown
        case cardPull = "card_pull"
    }

    public init(from: Int? = nil, to: Int? = nil, gold: Int? = nil, silver: Int? = nil, wood: Int? = nil, card: String? = nil,
                seeds: Int? = nil, packs: Int? = nil, trophy: String? = nil, cosmetic: String? = nil, crown: Bool? = nil,
                cardPull: AlbumPull? = nil) {
        self.from = from
        self.to = to
        self.gold = gold
        self.silver = silver
        self.wood = wood
        self.card = card
        self.seeds = seeds
        self.packs = packs
        self.trophy = trophy
        self.cosmetic = cosmetic
        self.crown = crown
        self.cardPull = cardPull
    }
}

/// Récompenses de fin de semaine reçues, pas encore montrées.
public struct ArenaWeekReward: Codable, Hashable, Sendable {
    public let week: String
    public let rank: Int
    public let points: Int
    public let eligible: Bool
    public let prizes: ArenaPrize

    public init(week: String, rank: Int, points: Int, eligible: Bool, prizes: ArenaPrize) {
        self.week = week
        self.rank = rank
        self.points = points
        self.eligible = eligible
        self.prizes = prizes
    }
}

/// Tout l'onglet Arène en un appel.
public struct ArenaOverview: Codable, Hashable, Sendable {
    public struct Me: Codable, Hashable, Sendable {
        public let points: Int
        public let wins: Int
        public let duels: Int
        public let rank: Int?
        public let eligible: Bool
        public let minDuels: Int
        public let champion: Bool

        enum CodingKeys: String, CodingKey {
            case points, wins, duels, rank, eligible, champion
            case minDuels = "min_duels"
        }

        public init(points: Int = 0, wins: Int = 0, duels: Int = 0, rank: Int? = nil, eligible: Bool = false, minDuels: Int = 5,
                    champion: Bool = false) {
            self.points = points
            self.wins = wins
            self.duels = duels
            self.rank = rank
            self.eligible = eligible
            self.minDuels = minDuels
            self.champion = champion
        }
    }

    public struct Champion: Codable, Hashable, Sendable {
        public let id: UUID
        public let handle: String

        public init(id: UUID, handle: String) {
            self.id = id
            self.handle = handle
        }
    }

    public struct Chest: Codable, Hashable, Sendable {
        public let progress: Int
        public let goal: Int

        public init(progress: Int = 0, goal: Int = 10) {
            self.progress = progress
            self.goal = goal
        }
    }

    public struct Rules: Codable, Hashable, Sendable {
        public let questions: Int
        public let seconds: Int
        public let win: Int
        public let draw: Int
        public let streakFrom: Int
        public let streakChest: Int

        enum CodingKeys: String, CodingKey {
            case questions, seconds, win, draw
            case streakFrom = "streak_from"
            case streakChest = "streak_chest"
        }

        public init(questions: Int = 7, seconds: Int = 25, win: Int = 3, draw: Int = 1, streakFrom: Int = 3, streakChest: Int = 5) {
            self.questions = questions
            self.seconds = seconds
            self.win = win
            self.draw = draw
            self.streakFrom = streakFrom
            self.streakChest = streakChest
        }
    }

    public let week: String
    public let endsAt: Date
    public let me: Me
    public let players: Int
    public let top: [ArenaRow]
    public let champion: Champion?
    public let streak: Int
    public let winsTotal: Int
    public let chest: Chest
    /// Le coffre du 1er duel gagné du jour est encore à gagner.
    public let dailyChest: Bool
    /// Duels d'autres joueurs qui attendent un adversaire.
    public let waiting: Int
    public let prizes: [ArenaPrize]
    public let rules: Rules
    public let reward: ArenaWeekReward?
    public let duels: [ArenaDuel]

    enum CodingKeys: String, CodingKey {
        case week, me, players, top, champion, streak, chest, waiting, prizes, rules, reward, duels
        case endsAt = "ends_at"
        case winsTotal = "wins_total"
        case dailyChest = "daily_chest"
    }

    public init(week: String = "", endsAt: Date = Date().addingTimeInterval(3 * 86_400), me: Me = Me(), players: Int = 0,
                top: [ArenaRow] = [], champion: Champion? = nil, streak: Int = 0, winsTotal: Int = 0, chest: Chest = Chest(),
                dailyChest: Bool = true, waiting: Int = 0, prizes: [ArenaPrize] = [], rules: Rules = Rules(),
                reward: ArenaWeekReward? = nil, duels: [ArenaDuel] = []) {
        self.week = week
        self.endsAt = endsAt
        self.me = me
        self.players = players
        self.top = top
        self.champion = champion
        self.streak = streak
        self.winsTotal = winsTotal
        self.chest = chest
        self.dailyChest = dailyChest
        self.waiting = waiting
        self.prizes = prizes
        self.rules = rules
        self.reward = reward
        self.duels = duels
    }
}

/// Classement complet.
public struct ArenaLeaderboard: Codable, Hashable, Sendable {
    public enum Scope: String, Codable, CaseIterable, Sendable {
        case week, friends, all
    }

    public let scope: Scope
    public let endsAt: Date?
    public let rows: [ArenaRow]
    public let me: ArenaRow?
    public let minDuels: Int
    public let prizes: [ArenaPrize]

    enum CodingKeys: String, CodingKey {
        case scope, rows, me, prizes
        case endsAt = "ends_at"
        case minDuels = "min_duels"
    }

    public init(scope: Scope = .week, endsAt: Date? = nil, rows: [ArenaRow] = [], me: ArenaRow? = nil, minDuels: Int = 5,
                prizes: [ArenaPrize] = []) {
        self.scope = scope
        self.endsAt = endsAt
        self.rows = rows
        self.me = me
        self.minDuels = minDuels
        self.prizes = prizes
    }
}
