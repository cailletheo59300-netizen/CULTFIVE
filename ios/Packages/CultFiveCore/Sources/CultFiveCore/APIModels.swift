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
    /// Seconde chance : la première réponse (fausse) ; `given` est alors le second essai.
    public let firstGiven: GivenAnswer?

    enum CodingKeys: String, CodingKey {
        case given
        case clientAttemptId = "client_attempt_id"
        case questionId = "question_id"
        case responseMs = "response_ms"
        case firstGiven = "first_given"
    }

    public init(clientAttemptId: UUID = UUID(), questionId: UUID, given: GivenAnswer?, responseMs: Int, firstGiven: GivenAnswer? = nil) {
        self.clientAttemptId = clientAttemptId
        self.questionId = questionId
        self.given = given
        self.responseMs = responseMs
        self.firstGiven = firstGiven
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
    /// Réessayer après une mauvaise réponse, avant de voir la correction (moitié des points).
    case secondChance = "second_chance"

    public var cost: Int {
        switch self {
        case .fiftyFifty: return 15
        case .hint: return 10
        case .context: return 5
        case .secondChance: return 15
        }
    }
}

public struct HelpContent: Codable, Hashable, Sendable {
    public let remove: [String]?
    public let hint: String?
    public let context: String?
    public let balance: Int
    /// Un ticket d'aide a remplacé les graines ; tickets de ce type restants.
    public let ticketUsed: Bool?
    public let ticketsLeft: Int?

    enum CodingKeys: String, CodingKey {
        case remove, hint, context, balance
        case ticketUsed = "ticket_used"
        case ticketsLeft = "tickets_left"
    }
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
    /// Notifications push « Duels et amis » et « Ligues » (absentes sur un ancien serveur : activées).
    public let notifSocial: Bool?
    public let notifLeagues: Bool?
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
        case notifSocial = "notif_social"
        case notifLeagues = "notif_leagues"
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
    /// upcoming · active · finished
    public let status: String?
    public let myRank: Int?
    public let daysLeft: Int?
    public let startsIn: Int?
    public let questionCount: Int?
    /// Quiz du jour de la ligue : todo · in_progress · done (nil hors saison).
    public let todayState: String?

    enum CodingKeys: String, CodingKey {
        case id, name, period, members, status
        case inviteCode = "invite_code"
        case myRank = "my_rank"
        case daysLeft = "days_left"
        case startsIn = "starts_in"
        case questionCount = "question_count"
        case todayState = "today_state"
    }
}

/// Réglages d'une ligue.
public struct LeagueSettings: Codable, Hashable, Sendable {
    public static let counts = [5, 10, 15, 20]
    public static let memberLimits = [5, 10, 20, 50]

    public var questionCount: Int
    /// nil ou vide = tous les domaines.
    public var domains: [String]?
    public var difficulty: String
    /// 1w · 2w · 1m
    public var duration: String
    public var maxMembers: Int

    public init(questionCount: Int = 5, domains: [String]? = nil, difficulty: String = "auto", duration: String = "1w",
                maxMembers: Int = 50) {
        self.questionCount = questionCount
        self.domains = domains
        self.difficulty = difficulty
        self.duration = duration
        self.maxMembers = maxMembers
    }

    enum CodingKeys: String, CodingKey {
        case domains, difficulty, duration
        case questionCount = "question_count"
        case maxMembers = "max_members"
    }
}

/// Création d'une ligue.
public struct LeagueDraft: Hashable, Sendable {
    public var name: String
    public var settings: LeagueSettings
    public var startToday: Bool

    public init(name: String = "", settings: LeagueSettings = LeagueSettings(), startToday: Bool = true) {
        self.name = name
        self.settings = settings
        self.startToday = startToday
    }
}

