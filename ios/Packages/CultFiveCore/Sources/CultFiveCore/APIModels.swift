import Foundation

// Modèles des réponses RPC. Clés explicites (snake_case serveur) : aucune conversion automatique,
// pour ne jamais altérer les clés des payloads JSON (identifiants d'options, paires…).

// MARK: - Daily

public enum DailyState: String, Codable, Sendable {
    case available
    case inProgress = "in_progress"
    case done
}

public struct DailyStatus: Codable, Hashable, Sendable {
    public let date: String
    public let state: DailyState
    public let runId: UUID?
    public let nextPosition: Int?
    public let score: Int?
    public let answers: [Bool]
    public let streak: Int
    public let streakFreezes: Int
    public let secondsUntilNext: Int

    enum CodingKeys: String, CodingKey {
        case date, state, score, answers, streak
        case runId = "run_id"
        case nextPosition = "next_position"
        case streakFreezes = "streak_freezes"
        case secondsUntilNext = "seconds_until_next"
    }

    public init(date: String, state: DailyState, runId: UUID? = nil, nextPosition: Int? = nil, score: Int? = nil,
                answers: [Bool] = [], streak: Int = 0, streakFreezes: Int = 0, secondsUntilNext: Int = 0) {
        self.date = date
        self.state = state
        self.runId = runId
        self.nextPosition = nextPosition
        self.score = score
        self.answers = answers
        self.streak = streak
        self.streakFreezes = streakFreezes
        self.secondsUntilNext = secondsUntilNext
    }
}

public struct DailyStart: Codable, Hashable, Sendable {
    public let runId: UUID
    public let date: String
    public let status: String
    public let nextPosition: Int?
    public let total: Int

    enum CodingKeys: String, CodingKey {
        case date, status, total
        case runId = "run_id"
        case nextPosition = "next_position"
    }
}

/// Réponse de `daily_question` : une question, ou `expired` si le délai est dépassé.
public struct DailyQuestionResponse: Decodable, Sendable {
    public let question: Question?
    public let expired: Bool

    public init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)
        if json["expired"]?.boolValue == true {
            question = nil
            expired = true
        } else {
            question = try Question(from: decoder)
            expired = false
        }
    }
}

public struct DailyVerdict: Codable, Hashable, Sendable {
    public let position: Int
    public let isCorrect: Bool?
    public let duplicate: Bool?
    public let countedMs: Int?
    public let errorTransition: String?
    public let domainId: String?
    public let domainBefore: Double?
    public let domainAfter: Double?
    public let finished: Bool?
    public let expired: Bool?
    public let answer: CorrectAnswer?
    public let explanation: String?
    public let takeaway: String?
    public let source: String?

    enum CodingKeys: String, CodingKey {
        case position, duplicate, finished, expired, answer, explanation, takeaway, source
        case isCorrect = "is_correct"
        case countedMs = "counted_ms"
        case errorTransition = "error_transition"
        case domainId = "domain_id"
        case domainBefore = "domain_before"
        case domainAfter = "domain_after"
    }

    public var reveal: Reveal? {
        guard let answer, let explanation else { return nil }
        return Reveal(answer: answer, explanation: explanation, takeaway: takeaway, source: source)
    }
}

public struct Percentile: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable { case live, estimate }
    public let top: Int?
    public let source: Source
    public let participants: Int

    public init(top: Int?, source: Source, participants: Int) {
        self.top = top
        self.source = source
        self.participants = participants
    }
}

public struct AchievementRef: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let unlockedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case unlockedAt = "unlocked_at"
    }
}

public struct DailyResult: Codable, Hashable, Sendable {
    public struct Answer: Codable, Hashable, Sendable {
        public let position: Int
        public let isCorrect: Bool
        public let countedMs: Int?
        public let domainId: String
        public let domainBefore: Double?
        public let domainAfter: Double?

        enum CodingKeys: String, CodingKey {
            case position
            case isCorrect = "is_correct"
            case countedMs = "counted_ms"
            case domainId = "domain_id"
            case domainBefore = "domain_before"
            case domainAfter = "domain_after"
        }
    }

    public let runId: UUID
    public let date: String
    public let status: String
    public let score: Int
    public let totalMs: Int
    public let xp: Int
    public let seeds: Int
    public let streak: Int
    public let achievements: [AchievementRef]
    public let answers: [Answer]
    public let percentile: Percentile?

