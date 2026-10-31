import Foundation

/// Une grille commencée, gardée pour la reprendre plus tard.
public struct SavedGrid: Codable, Equatable, Sendable {
    public var key: String
    /// Marques du joueur (0 vide, 1 croix, 2 gemme).
    public var marks: [Int]
    public var elapsed: Double
    public var hintsUsed: Int

    public init(key: String, marks: [Int], elapsed: Double, hintsUsed: Int) {
        self.key = key
        self.marks = marks
        self.elapsed = elapsed
        self.hintsUsed = hintsUsed
    }
}

/// Ce que rapporte une grille finie.
public struct Reward: Equatable, Sendable {
    public var hints = 0
    /// Série de jours (grille du jour seulement).
    public var streak = 0
    /// Premier passage (niveau jamais fini, grille du jour pas encore finie aujourd'hui).
    public var firstTime = false
    /// Thème débloqué par ce niveau.
    public var unlockedTheme: String?

    public init() {}
}

/// Tout ce que le jeu garde sur le téléphone : niveaux, indices, série, thèmes, réglages, grilles commencées.
/// Pas de compte ni de serveur. Les achats, eux, sont gardés par Apple (« Restaurer les achats »).
public struct Profile: Codable, Equatable, Sendable {
    public var firstLaunch: Date
    /// Plus haut niveau fini (le prochain à jouer est `levelsDone + 1`).
    public var levelsDone = 0
    public var hints = Economy.startingHints
    public var gridsSolved = 0

    // Achats et thèmes
    public var noAds = false
    public var ownedThemes: [String] = []
    public var theme = Catalog.defaultTheme
    /// Achats d'indices déjà crédités (identifiants de transaction Apple) : jamais deux fois.
    public var creditedTransactions: [UInt64] = []

    // Grille du jour
    public var lastDailyDay: String?
    public var streak = 0
    public var bestStreak = 0
    /// Meilleur temps (avec pénalités) de la dernière grille du jour finie.
    public var dailyTime: Int?
    /// Jour où la grille bonus a été débloquée, et jour où elle a été finie.
    public var bonusUnlockedDay: String?
    public var bonusDoneDay: String?
    /// Indices gagnés avec une pub aujourd'hui.
    public var adHintsDay: String?
    public var adHintsCount = 0

    // Grilles commencées (clé de `PuzzleKind`).
    public var saved: [SavedGrid] = []

    // Réglages
    public var soundOn = true
    public var hapticsOn = true
    public var autoCrosses = true
    /// Symboles dans les zones, en plus des couleurs (daltonisme).
    public var showSymbols = false
    public var tutorialDone = false

    public init(now: Date = Date()) {
        firstLaunch = now
    }

    // MARK: Niveaux

    public var nextLevel: Int { levelsDone + 1 }