/// Aperçu d'une ligue avant de la rejoindre (par code ou lien).
public struct LeaguePreview: Decodable, Hashable, Sendable {
    public let found: Bool
    public let error: String?
    public let code: String?
    public let name: String?
    public let owner: String?
    public let members: Int?
    public let maxMembers: Int?
    public let isMember: Bool?
    public let status: String?
    public let startsOn: String?
    public let endsOn: String?
    public let daysLeft: Int?
    public let settings: LeagueSettings?

    enum CodingKeys: String, CodingKey {
        case found, error, code, name, owner, members, status, settings
        case maxMembers = "max_members"
        case isMember = "is_member"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case daysLeft = "days_left"
    }
}

/// Résultat du quiz du jour d'une ligue : mes réponses, et les scores des membres une fois mon quiz fini.
public struct LeagueDayResult: Decodable, Hashable, Sendable {
    public struct Me: Decodable, Hashable, Sendable {
        public let answered: Int
        public let score: Int
        public let totalMs: Int

        enum CodingKeys: String, CodingKey {
            case answered, score
            case totalMs = "total_ms"
        }
    }

    public struct Member: Decodable, Hashable, Identifiable, Sendable {
        public let id: UUID
        public let handle: String
        public let isMe: Bool
        public let answered: Int
        public let score: Int
        public let totalMs: Int

        enum CodingKeys: String, CodingKey {
            case id, handle, answered, score
            case isMe = "is_me"
            case totalMs = "total_ms"
        }
    }

    public let day: String
    public let total: Int
    public let me: Me
    public let myAnswers: [Duel.Mark]
    public let members: [Member]?

    enum CodingKeys: String, CodingKey {
        case day, total, me, members
        case myAnswers = "my_answers"
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
        public let isOwner: Bool?

        enum CodingKeys: String, CodingKey {
            case rank, id, handle, points, days
            case totalMs = "total_ms"
            case isMe = "is_me"
            case isOwner = "is_owner"
        }
    }

    /// Quiz du jour du joueur dans cette ligue.
    public struct Today: Codable, Hashable, Sendable {
        public let answered: Int
        public let score: Int
        public let total: Int
        /// todo · in_progress · done
        public let state: String
    }

    public let id: UUID
    public let name: String
    public let period: LeaguePeriod
    public let inviteCode: String
    public let isOwner: Bool
    public let startDate: String
    public let endDate: String
    public let standings: [Row]
    /// Règles du podium (coffres de fin de période) ; nil sur un ancien serveur.
    public let podium: Podium?
    /// Coffre gagné par le joueur sur cette période (podium), s'il y en a un.
    public let myReward: Reward?
    // Ligues v2 (absents sur un ancien serveur).
    public let season: Int?
    public let currentSeason: Int?
    public let hasPrevious: Bool?
    /// upcoming · active · finished
    public let status: String?
    public let timezone: String?
    public let totalDays: Int?
    public let dayIndex: Int?
    public let daysLeft: Int?
    public let startsIn: Int?
    public let endsAt: String?
    public let members: Int?
    public let settings: LeagueSettings?
    public let myToday: Today?

    public struct Podium: Codable, Hashable, Sendable {
        public let minPlayers: Int
        public let minDays: Int
        public let activePlayers: Int

        enum CodingKeys: String, CodingKey {
            case minPlayers = "min_players"
            case minDays = "min_days"
            case activePlayers = "active_players"
        }
    }

    public struct Reward: Codable, Hashable, Sendable {
        public let tier: ChestTier
        public let place: Int
    }