    enum CodingKeys: String, CodingKey {
        case date, status, score, xp, seeds, streak, achievements, answers, percentile
        case runId = "run_id"
        case totalMs = "total_ms"
    }
}

public struct ReviewItem: Codable, Hashable, Identifiable, Sendable {
    public let question: Question
    public let given: GivenAnswer?
    public let isCorrect: Bool
    public let countedMs: Int?
    public var id: UUID { question.id }

    enum CodingKeys: String, CodingKey {
        case given
        case isCorrect = "is_correct"
        case countedMs = "counted_ms"
    }

    public init(from decoder: Decoder) throws {
        question = try Question(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        given = try? c.decodeIfPresent(GivenAnswer.self, forKey: .given)
        isCorrect = try c.decode(Bool.self, forKey: .isCorrect)
        countedMs = try c.decodeIfPresent(Int.self, forKey: .countedMs)
    }

    public func encode(to encoder: Encoder) throws {
        try question.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(given, forKey: .given)
        try c.encode(isCorrect, forKey: .isCorrect)
        try c.encodeIfPresent(countedMs, forKey: .countedMs)
    }
}

public struct DailyHistoryEntry: Codable, Hashable, Sendable {
    public let date: String
    public let status: String
    public let score: Int?
    public let totalMs: Int?
    /// % de bonnes réponses (score × 20) et classement (« top 12 % »), une fois le 5 du jour terminé.
    public let rate: Int?
    public let percentile: Percentile?
    public var top: Int? { percentile?.top }

    enum CodingKeys: String, CodingKey {
        case date, status, score, rate, percentile
        case totalMs = "total_ms"
    }

    public init(date: String, status: String, score: Int?, totalMs: Int?, rate: Int? = nil, percentile: Percentile? = nil) {
        self.date = date
        self.status = status
        self.score = score
        self.totalMs = totalMs
        self.rate = rate
        self.percentile = percentile
    }
}

// MARK: - Objectifs et récap

/// Objectifs du jour et de la semaine. La progression est calculée par le serveur ; les récompenses tombent à la lecture.
public struct QuestsOverview: Codable, Hashable, Sendable {
    public struct Quest: Codable, Hashable, Identifiable, Sendable {
        public let slot: Int
        public let label: String
        public let target: Int
        public let progress: Int
        public let done: Bool
        public let xp: Int
        public let seeds: Int
        public var id: Int { slot }

        public init(slot: Int, label: String, target: Int, progress: Int, done: Bool, xp: Int, seeds: Int) {
            self.slot = slot
            self.label = label
            self.target = target
            self.progress = progress
            self.done = done
            self.xp = xp
            self.seeds = seeds
        }
    }

    public struct Bonus: Codable, Hashable, Sendable {
        public let xp: Int
        public let seeds: Int
        public let done: Bool
        /// Coffre gagné quand les trois défis sont remplis (« wood », « silver », « gold ») ; nil avant les coffres.
        public let chest: String?

        public init(xp: Int, seeds: Int, done: Bool, chest: String? = nil) {
            self.xp = xp
            self.seeds = seeds
            self.done = done
            self.chest = chest
        }
    }

    public struct Period: Codable, Hashable, Sendable {
        public let periodStart: String
        public let endsAt: Date
        public let quests: [Quest]
        public let bonus: Bonus

        public var doneCount: Int { quests.filter(\.done).count }

        enum CodingKeys: String, CodingKey {
            case quests, bonus
            case periodStart = "period_start"
            case endsAt = "ends_at"
        }

        public init(periodStart: String, endsAt: Date, quests: [Quest], bonus: Bonus) {
            self.periodStart = periodStart
            self.endsAt = endsAt
            self.quests = quests
            self.bonus = bonus
        }
    }

    /// Objectif rempli à l'instant (à célébrer).
    public struct Reward: Codable, Hashable, Sendable {
        public let label: String
        public let xp: Int
        public let seeds: Int
        public let bonus: Bool?
        public let chest: String?

        public init(label: String, xp: Int, seeds: Int, bonus: Bool? = nil, chest: String? = nil) {
            self.label = label
            self.xp = xp
            self.seeds = seeds
            self.bonus = bonus
            self.chest = chest
        }
    }

