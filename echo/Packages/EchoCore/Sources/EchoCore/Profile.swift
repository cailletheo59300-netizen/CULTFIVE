import Foundation

/// Tout ce que le jeu garde sur le téléphone : pièces, records, apparences, série, réglages.
/// Pas de compte ni de serveur. Les achats, eux, sont gardés par Apple (« Restaurer les achats »).
public struct Profile: Codable, Equatable, Sendable {
    public var coins = 0
    public var bestScore = 0
    public var bestRound = 0
    public var gamesPlayed = 0
    public var firstLaunch: Date

    // Apparences
    public var ownedSkins: Set<String> = [Catalog.defaultTrail, Catalog.defaultDecor]
    public var equippedTrail = Catalog.defaultTrail
    public var equippedDecor = Catalog.defaultDecor

    // Achats
    public var noAds = false
    /// Achats de pièces déjà crédités (identifiants de transaction Apple) : jamais deux fois.
    public var creditedTransactions: Set<UInt64> = []

    // Défi du jour
    /// Jour du dernier défi joué (« 2026-10-30 »), pour la série.
    public var lastDailyDay: String?
    public var streak = 0
    public var bestStreak = 0
    /// Jour des compteurs ci-dessous : ils repartent à zéro chaque jour.
    public var dailyDay: String?
    public var dailyAttemptsUsed = 0
    public var dailyExtraAttempts = 0
    public var dailyBest: Int?

    // Réglages
    public var soundOn = true
    public var hapticsOn = true
    /// Ancien réglage de sensibilité (version 1.0), plus utilisé : gardé pour lire les anciennes sauvegardes.
    public var sensitivity = 1.25
    /// Réglage du doigt, de 0 (« Précis ») à 1 (« Rapide ») : voir `Tuning.pointerGain`.
    public var controlSetting = 0.5
    public var tutorialDone = false

    public init(now: Date = Date()) {
        firstLaunch = now
    }

    // MARK: Apparences

    public func owns(_ skin: Skin) -> Bool { skin.price == .free || ownedSkins.contains(skin.id) }

    /// Achat d'une apparence avec des pièces. Renvoie `false` si pas assez de pièces (ou pas en pièces).
    @discardableResult
    public mutating func buy(_ skin: Skin) -> Bool {
        guard !owns(skin), case .coins(let price) = skin.price, coins >= price else { return false }
        coins -= price
        ownedSkins.insert(skin.id)
        equip(skin)
        return true
    }

    public mutating func equip(_ skin: Skin) {
        guard owns(skin) else { return }
        switch skin.kind {
        case .trail: equippedTrail = skin.id
        case .decor: equippedDecor = skin.id
        }
    }

    // MARK: Défi du jour

    /// Remet les compteurs du défi à zéro si on a changé de jour.
    public mutating func rollDaily(to day: String) {
        guard dailyDay != day else { return }
        dailyDay = day
        dailyAttemptsUsed = 0
        dailyExtraAttempts = 0
        dailyBest = nil
    }

    /// Essais restants aujourd'hui (1 gratuit + ceux gagnés avec une pub).
    public func dailyAttemptsLeft(day: String) -> Int {
        guard dailyDay == day else { return 1 }
        return max(0, 1 + dailyExtraAttempts - dailyAttemptsUsed)
    }

    /// Un essai de plus est-il encore possible avec une pub aujourd'hui ?
    public func canEarnDailyAttempt(day: String) -> Bool {
        dailyAttemptsLeft(day: day) == 0 && (dailyDay == day ? dailyExtraAttempts : 0) < Economy.maxExtraDailyAttempts
    }

    public mutating func earnDailyAttempt(day: String) {
        rollDaily(to: day)
        dailyExtraAttempts += 1
    }

    /// Commence un essai du défi. Renvoie `false` s'il n'en reste pas.
    public mutating func startDailyAttempt(day: String) -> Bool {
        rollDaily(to: day)
        guard dailyAttemptsLeft(day: day) > 0 else { return false }
        dailyAttemptsUsed += 1
        return true
    }