    enum CodingKeys: String, CodingKey {
        case id, name, period, standings, podium
        case inviteCode = "invite_code"
        case isOwner = "is_owner"
        case startDate = "start_date"
        case endDate = "end_date"
        case myReward = "my_reward"
        case season, status, timezone, members, settings
        case currentSeason = "current_season"
        case hasPrevious = "has_previous"
        case totalDays = "total_days"
        case dayIndex = "day_index"
        case daysLeft = "days_left"
        case startsIn = "starts_in"
        case endsAt = "ends_at"
        case myToday = "my_today"
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
    /// Nombre de questions (5 à 20) ; absent sur les anciens duels : 5.
    public let total: Int?
    /// Domaines choisis ; nil = tous.
    public let domains: [String]?
    /// auto · easy · medium · hard
    public let difficulty: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, code, status, opponent, me, winner, total, domains, difficulty
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case iAmChallenger = "i_am_challenger"
        case myTurn = "my_turn"
        case myAnswers = "my_answers"
        case theirAnswers = "their_answers"
    }

    public var isFinished: Bool { status == "finished" }
    public var questionCount: Int { total ?? 5 }
}

/// Difficulté d'un duel : automatique (niveau moyen des deux joueurs) ou choisie.
public enum DuelDifficulty: String, CaseIterable, Hashable, Sendable {
    case auto, easy, medium, hard

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }
}

/// Réglages d'un duel.
public struct DuelSettings: Hashable, Sendable {
    public static let counts = [5, 10, 15, 20]
    public var count: Int
    /// Vide = tous les domaines.
    public var domains: [String]
    public var difficulty: DuelDifficulty

    public init(count: Int = 5, domains: [String] = [], difficulty: DuelDifficulty = .auto) {
        self.count = count
        self.domains = domains
        self.difficulty = difficulty
    }
}

/// Profil d'un ami : son 5 du jour, son Elo, et notre face-à-face.
public struct FriendProfile: Decodable, Hashable, Sendable {
    public struct HeadToHead: Decodable, Hashable, Sendable {
        public struct Streak: Decodable, Hashable, Sendable {
            /// me · friend
            public let who: String
            public let count: Int
        }

        public struct Best: Decodable, Hashable, Sendable {
            public let score: Int
            public let total: Int
        }

        public let played: Int
        public let wins: Int
        public let losses: Int
        public let draws: Int
        public let questions: Int
        public let myRate: Int?
        public let theirRate: Int?
        public let streak: Streak?
        public let myBest: Best?

        enum CodingKeys: String, CodingKey {
            case played, wins, losses, draws, questions, streak
            case myRate = "my_rate"
            case theirRate = "their_rate"
            case myBest = "my_best"
        }
    }

    public let id: UUID
    public let handle: String
    public let streak: Int
    public let streakBest: Int
    public let xpTotal: Int
    public let cote: Int?
    public let cotePlaced: Bool
    public let today: FriendToday?
    public let headToHead: HeadToHead
    public let duels: [Duel]

    enum CodingKeys: String, CodingKey {
        case id, handle, streak, cote, today, duels
        case streakBest = "streak_best"
        case xpTotal = "xp_total"
        case cotePlaced = "cote_placed"
        case headToHead = "head_to_head"
    }
}

/// Nom d'un coffre pour l'affichage : « Coffre en bois »…
public enum ChestName {
    public static func title(_ tier: String) -> String {
        switch tier {
        case "silver": return "Coffre en argent"
        case "gold": return "Coffre en or"
        case "savant": return "Coffre Savant"
        default: return "Coffre en bois"
        }
    }
}

// MARK: - Coffres, arbre de Léon, tenue, trophées

public enum ChestTier: String, Codable, Hashable, Sendable, CaseIterable {
    /// `savant` : jamais un coffre reçu, seulement le rang obtenu à l'ouverture (Recharge).
    case wood, silver, gold, savant

    public var title: String { ChestName.title(rawValue) }
}