    public let day: Period
    public let week: Period
    public let newly: [Reward]
    public let balance: Int?

    public init(day: Period, week: Period, newly: [Reward], balance: Int? = nil) {
        self.day = day
        self.week = week
        self.newly = newly
        self.balance = balance
    }
}

/// Une semaine du récap (profil), du lundi au dimanche.
public struct WeekRecap: Codable, Hashable, Identifiable, Sendable {
    public struct CoteMove: Codable, Hashable, Sendable {
        public let domainId: String
        public let delta: Int

        enum CodingKeys: String, CodingKey {
            case delta
            case domainId = "domain_id"
        }

        public init(domainId: String, delta: Int) {
            self.domainId = domainId
            self.delta = delta
        }
    }

    public let weekStart: String
    public let answers: Int
    public let correct: Int
    public let games: Int
    public let dailies: Int
    public let dailyAvg: Double?
    public let errorsCorrected: Int
    public let questsDone: Int
    public let coteMoves: [CoteMove]
    public var id: String { weekStart }

    /// % de bonnes réponses de la semaine.
    public var rate: Int? { answers > 0 ? Int((Double(correct) / Double(answers) * 100).rounded()) : nil }
    public var isEmpty: Bool { answers == 0 && dailies == 0 }

    enum CodingKeys: String, CodingKey {
        case answers, correct, games, dailies
        case weekStart = "week_start"
        case dailyAvg = "daily_avg"
        case errorsCorrected = "errors_corrected"
        case questsDone = "quests_done"
        case coteMoves = "cote_moves"
    }

    public init(weekStart: String, answers: Int, correct: Int, games: Int, dailies: Int, dailyAvg: Double?,
                errorsCorrected: Int, questsDone: Int, coteMoves: [CoteMove]) {
        self.weekStart = weekStart
        self.answers = answers
        self.correct = correct
        self.games = games
        self.dailies = dailies
        self.dailyAvg = dailyAvg
        self.errorsCorrected = errorsCorrected
        self.questsDone = questsDone
        self.coteMoves = coteMoves
    }
}

// MARK: - Jouer

public enum PlayMode: String, Codable, Sendable, CaseIterable {
    case quick, training, surprise, errors, challenge
}

/// Difficulté d'un entraînement libre. `adaptive` = selon le niveau du joueur (seul choix en partie classée).
public enum PlayLevel: String, Codable, Sendable, CaseIterable {
    case adaptive, beginner, intermediate, expert
}

public struct PlayPack: Codable, Hashable, Sendable {
    public let sessionId: UUID
    public let mode: String?
    public let questions: [Question]
    /// Partie classée (le niveau bouge) ou entraînement libre.
    public let ranked: Bool?
    public let level: String?

    enum CodingKeys: String, CodingKey {
        case mode, questions, ranked, level
        case sessionId = "session_id"
    }

    public init(sessionId: UUID, mode: String?, questions: [Question], ranked: Bool? = nil, level: String? = nil) {
        self.sessionId = sessionId
        self.mode = mode
        self.questions = questions
        self.ranked = ranked
        self.level = level
    }
}

public struct PlayAttempt: Codable, Hashable, Sendable {
    public let clientAttemptId: UUID
    public let questionId: UUID
    public let given: GivenAnswer?
    public let responseMs: Int

    enum CodingKeys: String, CodingKey {
        case given
        case clientAttemptId = "client_attempt_id"
        case questionId = "question_id"
        case responseMs = "response_ms"
    }

    public init(clientAttemptId: UUID = UUID(), questionId: UUID, given: GivenAnswer?, responseMs: Int) {
        self.clientAttemptId = clientAttemptId
        self.questionId = questionId
        self.given = given
        self.responseMs = responseMs
    }
}

public struct PlaySubmitResult: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Sendable {
        public let questionId: UUID
        public let isCorrect: Bool?
        public let errorTransition: String?
        public let domainBefore: Double?
        public let domainAfter: Double?
        /// Points de la question (0 si ratée).
        public let points: Int?

        enum CodingKeys: String, CodingKey {
            case questionId = "question_id"
            case isCorrect = "is_correct"
            case errorTransition = "error_transition"
            case domainBefore = "domain_before"
            case domainAfter = "domain_after"
            case points
        }
    }