    /// Niveau fini. Seul le prochain niveau compte (les niveaux se font dans l'ordre).
    @discardableResult
    public mutating func completeLevel(_ number: Int) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        guard number == levelsDone + 1 else { return reward }
        levelsDone = number
        reward.firstTime = true
        reward.hints = Economy.levelReward(number)
        hints += reward.hints
        reward.unlockedTheme = Catalog.themes.first { $0.price == .level(number) }?.id
        return reward
    }

    // MARK: Grille du jour

    public func dailyDone(today: String) -> Bool { lastDailyDay == today }

    /// Grille du jour finie. Renvoie la récompense (vide si déjà finie aujourd'hui).
    @discardableResult
    public mutating func completeDaily(day: String, time: Int) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        guard lastDailyDay != day else {
            dailyTime = min(dailyTime ?? time, time)
            reward.streak = streak
            return reward
        }
        streak = (lastDailyDay != nil && lastDailyDay == DayKey.previous(day)) ? streak + 1 : 1
        bestStreak = max(bestStreak, streak)
        lastDailyDay = day
        dailyTime = time
        reward.firstTime = true
        reward.streak = streak
        reward.hints = Economy.dailyReward(streak: streak)
        hints += reward.hints
        return reward
    }

    /// Série affichée aujourd'hui : elle tient tant que la grille d'hier ou d'aujourd'hui a été finie.
    public func currentStreak(today: String) -> Int {
        guard let last = lastDailyDay, last == today || last == DayKey.previous(today) else { return 0 }
        return streak
    }

    // MARK: Grille bonus

    /// La grille bonus se débloque avec une pub, une fois la grille du jour finie.
    public func canUnlockBonus(today: String) -> Bool {
        dailyDone(today: today) && bonusUnlockedDay != today
    }

    public func bonusAvailable(today: String) -> Bool { bonusUnlockedDay == today && bonusDoneDay != today }

    public mutating func unlockBonus(today: String) { bonusUnlockedDay = today }

    @discardableResult
    public mutating func completeBonus(day: String) -> Reward {
        var reward = Reward()
        gridsSolved += 1
        guard bonusDoneDay != day else { return reward }
        bonusDoneDay = day
        reward.firstTime = true
        reward.hints = Economy.bonusReward
        hints += reward.hints
        return reward
    }

    // MARK: Indices

    /// Utilise un indice. Renvoie `false` s'il n'en reste pas.
    public mutating func useHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        return true
    }

    public func canEarnAdHint(today: String) -> Bool {
        adHintsDay != today || adHintsCount < Economy.maxAdHintsPerDay
    }

    public mutating func earnAdHint(today: String) {
        if adHintsDay != today {
            adHintsDay = today
            adHintsCount = 0
        }
        adHintsCount += 1
        hints += Economy.adHint
    }

    // MARK: Thèmes

    public func owns(_ theme: ThemeSkin) -> Bool {
        switch theme.price {
        case .free: true
        case .level(let number): levelsDone >= number
        case .store: ownedThemes.contains(theme.id)
        }
    }

    public mutating func select(_ theme: ThemeSkin) {
        guard owns(theme) else { return }
        self.theme = theme.id
    }

    // MARK: Grilles commencées

    public func saved(_ key: String) -> SavedGrid? { saved.first { $0.key == key } }

    /// Garde une grille commencée (au plus 3 : niveau, jour, bonus ; les plus anciennes partent).
    public mutating func save(_ grid: SavedGrid) {
        saved.removeAll { $0.key == grid.key }
        saved.insert(grid, at: 0)
        if saved.count > 3 { saved.removeLast(saved.count - 3) }
    }

    public mutating func forget(_ key: String) {
        saved.removeAll { $0.key == key }
    }

    // MARK: Lecture tolérante

    // Chaque champ a une valeur par défaut : un profil enregistré par une ancienne version se lit toujours,
    // même quand on ajoute des champs. Ne jamais renommer une clé existante (le profil serait perdu).
    private enum CodingKeys: String, CodingKey {
        case firstLaunch, levelsDone, hints, gridsSolved, noAds, ownedThemes, theme, creditedTransactions, lastDailyDay,
             streak, bestStreak, dailyTime, bonusUnlockedDay, bonusDoneDay, adHintsDay, adHintsCount, saved, soundOn,
             hapticsOn, autoCrosses, showSymbols, tutorialDone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = Profile()
        firstLaunch = try c.decodeIfPresent(Date.self, forKey: .firstLaunch) ?? base.firstLaunch
        levelsDone = try c.decodeIfPresent(Int.self, forKey: .levelsDone) ?? base.levelsDone
        hints = try c.decodeIfPresent(Int.self, forKey: .hints) ?? base.hints
        gridsSolved = try c.decodeIfPresent(Int.self, forKey: .gridsSolved) ?? base.gridsSolved
        noAds = try c.decodeIfPresent(Bool.self, forKey: .noAds) ?? base.noAds
        ownedThemes = try c.decodeIfPresent([String].self, forKey: .ownedThemes) ?? base.ownedThemes
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? base.theme
        creditedTransactions = try c.decodeIfPresent([UInt64].self, forKey: .creditedTransactions) ?? base.creditedTransactions
        lastDailyDay = try c.decodeIfPresent(String.self, forKey: .lastDailyDay)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? base.streak
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? base.bestStreak
        dailyTime = try c.decodeIfPresent(Int.self, forKey: .dailyTime)
        bonusUnlockedDay = try c.decodeIfPresent(String.self, forKey: .bonusUnlockedDay)
        bonusDoneDay = try c.decodeIfPresent(String.self, forKey: .bonusDoneDay)
        adHintsDay = try c.decodeIfPresent(String.self, forKey: .adHintsDay)
        adHintsCount = try c.decodeIfPresent(Int.self, forKey: .adHintsCount) ?? base.adHintsCount
        saved = try c.decodeIfPresent([SavedGrid].self, forKey: .saved) ?? base.saved
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? base.soundOn
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? base.hapticsOn
        autoCrosses = try c.decodeIfPresent(Bool.self, forKey: .autoCrosses) ?? base.autoCrosses
        showSymbols = try c.decodeIfPresent(Bool.self, forKey: .showSymbols) ?? base.showSymbols
        tutorialDone = try c.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? base.tutorialDone
    }
}