public struct ChestRef: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let tier: ChestTier
    public let source: String
    public let ref: String?

    public init(id: UUID, tier: ChestTier, source: String, ref: String? = nil) {
        self.id = id
        self.tier = tier
        self.source = source
        self.ref = ref
    }

    /// D'où vient le coffre, en mots.
    public var origin: String {
        switch source {
        case "quests_day": return "Tous les défis du jour"
        case "quests_week": return "Tous les défis de la semaine"
        case "level": return ref.map { "Niveau \($0)" } ?? "Nouveau niveau"
        case "trophy": return "Trophée"
        case "tree": return "L'arbre de Léon a grandi"
        case "referral": return "Parrainage"
        case "league": return "Podium de ta ligue"
        case "welcome": return "Bienvenue dans la nouvelle version"
        case "ad": return "Coffre offert"
        default: return "Récompense"
        }
    }
}

public struct ChestItem: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let slot: String

    public init(id: String, name: String, slot: String) {
        self.id = id
        self.name = name
        self.slot = slot
    }
}

public struct ChestContents: Codable, Hashable, Sendable {
    public struct Tickets: Codable, Hashable, Sendable {
        public let fiftyFifty: Int
        public let hint: Int

        public init(fiftyFifty: Int, hint: Int) {
            self.fiftyFifty = fiftyFifty
            self.hint = hint
        }

        enum CodingKeys: String, CodingKey {
            case hint
            case fiftyFifty = "fifty_fifty"
        }
    }

    public let tier: ChestTier
    public let seeds: Int
    public let tickets: Tickets
    public let joker: Bool
    public let item: ChestItem?
    public let balance: Int?
    /// Rang obtenu après la Recharge (absent sur un ancien coffre) et nombre de montées.
    public let finalTier: ChestTier?
    public let upgrades: Int?
    /// Objet exclusif du premier coffre Savant.
    public let bonusItem: ChestItem?

    public init(tier: ChestTier, seeds: Int, tickets: Tickets, joker: Bool, item: ChestItem?, balance: Int?,
                finalTier: ChestTier? = nil, upgrades: Int? = nil, bonusItem: ChestItem? = nil) {
        self.tier = tier
        self.seeds = seeds
        self.tickets = tickets
        self.joker = joker
        self.item = item
        self.balance = balance
        self.finalTier = finalTier
        self.upgrades = upgrades
        self.bonusItem = bonusItem
    }

    /// Rang final du coffre, montées comprises.
    public var reachedTier: ChestTier { finalTier ?? tier }

    enum CodingKeys: String, CodingKey {
        case tier, seeds, tickets, joker, item, balance, upgrades
        case finalTier = "final_tier"
        case bonusItem = "bonus_item"
    }
}

public struct TreeState: Codable, Hashable, Sendable {
    public let points: Int
    public let stage: Int
    public let stageName: String
    public let fruits: Int
    /// Graines cumulées pour la prochaine étape ou le prochain fruit ; nil quand l'arbre est complet.
    public let nextAt: Int?
    public let max: Int
    public let complete: Bool

    public init(points: Int, stage: Int, stageName: String, fruits: Int, nextAt: Int?, max: Int, complete: Bool) {
        self.points = points
        self.stage = stage
        self.stageName = stageName
        self.fruits = fruits
        self.nextAt = nextAt
        self.max = max
        self.complete = complete
    }

    enum CodingKeys: String, CodingKey {
        case points, stage, fruits, max, complete
        case stageName = "stage_name"
        case nextAt = "next_at"
    }

    /// Seuils (graines cumulées) des étapes 1 à 6, puis des fruits : mêmes valeurs que le serveur.
    public static let stageThresholds = [0, 150, 600, 1800, 4000, 9000]
    public static let fruitStep = 2500

    /// Début du palier en cours, pour la jauge.
    public var levelStart: Int {
        if stage < 6 { return TreeState.stageThresholds[stage - 1] }
        return 9000 + TreeState.fruitStep * fruits
    }

    /// Avancement vers le prochain palier (0 à 1).
    public var progress: Double {
        guard let nextAt, nextAt > levelStart else { return 1 }
        return Double(points - levelStart) / Double(nextAt - levelStart)
    }