    /// Variation de cote d'un domaine sur la partie (partie classée seulement).
    public struct RatingChange: Codable, Hashable, Sendable {
        public let domainId: String
        public let coteBefore: Int
        public let coteAfter: Int
        public let answered: Int
        public let placement: Int
        public let placed: Bool

        public var delta: Int { coteAfter - coteBefore }

        enum CodingKeys: String, CodingKey {
            case answered, placement, placed
            case domainId = "domain_id"
            case coteBefore = "cote_before"
            case coteAfter = "cote_after"
        }

        public init(domainId: String, coteBefore: Int, coteAfter: Int, answered: Int, placement: Int, placed: Bool) {
            self.domainId = domainId
            self.coteBefore = coteBefore
            self.coteAfter = coteAfter
            self.answered = answered
            self.placement = placement
            self.placed = placed
        }
    }

    public let recorded: Int
    public let correct: Int
    public let xp: Int
    public let seeds: Int
    public let corrected: [UUID]
    public let results: [Item]
    public let achievements: [String]
    public let balance: Int
    /// Points de la partie (difficulté + vitesse).
    public let points: Int?
    public let ratings: [RatingChange]?
}

public enum HelpKind: String, Codable, Sendable, CaseIterable {
    case fiftyFifty = "fifty_fifty"
    case hint
    case context

    public var cost: Int {
        switch self {
        case .fiftyFifty: return 15
        case .hint: return 10
        case .context: return 5
        }
    }
}

public struct HelpContent: Codable, Hashable, Sendable {
    public let remove: [String]?
    public let hint: String?
    public let context: String?
    public let balance: Int
}

// MARK: - Profil, compétences

public struct Profile: Codable, Hashable, Sendable {
    public let id: UUID
    public let handle: String
    public let avatar: JSONValue?
    public let ageRange: String?
    public let timezone: String
    public let challengePrior: Double
    public let interests: [String]
    public let xpTotal: Int
    public let seeds: Int
    public let streak: Int
    public let streakBest: Int
    public let streakFreezes: Int
    public let questionsAnswered: Int
    public let questionsCorrect: Int
    public let errorsCorrected: Int
    public let activeErrors: Int
    public let referralCode: String
    public let notifDaily: Bool
    public let notifDailyTime: String
    public let notifReminder: Bool
    public let onboarded: Bool
    public let isAnonymous: Bool

    enum CodingKeys: String, CodingKey {
        case id, handle, avatar, timezone, interests, seeds, streak, onboarded
        case ageRange = "age_range"
        case challengePrior = "challenge_prior"
        case xpTotal = "xp_total"
        case streakBest = "streak_best"
        case streakFreezes = "streak_freezes"
        case questionsAnswered = "questions_answered"
        case questionsCorrect = "questions_correct"
        case errorsCorrected = "errors_corrected"
        case activeErrors = "active_errors"
        case referralCode = "referral_code"
        case notifDaily = "notif_daily"
        case notifDailyTime = "notif_daily_time"
        case notifReminder = "notif_reminder"
        case isAnonymous = "is_anonymous"
    }
}

public struct HandleAvailability: Codable, Hashable, Sendable {
    public let available: Bool
    public let reason: String?
}

public struct SkillSummary: Codable, Hashable, Identifiable, Sendable {
    public let domainId: String
    public let name: String
    public let level: Int
    public let reliability: Double
    public let answered: Int
    public let correct: Int
    /// Cote CULT (1000 = niveau médian) ; affichée seulement une fois le placement terminé.
    public let cote: Int?
    /// Parties de placement jouées (0–5).
    public let placement: Int?
    public let placed: Bool?
    public var id: String { domainId }

    enum CodingKeys: String, CodingKey {
        case name, level, reliability, answered, correct, cote, placement, placed
        case domainId = "domain_id"
    }

    public init(domainId: String, name: String, level: Int, reliability: Double, answered: Int, correct: Int,
                cote: Int? = nil, placement: Int? = nil, placed: Bool? = nil) {
        self.domainId = domainId
        self.name = name
        self.level = level
        self.reliability = reliability
        self.answered = answered
        self.correct = correct
        self.cote = cote
        self.placement = placement
        self.placed = placed
    }