    /// Fin d'un essai du défi : meilleur score du jour et série. Renvoie le cadeau de série (0 si déjà reçu aujourd'hui).
    public mutating func recordDaily(score: Int, day: String) -> Int {
        rollDaily(to: day)
        dailyBest = max(dailyBest ?? 0, score)
        guard lastDailyDay != day else { return 0 }
        streak = (lastDailyDay != nil && lastDailyDay == DayKey.previous(day)) ? streak + 1 : 1
        bestStreak = max(bestStreak, streak)
        lastDailyDay = day
        let reward = Economy.streakReward(streak: streak)
        coins += reward
        return reward
    }

    /// Série affichée aujourd'hui : elle tient tant que le défi d'hier ou d'aujourd'hui a été joué.
    public func currentStreak(today: String) -> Int {
        guard let last = lastDailyDay, last == today || last == DayKey.previous(today) else { return 0 }
        return streak
    }

    // MARK: Fin de partie

    /// Ajoute une partie terminée. Renvoie vrai si c'est un nouveau record.
    @discardableResult
    public mutating func recordGame(_ result: GameResult, coinsEarned: Int) -> Bool {
        gamesPlayed += 1
        coins += coinsEarned
        let record = result.score > bestScore && result.mode == .classic
        if result.mode == .classic {
            bestScore = max(bestScore, result.score)
            bestRound = max(bestRound, result.roundsCleared)
        }
        return record
    }

    // MARK: Lecture tolérante

    // Chaque champ a une valeur par défaut : un profil enregistré par une ancienne version se lit toujours,
    // même quand on ajoute des champs. Ne jamais renommer une clé existante (le profil serait perdu).
    private enum CodingKeys: String, CodingKey {
        case coins, bestScore, bestRound, gamesPlayed, firstLaunch, ownedSkins, equippedTrail, equippedDecor, noAds,
             creditedTransactions, lastDailyDay, streak, bestStreak, dailyDay, dailyAttemptsUsed, dailyExtraAttempts,
             dailyBest, soundOn, hapticsOn, sensitivity, controlSetting, tutorialDone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Profile()
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? base.coins
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? base.bestScore
        bestRound = try c.decodeIfPresent(Int.self, forKey: .bestRound) ?? base.bestRound
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? base.gamesPlayed
        firstLaunch = try c.decodeIfPresent(Date.self, forKey: .firstLaunch) ?? base.firstLaunch
        ownedSkins = try c.decodeIfPresent(Set<String>.self, forKey: .ownedSkins) ?? base.ownedSkins
        equippedTrail = try c.decodeIfPresent(String.self, forKey: .equippedTrail) ?? base.equippedTrail
        equippedDecor = try c.decodeIfPresent(String.self, forKey: .equippedDecor) ?? base.equippedDecor
        noAds = try c.decodeIfPresent(Bool.self, forKey: .noAds) ?? base.noAds
        creditedTransactions = try c.decodeIfPresent(Set<UInt64>.self, forKey: .creditedTransactions) ?? base.creditedTransactions
        lastDailyDay = try c.decodeIfPresent(String.self, forKey: .lastDailyDay)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? base.streak
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? base.bestStreak
        dailyDay = try c.decodeIfPresent(String.self, forKey: .dailyDay)
        dailyAttemptsUsed = try c.decodeIfPresent(Int.self, forKey: .dailyAttemptsUsed) ?? base.dailyAttemptsUsed
        dailyExtraAttempts = try c.decodeIfPresent(Int.self, forKey: .dailyExtraAttempts) ?? base.dailyExtraAttempts
        dailyBest = try c.decodeIfPresent(Int.self, forKey: .dailyBest)
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? base.soundOn
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? base.hapticsOn
        sensitivity = try c.decodeIfPresent(Double.self, forKey: .sensitivity) ?? base.sensitivity
        controlSetting = try c.decodeIfPresent(Double.self, forKey: .controlSetting) ?? base.controlSetting
        tutorialDone = try c.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? base.tutorialDone
    }
}