    /// « Jeune plant », « 2e fruit »…
    public var nextLabel: String? {
        guard nextAt != nil else { return nil }
        if stage < 6 { return TreeState.stageName(stage + 1) }
        return fruits == 0 ? "1er fruit" : "\(fruits + 1)e fruit"
    }

    public static func stageName(_ stage: Int) -> String {
        ["Graine", "Pousse", "Jeune plant", "Arbuste", "Arbre", "Arbre de Léon en fleurs"][min(Swift.max(stage, 1), 6) - 1]
    }
}

public struct LeonItem: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slot: String
    /// « chest » (coffres), « fruit » (arbre), « shop » (boutique), « tree » (forme débloquée par l'arbre).
    public let rarity: String
    public let owned: Bool
    public let equipped: Bool
    /// Prix en graines (boutique seulement).
    public let price: Int?
    /// Étape de l'arbre qui débloque cette forme de Léon.
    public let unlockStage: Int?

    public init(id: String, name: String, slot: String, rarity: String, owned: Bool, equipped: Bool,
                price: Int? = nil, unlockStage: Int? = nil) {
        self.id = id
        self.name = name
        self.slot = slot
        self.rarity = rarity
        self.owned = owned
        self.equipped = equipped
        self.price = price
        self.unlockStage = unlockStage
    }

    enum CodingKeys: String, CodingKey {
        case id, name, slot, rarity, owned, equipped, price
        case unlockStage = "unlock_stage"
    }
}

/// Vitrine du jour de la boutique de Léon (le premier objet est en promotion).
public struct ShopOverview: Codable, Hashable, Sendable {
    public struct Featured: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let price: Int
        public let original: Int

        public init(id: String, price: Int, original: Int) {
            self.id = id
            self.price = price
            self.original = original
        }
    }

    public let featured: [Featured]
    public let resetsAt: Date?
    public let balance: Int

    public init(featured: [Featured], resetsAt: Date?, balance: Int) {
        self.featured = featured
        self.resetsAt = resetsAt
        self.balance = balance
    }

    enum CodingKeys: String, CodingKey {
        case featured, balance
        case resetsAt = "resets_at"
    }
}

public struct ShopPurchase: Codable, Hashable, Sendable {
    public let bought: Bool
    public let item: String
    public let price: Int?
    public let balance: Int

    public init(bought: Bool, item: String, price: Int?, balance: Int) {
        self.bought = bought
        self.item = item
        self.price = price
        self.balance = balance
    }
}

public struct HelpTickets: Codable, Hashable, Sendable {
    public let fiftyFifty: Int
    public let hint: Int

    public init(fiftyFifty: Int, hint: Int) {
        self.fiftyFifty = fiftyFifty
        self.hint = hint
    }

    enum CodingKeys: String, CodingKey {
        case hint
        case fiftyFifty = "fifty_fifty"
    }

    public func count(_ kind: HelpKind) -> Int {
        switch kind {
        case .fiftyFifty: return fiftyFifty
        case .hint, .secondChance: return hint   // le ticket « indice » sert aussi de Seconde chance
        case .context: return 0
        }
    }
}

public struct ProgressionOverview: Codable, Hashable, Sendable {
    public let xp: Int
    public let level: Int
    public let seeds: Int
    public let streakFreezes: Int
    public let tree: TreeState
    public let chests: [ChestRef]
    public let tickets: HelpTickets
    /// Emplacement → objet porté (« hat » → « beret »).
    public let outfit: [String: String]
    public let items: [LeonItem]
    /// Forme de Léon la plus avancée débloquée (affichée quand aucune n'est choisie).
    public let bestForm: String?

    public init(xp: Int, level: Int, seeds: Int, streakFreezes: Int, tree: TreeState, chests: [ChestRef],
                tickets: HelpTickets, outfit: [String: String], items: [LeonItem], bestForm: String? = nil) {
        self.bestForm = bestForm
        self.xp = xp
        self.level = level
        self.seeds = seeds
        self.streakFreezes = streakFreezes
        self.tree = tree
        self.chests = chests
        self.tickets = tickets
        self.outfit = outfit
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case xp, level, seeds, tree, chests, tickets, outfit, items
        case streakFreezes = "streak_freezes"
        case bestForm = "best_form"
    }
}