    /// Cote de ce domaine (calculée depuis le niveau si le serveur ne l'envoie pas).
    public var rating: CoteCULT { CoteCULT(cote: cote ?? CoteCULT.cote(level: Double(level)), answered: answered, placed: placed) }
}

public struct DomainStats: Codable, Hashable, Sendable {
    public struct Subdomain: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let level: Int
        public let reliability: Double
        public let answered: Int
        public let correct: Int
        public let available: Int
        public let cote: Int?
        public let placed: Bool?

        public init(id: String, name: String, level: Int, reliability: Double, answered: Int, correct: Int, available: Int,
                    cote: Int? = nil, placed: Bool? = nil) {
            self.id = id
            self.name = name
            self.level = level
            self.reliability = reliability
            self.answered = answered
            self.correct = correct
            self.available = available
            self.cote = cote
            self.placed = placed
        }

        public var rating: CoteCULT { CoteCULT(cote: cote ?? CoteCULT.cote(level: Double(level)), answered: answered, placed: placed) }
    }

    public struct HistoryPoint: Codable, Hashable, Sendable {
        public let day: String
        public let level: Double
    }

    public struct DifficultyBand: Codable, Hashable, Sendable {
        public let band: String
        public let answered: Int
        public let correct: Int
    }

    public struct RecentError: Codable, Hashable, Identifiable, Sendable {
        public let conceptId: String
        public let label: String
        public let state: String
        public var id: String { conceptId }

        enum CodingKeys: String, CodingKey {
            case label, state
            case conceptId = "concept_id"
        }
    }

    public let domainId: String
    public let level: Int
    public let reliability: Double
    public let answered: Int
    public let correct: Int
    public let avgMs: Int?
    public let conceptsMastered: Int
    public let history: [HistoryPoint]
    public let subdomains: [Subdomain]
    public let byDifficulty: [DifficultyBand]
    public let recentErrors: [RecentError]
    public let cote: Int?
    public let placement: Int?
    public let placed: Bool?

    public var rating: CoteCULT { CoteCULT(cote: cote ?? CoteCULT.cote(level: Double(level)), answered: answered, placed: placed) }

    enum CodingKeys: String, CodingKey {
        case level, reliability, answered, correct, history, subdomains, cote, placement, placed
        case domainId = "domain_id"
        case avgMs = "avg_ms"
        case conceptsMastered = "concepts_mastered"
        case byDifficulty = "by_difficulty"
        case recentErrors = "recent_errors"
    }
}

public struct ErrorsOverview: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Identifiable, Sendable {
        public let conceptId: String
        public let label: String
        public let domainId: String
        public let state: String
        public let timesFailed: Int
        public var id: String { conceptId }

        enum CodingKeys: String, CodingKey {
            case label, state
            case conceptId = "concept_id"
            case domainId = "domain_id"
            case timesFailed = "times_failed"
        }
    }

    public let active: [Item]
    public let correctedTotal: Int
    public let masteredTotal: Int

    enum CodingKeys: String, CodingKey {
        case active
        case correctedTotal = "corrected_total"
        case masteredTotal = "mastered_total"
    }
}

// MARK: - Social

public struct FriendToday: Codable, Hashable, Sendable {
    public let score: Int?
    public let totalMs: Int?
    public let status: String?
    public let answers: [Bool]?

    enum CodingKeys: String, CodingKey {
        case score, status, answers
        case totalMs = "total_ms"
    }
}

public struct Friend: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let handle: String
    public let avatar: JSONValue?
    public let streak: Int
    public let today: FriendToday?
}

public struct FriendRequest: Codable, Hashable, Identifiable, Sendable {
    public let friendshipId: UUID
    public let userId: UUID
    public let handle: String
    public var id: UUID { friendshipId }

    enum CodingKeys: String, CodingKey {
        case handle
        case friendshipId = "friendship_id"
        case userId = "id"
    }
}

public struct FriendsOverview: Codable, Hashable, Sendable {
    public let friends: [Friend]
    public let incoming: [FriendRequest]
    public let outgoing: [FriendRequest]
}

public struct HandleSearchResult: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let handle: String
    public let relation: String
    public let incoming: Bool?
}