public struct TreeFeedResult: Codable, Hashable, Sendable {
    public let fed: Int
    public let newChests: Int
    public let newItems: [ChestItem]
    public let tree: TreeState
    public let balance: Int

    public init(fed: Int, newChests: Int, newItems: [ChestItem], tree: TreeState, balance: Int) {
        self.fed = fed
        self.newChests = newChests
        self.newItems = newItems
        self.tree = tree
        self.balance = balance
    }

    enum CodingKeys: String, CodingKey {
        case fed, tree, balance
        case newChests = "new_chests"
        case newItems = "new_items"
    }
}

public struct TrophiesOverview: Codable, Hashable, Sendable {
    public struct Exploit: Codable, Hashable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let description: String
        public let chest: ChestTier?
        public let unlockedAt: Date?

        public init(id: String, name: String, description: String, chest: ChestTier?, unlockedAt: Date?) {
            self.id = id
            self.name = name
            self.description = description
            self.chest = chest
            self.unlockedAt = unlockedAt
        }

        enum CodingKeys: String, CodingKey {
            case id, name, description, chest
            case unlockedAt = "unlocked_at"
        }
    }

    public struct Mastery: Codable, Hashable, Identifiable, Sendable {
        public struct Next: Codable, Hashable, Sendable {
            public let tier: String
            public let cote: Int

            public init(tier: String, cote: Int) {
                self.tier = tier
                self.cote = cote
            }
        }

        public let domainId: String
        public let name: String
        public let placed: Bool
        public let cote: Int?
        /// Palier atteint : « bronze », « silver », « gold », « diamond » ; nil sinon.
        public let tier: String?
        public let next: Next?
        public var id: String { domainId }

        public init(domainId: String, name: String, placed: Bool, cote: Int?, tier: String?, next: Next?) {
            self.domainId = domainId
            self.name = name
            self.placed = placed
            self.cote = cote
            self.tier = tier
            self.next = next
        }

        enum CodingKeys: String, CodingKey {
            case name, placed, cote, tier, next
            case domainId = "domain_id"
        }
    }

    public let exploits: [Exploit]
    public let mastery: [Mastery]

    public init(exploits: [Exploit], mastery: [Mastery]) {
        self.exploits = exploits
        self.mastery = mastery
    }

    /// Paliers de maîtrise dans l'ordre, avec leur Elo et leur nom.
    public static let tiers: [(id: String, name: String, cote: Int)] = [
        ("bronze", "Bronze", 1050), ("silver", "Argent", 1200), ("gold", "Or", 1350), ("diamond", "Diamant", 1500),
    ]
}

// MARK: - Journal d'usage

/// Un événement d'usage : nom (liste blanche côté serveur) et quelques propriétés courtes.
public struct AppEvent: Hashable, Sendable {
    public let name: String
    public let props: [String: String]
    public let appVersion: String?

    public init(name: String, props: [String: String] = [:], appVersion: String? = nil) {
        self.name = name
        self.props = props
        self.appVersion = appVersion
    }

    public var json: JSONValue {
        var object: [String: JSONValue] = ["name": .string(name), "props": .object(props.mapValues(JSONValue.string))]
        if let appVersion { object["app_version"] = .string(appVersion) }
        return .object(object)
    }
}

// MARK: - Corrige tes erreurs

public struct CorrectionStart: Decodable, Hashable, Sendable {
    public let questionIds: [UUID]
    public let ranked: Bool

    public init(questionIds: [UUID], ranked: Bool) {
        self.questionIds = questionIds
        self.ranked = ranked
    }

    enum CodingKeys: String, CodingKey {
        case ranked
        case questionIds = "question_ids"
    }
}

public struct CorrectionResult: Decodable, Hashable, Sendable {
    public struct Refund: Decodable, Hashable, Sendable {
        public let domainId: String
        public let coteRefund: Int
        public let coteAfter: Int

        public init(domainId: String, coteRefund: Int, coteAfter: Int) {
            self.domainId = domainId
            self.coteRefund = coteRefund
            self.coteAfter = coteAfter
        }

        enum CodingKeys: String, CodingKey {
            case domainId = "domain_id"
            case coteRefund = "cote_refund"
            case coteAfter = "cote_after"
        }
    }

    public let corrected: Int
    public let total: Int
    public let refunds: [Refund]

    public init(corrected: Int, total: Int, refunds: [Refund]) {
        self.corrected = corrected
        self.total = total
        self.refunds = refunds
    }
}

// MARK: - Pubs récompensées

/// Récompenses possibles d'une pub (nom serveur).
public enum AdKind: String, Sendable, CaseIterable {
    case doubleSeeds = "double_seeds"
    case boostChest = "boost_chest"
    case freeChest = "free_chest"
    case streakRescue = "streak_rescue"
    case correction
}

/// État des pubs du jour : récompenses restantes, série à sauver, pub entre les parties autorisée.
public struct AdStatus: Decodable, Hashable, Sendable {
    public var doubleSeeds: Int
    public var boostChest: Int
    public var freeChest: Int
    /// Série perdue récupérable (sa longueur), sinon nil.
    public var streakRescue: Int?
    public var interstitial: Bool
    public var admin: Bool

    public init(doubleSeeds: Int = 0, boostChest: Int = 0, freeChest: Int = 0, streakRescue: Int? = nil,
                interstitial: Bool = false, admin: Bool = false) {
        self.doubleSeeds = doubleSeeds
        self.boostChest = boostChest
        self.freeChest = freeChest
        self.streakRescue = streakRescue
        self.interstitial = interstitial
        self.admin = admin
    }

    enum CodingKeys: String, CodingKey {
        case interstitial, admin
        case doubleSeeds = "double_seeds"
        case boostChest = "boost_chest"
        case freeChest = "free_chest"
        case streakRescue = "streak_rescue"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        doubleSeeds = try c.decodeIfPresent(Int.self, forKey: .doubleSeeds) ?? 0
        boostChest = try c.decodeIfPresent(Int.self, forKey: .boostChest) ?? 0
        freeChest = try c.decodeIfPresent(Int.self, forKey: .freeChest) ?? 0
        streakRescue = try c.decodeIfPresent(Int.self, forKey: .streakRescue)
        interstitial = try c.decodeIfPresent(Bool.self, forKey: .interstitial) ?? false
        admin = try c.decodeIfPresent(Bool.self, forKey: .admin) ?? false
    }
}

/// Récompense donnée par le serveur après une pub vérifiée.
public struct AdReward: Decodable, Hashable, Sendable {
    public let seeds: Int?
    public let chestId: UUID?
    public let boosted: Bool?
    public let streak: Int?
    public let balance: Int?

    public init(seeds: Int? = nil, chestId: UUID? = nil, boosted: Bool? = nil, streak: Int? = nil, balance: Int? = nil) {
        self.seeds = seeds
        self.chestId = chestId
        self.boosted = boosted
        self.streak = streak
        self.balance = balance
    }

    enum CodingKeys: String, CodingKey {
        case seeds, boosted, streak, balance
        case chestId = "chest_id"
    }
}

// MARK: - Réglages de l'app

public struct AppSettings: Decodable, Hashable, Sendable {
    /// En dessous de ce numéro de build, l'app demande la mise à jour.
    public let minBuild: Int

    public init(minBuild: Int) { self.minBuild = minBuild }

    enum CodingKeys: String, CodingKey {
        case minBuild = "min_build"
    }
}