public struct FriendRequestResult: Codable, Hashable, Sendable {
    public let status: String
}

public struct ReferralClaimResult: Codable, Hashable, Sendable {
    public let status: String
    public let reason: String?
    public let seeds: Int?
    public let inviter: String?
}

public struct ReferralOverview: Codable, Hashable, Sendable {
    public let code: String
    public let qualified: Int
    public let pending: Int
    public let tiers: [Int]
}

public enum LeaguePeriod: String, Codable, Sendable, CaseIterable {
    case week, month
}

public struct LeagueSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let period: LeaguePeriod
    public let members: Int
    public let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name, period, members
        case inviteCode = "invite_code"
    }
}

public struct LeagueStandings: Codable, Hashable, Sendable {
    public struct Row: Codable, Hashable, Identifiable, Sendable {
        public let rank: Int
        public let id: UUID
        public let handle: String
        public let points: Int
        public let days: Int
        public let totalMs: Int
        public let isMe: Bool

        enum CodingKeys: String, CodingKey {
            case rank, id, handle, points, days
            case totalMs = "total_ms"
            case isMe = "is_me"
        }
    }

    public let id: UUID
    public let name: String
    public let period: LeaguePeriod
    public let inviteCode: String
    public let isOwner: Bool
    public let startDate: String
    public let endDate: String
    public let standings: [Row]

    enum CodingKeys: String, CodingKey {
        case id, name, period, standings
        case inviteCode = "invite_code"
        case isOwner = "is_owner"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - Référentiel

public struct DomainInfo: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let dailySlot: String?
    public let sort: Int

    enum CodingKeys: String, CodingKey {
        case id, name, sort
        case dailySlot = "daily_slot"
    }

    public init(id: String, name: String, dailySlot: String?, sort: Int) {
        self.id = id
        self.name = name
        self.dailySlot = dailySlot
        self.sort = sort
    }
}

public struct SubdomainInfo: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let domainId: String
    public let name: String
    public let sort: Int

    enum CodingKeys: String, CodingKey {
        case id, name, sort
        case domainId = "domain_id"
    }
}

// MARK: - Duels

/// Duel entre deux joueurs sur les mêmes 5 questions. Le score adverse n'est connu qu'une fois sa propre partie finie.
public struct Duel: Codable, Hashable, Identifiable, Sendable {
    public struct Opponent: Codable, Hashable, Sendable {
        public let id: UUID?
        public let handle: String?
        public let answered: Int
        public let score: Int?
        public let totalMs: Int?

        enum CodingKeys: String, CodingKey {
            case id, handle, answered, score
            case totalMs = "total_ms"
        }
    }

    public struct Mine: Codable, Hashable, Sendable {
        public let answered: Int
        public let score: Int
        public let totalMs: Int

        enum CodingKeys: String, CodingKey {
            case answered, score
            case totalMs = "total_ms"
        }
    }

    public struct Mark: Codable, Hashable, Sendable {
        public let position: Int
        public let isCorrect: Bool?
        public let countedMs: Int?

        enum CodingKeys: String, CodingKey {
            case position
            case isCorrect = "is_correct"
            case countedMs = "counted_ms"
        }
    }

    public let id: UUID
    public let code: String
    /// open (lien, personne n'a rejoint) · active · finished · declined · expired
    public let status: String
    public let expiresAt: String?
    public let iAmChallenger: Bool
    public let opponent: Opponent?
    public let me: Mine
    public let myTurn: Bool
    /// me · opponent · draw (duel terminé)
    public let winner: String?
    public let myAnswers: [Mark]?
    public let theirAnswers: [Mark]?

    enum CodingKeys: String, CodingKey {
        case id, code, status, opponent, me, winner
        case expiresAt = "expires_at"
        case iAmChallenger = "i_am_challenger"
        case myTurn = "my_turn"
        case myAnswers = "my_answers"
        case theirAnswers = "their_answers"
    }

    public var isFinished: Bool { status == "finished" }
}

/// Nom d'un coffre pour l'affichage : « Coffre en bois »…
public enum ChestName {
    public static func title(_ tier: String) -> String {
        switch tier {
        case "silver": return "Coffre en argent"
        case "gold": return "Coffre en or"
        default: return "Coffre en bois"
        }
    }
}
